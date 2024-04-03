#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)
        half4   _BaseColor;
        half    _AlphaClip;
        float4  _BaseMap_ST;
        half    _Cutoff;
        half    _Smoothness;
        half4   _SpecColor;
        half    _Occlusion;
        half4   _WindMultiplier;

        half    _OcclusionFromSpecMask;

        half    _Jitter;

        float2  _DistanceFade;
        half    _BumpScale;
        half    _LightMapBoost;

        half    _DisplacementSampleSize;
        half    _DisplacementStrength;
        half    _DisplacementStrengthVertical;
        half    _NormalDisplacement;
    CBUFFER_END

//  Additional textures
    TEXTURE2D(_LuxURPWindRT); SAMPLER(sampler_LuxURPWindRT);
    TEXTURE2D(_SpecMask); SAMPLER(sampler_SpecMask);

//  Global Inputs
    half4 _LuxURPWindDirSize;
    half4 _LuxURPWindStrengthMultipliers;
    float4 _LuxURPSinTime;

//  Displacement
    #if defined(_DISPLACEMENT)
        TEXTURE2D(_Lux_DisplacementRT); SAMPLER(sampler_Lux_DisplacementRT);
        float4 _Lux_DisplacementPosition;
    #endif

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
            UNITY_DOTS_INSTANCED_PROP(float , _Surface)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
        #define _Surface                UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Surface)
    #endif


    void BendGrass(float3 positionOS, half3 normalOS, half4 vertexColors, out float3 positionWS, out half3 normalWS, out half2 fadeOcclusion) {
        #if defined (_BENDINGMODE_ALPHA)
            #define bendAmount vertexColors.a
        #else
            #define bendAmount vertexColors.b
        #endif
        #define phase vertexColors.gg
        
        fadeOcclusion = half2(1,1);

        #if !defined(_ALPHATEST_ON)
            float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
            float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
            float dist = dot(diff, diff);
            half fade = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );
        //  Shrink mesh
            positionOS.xyz *= fade;
        #endif

        positionWS = TransformObjectToWorld(positionOS.xyz);
        float3 cachedPositionWS = positionWS;
            //half4 wind = SAMPLE_TEXTURE2D_LOD(_LuxURPWindRT, sampler_LuxURPWindRT, positionWS.xz * _LuxURPWindDirSize.w + phase * _WindMultiplier.z, _WindMultiplier.w);
        //  Mind spatial coherency!
            half4 wind = SAMPLE_TEXTURE2D_LOD(_LuxURPWindRT, sampler_LuxURPWindRT, (positionWS.xz + phase * _WindMultiplier.z) * _LuxURPWindDirSize.w, _WindMultiplier.w);

    //  Calculate fade
        #if defined(_ALPHATEST_ON)
            float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
            float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
            float dist = dot(diff, diff);
            fadeOcclusion.x = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );
        #endif

        half windStrength = bendAmount * _LuxURPWindStrengthMultipliers.x * _WindMultiplier.x;
        half3 windDir = _LuxURPWindDirSize.xyz;

            //wind.r = wind.r * (wind.g * 2.0h - 0.243h);  // not a "real" normal as we want to keep the base direction
            //windStrength *= wind.r;
        windStrength *= wind.r * wind.g;

        normalWS = TransformObjectToWorldNormal(normalOS);

    //  Add small scale jitter (Horizon Zero Dawn)
        //float3 wpos = GetAbsolutePositionWS(positionRWS);
        float3 disp = sin( 4.0f * 2.650f * (positionWS.x + positionWS.y + positionWS.z + _Time.y)) * normalWS * float3(1.0f, 0.35f, 1.0f);
        positionWS += disp * windStrength * _Jitter; // * WindMultiplier.y;

    //  Displace vertices
        positionWS.xz += windDir.xz * windStrength;

    //  Do something to the normal as well
        //normalWS = TransformObjectToWorldNormal(normalOS);
        half2 normalWindDir = windDir.xz * _WindMultiplier.y;
        normalWS.xz += normalWindDir * windStrength;
        normalWS = NormalizeNormalPerVertex(normalWS);

    //  Displacement
        #if defined(_DISPLACEMENT)
            float2 samplePos = lerp(worldInstancePos.xz, cachedPositionWS.xz, _DisplacementSampleSize) - _Lux_DisplacementPosition.xy; // lower left corner
            samplePos = samplePos * _Lux_DisplacementPosition.z; // _Lux_DisplacementPosition.z = one OverSize

            if(samplePos.x == saturate(samplePos.x)) {
                if(samplePos.y == saturate(samplePos.y)) {
                    half2 radialMask = (samplePos.xy * 2 - 1);
                    half finalMask = 1 - dot(radialMask, radialMask);
                    finalMask = smoothstep(0, 0.5, finalMask);
                    if (finalMask > 0) {
                        half4 displacementSample = SAMPLE_TEXTURE2D_LOD(_Lux_DisplacementRT, sampler_Lux_DisplacementRT, samplePos, 0);
                        half3 bend = ( (displacementSample.rgb * 2 - 1)) * bendAmount;
                    //  Blue usually is close to 1 (speaking of a normal). So we use saturate to get only the negative part.
                        bend.z = (saturate(displacementSample.b * 2) - 1) * bendAmount;
                        bend *= finalMask;

                        half3 disp;
                        disp.xz = bend.xy * _DisplacementStrength;
                        disp.y = -(abs(bend.x) + abs(bend.y) - bend.z) * _DisplacementStrengthVertical;
                        positionWS = lerp(positionWS, cachedPositionWS + disp, saturate(dot(disp, disp)*16) );
                    //  Do something to the normal. Sign looks fine (reversed).
                        normalWS = normalWS + disp * PI * _NormalDisplacement;
                    }
                }
            }
        #endif

    }
#endif