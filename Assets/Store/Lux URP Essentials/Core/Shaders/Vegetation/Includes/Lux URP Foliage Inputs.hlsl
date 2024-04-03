#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

//  Must be declared before we can include Lighting.hlsl
    struct AdditionalSurfaceData
    {
        half translucency;
    };

//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 
//  Moved down so we have access to the cbuffer 
    //#include "../../Includes/Lux URP Translucent Lighting.hlsl"

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)
        float4  _BaseMap_ST;
        half    _Cutoff;
        half    _Smoothness;
        half4   _SpecColor;
        half4   _WindMultiplier;
        float   _SampleSize;
        half    _GlossMapScale;
        half    _BumpScale;
        float2  _DistanceFade;

        half4   _BaseColor;
        
        half    _TranslucencyPower;
        half    _TranslucencyStrength;
        half    _ShadowStrength;
        half    _MaskByShadowStrength;
        half    _Distortion;

        half    _OverrideTransmission;
        half3   _TransmissionColor;

        float   _PerInstanceVariation;

        float   _Turbulence;
        float   _TurbulenceFrequency;
        half    _TurbulenceMask;

        half    _Stretchiness;
        half    _SecondaryUp;

        half    _DebugVertexColor;
        half    _DebugBrightness;

        half    _DisplacementSampleSize;
        half    _DisplacementStrength;
        half    _DisplacementStrengthVertical;
        half    _NormalDisplacement;

    CBUFFER_END

    #include "../../Includes/Lux URP Translucent Lighting.hlsl"

//  Additional textures
    TEXTURE2D(_BumpSpecMap); SAMPLER(sampler_BumpSpecMap); float4 _BumpSpecMap_TexelSize;
    TEXTURE2D(_LuxURPWindRT); SAMPLER(sampler_LuxURPWindRT);

//  Displacement
    #if defined(_DISPLACEMENT)
        TEXTURE2D(_Lux_DisplacementRT); SAMPLER(sampler_Lux_DisplacementRT);
        float4 _Lux_DisplacementPosition;
    #endif

//  Global Inputs
    float4 _LuxURPWindDirSize;
    float4 _LuxURPWindStrengthMultipliers;
    float4 _LuxURPSinTime;
    float2 _LuxURPGust;
    float  _LuxURPBendFrequency;

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
    #endif


//  Vertex animation

    half4 SmoothCurve( half4 x ) {   
        return x * x *( 3.0h - 2.0h * x );   
    }
    half4 TriangleWave( half4 x ) {   
        return abs( frac( x + 0.5h ) * 2.0h - 1.0h );   
    }
    half4 SmoothTriangleWave( half4 x ) {   
        return SmoothCurve( TriangleWave( x ) );   
    }

    half2 SmoothCurve( half2 x ) {   
        return x * x *( 3.0h - 2.0h * x );   
    }
    half2 TriangleWave( half2 x ) {   
        return abs( frac( x + 0.5h ) * 2.0h - 1.0h );   
    }
    half2 SmoothTriangleWave( half2 x ) {   
        return SmoothCurve( TriangleWave( x ) );   
    }

    #define foliageMainWindStrengthFromZone _LuxURPWindStrengthMultipliers.y
    #define primaryBending _WindMultiplier.x
    #define secondaryBending _WindMultiplier.y
    #define edgeFlutter _WindMultiplier.z

    //  Wind animation - mapping
    #define vMainBending animParams.a
    #define vBranchBending animParams.b
    #define vPhase animParams.r
    #define vEdgeFlutter animParams.g


    void animateVertex(half4 animParams, half3 normalOS, inout float3 positionOS) {

        float origLength = length(positionOS.xyz);
        float3 windDir = TransformWorldToObjectDir(_LuxURPWindDirSize.xyz);
    //  In case we have no Wind Prefab foliage will vanish otherwise.
        windDir = clamp(windDir, -1, 1);

        const half fDetailAmp = 0.1h;
        const half fBranchAmp = 0.3h;

    //  Cache anim params for turbulence
        half vTurbulence = vBranchBending;
        half vTurbulenceMask = vEdgeFlutter;

half bendAmount = vMainBending;
float3 cachedPositionWS = TransformObjectToWorld(positionOS);
        
    #if !defined(_WIND_MATH)

        float3 objectWorldPos = UNITY_MATRIX_M._m03_m13_m23;
        float fObjPhase = dot(objectWorldPos, 2);
    //  As we are doing texture lookups we care about spatial coherency (cache). Thus we use frac.
        float fracObjPhase = frac(fObjPhase);
        float fBranchPhase = fracObjPhase + vPhase * 2; // * PhaseOffset;

    //  Sample main wind. Mind locality!
        float2 samplePos = (TransformObjectToWorld(positionOS.xyz * _SampleSize).xz - fracObjPhase.xx * _PerInstanceVariation) * _LuxURPWindDirSize.ww;
        float4 wind = SAMPLE_TEXTURE2D_LOD(_LuxURPWindRT, sampler_LuxURPWindRT, samplePos.xy, _WindMultiplier.w);

    //  Factor in bending params from Material
        animParams.abg *= _WindMultiplier.xyz;
    //  Make math match
        animParams.ab *= 2;

    //  Break up WindDir
        windDir.xz = windDir.xz + (fracObjPhase * 2 - 1).xx * 0.25; 
        windDir = normalize(windDir);

    //  Primary bending
                //positionOS.xz += vMainBending   *   windDir.xz * foliageMainWindStrengthFromZone * smoothstep(-1.5h, 1.0h, wind.r * (wind.g * 1.0h - 0.243h));
        positionOS.xz += vMainBending * windDir.xz * foliageMainWindStrengthFromZone * wind.r * wind.g;

    //  Second texture sample taking phase into account. Mind locality!
        wind = SAMPLE_TEXTURE2D_LOD(_LuxURPWindRT, sampler_LuxURPWindRT, samplePos.xy - fBranchPhase * _LuxURPWindDirSize.ww, _WindMultiplier.w);
            //  Edge Flutter
                //float3 bend = normalOS.xyz * (animParams.g * fDetailAmp * lerp(_LuxURPSinTime.y, _LuxURPSinTime.z, wind.r));
                //bend.y = animParams.b * fBranchAmp;
            //  Edge Flutter and Secondary Bending
                //positionOS.xyz += ( bend + ( animParams.b  *  windDir * wind.r * (wind.g * 2.0h - 0.243h) ) ) * foliageMainWindStrengthFromZone;

                //float windSecondary = wind.r * (wind.g * 2.0h - 0.243h);
        float windSecondary = wind.r * wind.g;
    
    //  Edge Flutter
        float3 bend = normalOS.xyz * vEdgeFlutter * fDetailAmp * lerp(_LuxURPSinTime.y, _LuxURPSinTime.z, wind.r);
    //  Secondary Bending - up and down which did not exist before.
        bend.y = vTurbulence * fBranchAmp * _SecondaryUp;
    //  Secondary Bending - along wind dir
        bend += vBranchBending * windDir;
        positionOS.xyz += bend * windSecondary * foliageMainWindStrengthFromZone;

    #else
        float3 objectWorldPos = UNITY_MATRIX_M._m03_m13_m23;

    //  Animate incoming wind
        float3 absObjectWorldPos = abs(objectWorldPos.xyz * 0.125h);
        float sinuswave = _SinTime.z;
        half2 vOscillations = SmoothTriangleWave( half2(absObjectWorldPos.x + sinuswave, absObjectWorldPos.z + sinuswave * 0.7h) );
        // x used for main wind bending / y used for tumbling
        half2 fOsc = (vOscillations.xy * vOscillations.xy);
            //fOsc = 0.75h + (fOsc + 3.33h) * 0.33h;
        fOsc = (fOsc + 3.33h) * 0.33h;

        half fObjPhase = dot(objectWorldPos, 2);
        half fBranchPhase = fObjPhase + vPhase;
        half fVtxPhase = dot(positionOS.xyz, vEdgeFlutter + fBranchPhase);

    //  Factor in bending params from Material
        animParams.abg *= _WindMultiplier.xyz;

        // x is used for edges; y is used for branches
        float2 vWavesIn = _Time.yy + half2(fVtxPhase, fBranchPhase); // changed to float (android issues)
        // 1.975, 0.793, 0.375, 0.193 are good frequencies
        half4 vWaves = frac( vWavesIn.xxyy * float4(1.975f, 0.793f, 0.375f, 0.193f) ) * 2.0f - 1.0f; // changed to float (android issues)
        vWaves = SmoothTriangleWave( vWaves );
        half2 vWavesSum = vWaves.xz + vWaves.yw;

    //  Primary bending / animated by * fOsc.x
        positionOS.xz += animParams.a * windDir.xz * foliageMainWindStrengthFromZone * fOsc.x;

        float3 bend = normalOS.xyz * (animParams.g * fDetailAmp);
        bend.y = vTurbulence * fBranchAmp * _SecondaryUp;

        positionOS.xyz += ( (vWavesSum.xyx * bend) + (animParams.b * fBranchAmp * windDir * fOsc.y * vWavesSum.y) ) * foliageMainWindStrengthFromZone;

        float4 wind = float4(1, foliageMainWindStrengthFromZone * fOsc.x * 0.2, 0, 0);
    #endif


    //  Displacement Part1
        #if defined(_DISPLACEMENT)
            half finalMask = 0;
            float3 push = 0;

            //float2 samplePosD = lerp(objectWorldPos.xz + vPhase * 0.5, cachedPositionWS.xz, 0 /*_DisplacementSampleSize*/) - _Lux_DisplacementPosition.xy; // lower left corner
            
            float2 samplePosD = objectWorldPos.xz + vPhase * _DisplacementSampleSize - _Lux_DisplacementPosition.xy; // lower left corner

            samplePosD = samplePosD * _Lux_DisplacementPosition.z; // _Lux_DisplacementPosition.z = one Over Size
            if(samplePosD.x == saturate(samplePosD.x)) {
                if(samplePosD.y == saturate(samplePosD.y)) {
                    half2 radialMask = (samplePosD.xy * 2 - 1);
                    finalMask = 1 - dot(radialMask, radialMask);
                    finalMask = smoothstep(0, 0.5, finalMask);
                    if (finalMask > 0) {
                        half4 displacementSample = SAMPLE_TEXTURE2D_LOD(_Lux_DisplacementRT, sampler_Lux_DisplacementRT, samplePosD, 0);
                        push = ( (displacementSample.rgb * 2 - 1)) * bendAmount;
                    //  Blue usually is close to 1 (speaking of a normal). So we use saturate to get only the negative part.
                        push.z = (saturate(displacementSample.b * 2) - 1) * bendAmount;
                        push *= finalMask;
                        push = TransformWorldToObjectDir(push.xzy, false).xzy; //normalize?
                    }
                }
            }
        #endif


    //  Turbulence
        float localTime = _LuxURPBendFrequency;
        #if defined(_DISPLACEMENT)
            float Turbulence = (_Turbulence  + ( abs(push.x) + abs(push.y) ) * 18 )           * lerp(1, vTurbulenceMask, _TurbulenceMask);
        #else 
            float Turbulence = _Turbulence * lerp(1, vTurbulenceMask, _TurbulenceMask);
        #endif

        if(Turbulence > 0) {
            float tOffset = (vTurbulence + vPhase) * 4;
        //  Get a unique frequency per object and phase
            float tFrequency = _TurbulenceFrequency * (localTime.x + fObjPhase * 8 + vPhase);
            float4 tWaves = SmoothTriangleWave(float4( tFrequency + tOffset, tFrequency * 0.75 + tOffset, tFrequency * 0.5 + tOffset, tFrequency * .25 + tOffset));
            float noiseSum = tWaves.x + tWaves.y + (tWaves.z * tWaves.w);
            noiseSum = 1 - noiseSum;
            positionOS.xyz += normalOS.xyz * noiseSum * vTurbulence * Turbulence * fDetailAmp * max(wind.r, wind.g) * foliageMainWindStrengthFromZone;
        }

        //positionOS.xyz = lerp( normalize(positionOS.xyz) * origLength, positionOS.xyz, _Stretchiness.xxx);


//  Displacement
    

//float2 samplePosD = objectWorldPos.xz - _Lux_DisplacementPosition.xy;

    

        #if defined(_DISPLACEMENT)
            if (finalMask > 0) {
                half3 disp;
                disp.xz = push.xy * _DisplacementStrength;
                disp.y = -(abs(push.x) + abs(push.y) - push.z) * _DisplacementStrengthVertical;
// positionWS = lerp(positionWS, cachedPositionWS + disp, saturate(dot(disp, disp)*16) );
positionOS +=  disp * saturate(dot(disp, disp)*16);

            //  Do something to the normal. Sign looks fine (reversed).
                normalOS = normalOS + disp * PI * _NormalDisplacement;
            }
        #endif


     
        positionOS.xyz = lerp( normalize(positionOS.xyz) * origLength, positionOS.xyz, _Stretchiness.xxx);

        
        
    }
#endif