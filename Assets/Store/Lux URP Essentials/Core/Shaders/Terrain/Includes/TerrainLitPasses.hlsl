#ifndef UNIVERSAL_TERRAIN_LIT_PASSES_INCLUDED
#define UNIVERSAL_TERRAIN_LIT_PASSES_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

    #if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
        #define ENABLE_TERRAIN_PERPIXEL_NORMAL
    #endif

    #ifdef UNITY_INSTANCING_ENABLED
        TEXTURE2D(_TerrainHeightmapTexture);
        TEXTURE2D(_TerrainNormalmapTexture);
        SAMPLER(sampler_TerrainNormalmapTexture);
        float4 _TerrainHeightmapRecipSize;   // float4(1.0f/width, 1.0f/height, 1.0f/(width-1), 1.0f/(height-1))
        float4 _TerrainHeightmapScale;       // float4(hmScale.x, hmScale.y / (float)(kMaxHeight), hmScale.z, 0.0f)
    #endif


    UNITY_INSTANCING_BUFFER_START(Terrain)
        UNITY_DEFINE_INSTANCED_PROP(float4, _TerrainPatchInstanceData)  // float4(xBase, yBase, skipScale, ~)
    UNITY_INSTANCING_BUFFER_END(Terrain)

    #ifdef _ALPHATEST_ON
        // Already defined in TerrainLitinput.hlsl
        // TEXTURE2D(_TerrainHolesTexture);
        // SAMPLER(sampler_TerrainHolesTexture);
        void ClipHoles(float2 uv)
        {
            float hole = SAMPLE_TEXTURE2D(_TerrainHolesTexture, sampler_TerrainHolesTexture, uv).r;
            clip(hole == 0.0f ? -1 : 1);
        }
    #endif

    struct Attributes
    {
        float4 positionOS : POSITION;
        float3 normalOS : NORMAL;
        float2 texcoord : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 uvMainAndLM              : TEXCOORD0; // xy: control, zw: lightmap
    #ifndef TERRAIN_SPLAT_BASEPASS
        float4 uvSplat01                : TEXCOORD1; // xy: splat0, zw: splat1
        float4 uvSplat23                : TEXCOORD2; // xy: splat2, zw: splat3
    #endif

    #if ( defined(_NORMALMAP) || defined(_PARALLAX) ) && !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
        half3 normal                    : TEXCOORD3;    // xyz: normal, w: viewDir.x
        half4 tangent                   : TEXCOORD4;    // xyz: tangent, w: viewDir.y
    #else
        half3 normal                    : TEXCOORD3;
        half3 vertexSH                  : TEXCOORD4; // SH
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light
    #else
        half  fogFactor                 : TEXCOORD5;
    #endif
    
        float3 positionWS               : TEXCOORD7;
    
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord              : TEXCOORD8;
    #endif

    #if defined(DYNAMICLIGHTMAP_ON)
        float2 dynamicLightmapUV        : TEXCOORD9;
    #endif

    #ifdef USE_APV_PROBE_OCCLUSION
        float4 probeOcclusion           : TEXCOORD10;
    #endif
        

        float4 clipPos                  : SV_POSITION;

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

//  -----------------------------------------------------------------------------------------------
//  Procedural Mapping

    real Lux_Luminance(real3 linearRgb) {
        return dot(linearRgb, real3(0.2126729, 0.7151522, 0.0721750));
    }

    void GetProceduralBaseSample(
        Texture2D sampleTex, SamplerState samplerTex, float2 uv,
        #ifdef _TERRAIN_BLEND_HEIGHT
            inout half result,
        #else
            inout half4 result,
        #endif
        inout float2 uv1, inout float2 uv2, inout float2 uv3,
        inout float w1, inout float w2, inout float w3, inout float2 duvdx, inout float2 duvdy)
    {
        float2 uvScaled = uv * 3.464 * _ProceduralScale;
        const float2x2 gridToSkewedGrid = float2x2(1.0, 0.0, -0.57735027, 1.15470054);
        float2 skewedCoord = mul(gridToSkewedGrid, uvScaled);
        int2 baseId = int2(floor(skewedCoord));
        float3 temp = float3(frac(skewedCoord), 0);
        temp.z = 1.0 - temp.x - temp.y;
        
        int2 vertex1, vertex2, vertex3;
        if (temp.z > 0.0) {
            w1 = temp.z;
            w2 = temp.y;
            w3 = temp.x;
            vertex1 = baseId;
            vertex2 = baseId + int2(0, 1);
            vertex3 = baseId + int2(1, 0);
        }
        else {
            w1 = -temp.z;
            w2 = 1.0 - temp.y;
            w3 = 1.0 - temp.x;
            vertex1 = baseId + int2(1, 1);
            vertex2 = baseId + int2(1, 0);
            vertex3 = baseId + int2(0, 1);
        }

        const float2x2 hashMatrix = float2x2(127.1, 311.7, 269.5, 183.3);
        const float hashFactor = 3758.5453;
        uv1 = uv + frac(sin(mul(hashMatrix, (float2)vertex1)) * hashFactor);
        uv2 = uv + frac(sin(mul(hashMatrix, (float2)vertex2)) * hashFactor);
        uv3 = uv + frac(sin(mul(hashMatrix, (float2)vertex3)) * hashFactor);

    //  Use a hash function which does not include sin
    //  Adds a little bit visible tiling...   
        // float2 uv1 = uv + hash22( (float2)vertex1 );
        // float2 uv2 = uv + hash22( (float2)vertex2 );
        // float2 uv3 = uv + hash22( (float2)vertex3 );

        duvdx = ddx(uv);
        duvdy = ddy(uv);

    //  Here we have to sample first as we want to calculate the weights based on height or luminance
    //  Albedo – Sample Gaussion values from transformed input
        #ifdef _TERRAIN_BLEND_HEIGHT
            half G1 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv1, duvdx, duvdy).r;
            half G2 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv2, duvdx, duvdy).r;
            half G3 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv3, duvdx, duvdy).r;
        //  Weight by Height - somehow
            w1 *= G1;
            w2 *= G2;
            w3 *= G3;
        #else
            half4 G1 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv1, duvdx, duvdy);
            half4 G2 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv2, duvdx, duvdy);
            half4 G3 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv3, duvdx, duvdy);
        //  Weight by Luminance
            w1 *= Lux_Luminance(G1.rgb);
            w2 *= Lux_Luminance(G2.rgb);
            w3 *= Lux_Luminance(G3.rgb);
        #endif
        
    //  Get weights using float!
        float exponent = 1.0f + _ProceduralBlend * 15.0f;
        w1 = pow(w1, exponent);
        w2 = pow(w2, exponent);
        w3 = pow(w3, exponent);
        float sum = saturate(w1 + w2 + w3);
        sum = (sum == 0.0f) ? 0.0f : rcp(sum);

        w1 = w1 * sum;
        w2 = w2 * sum;
        w3 = w3 * sum;
        
    //  Result
        result = w1 * G1 + w2 * G2 + w3 * G3;
    }

    half4 sampleProcedural(Texture2D sampleTex, SamplerState samplerTex, float2 uv, float2 uv1, float2 uv2, float2 uv3, half w1, half w2, half w3, float2 duvdx, float2 duvdy) {

        half4 G1; half4 G2; half4 G3; half4 G4;
        
        UNITY_BRANCH if (w1 > 0.95)
        {
            return SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv1, duvdx, duvdy);
        }
        else if (w2 > 0.95)
        {
            return SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv2, duvdx, duvdy); 
        }
        else if (w3 > 0.95)
        {
            return SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv3, duvdx, duvdy);
        }
        else
        {
            G1 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv1, duvdx, duvdy);
            G2 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv2, duvdx, duvdy);
            G3 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv3, duvdx, duvdy);
            return w1 * G1 + w2 * G2 + w3 * G3;
        }
        
        // half4 G1 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv1, duvdx, duvdy);
        // half4 G2 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv2, duvdx, duvdy);
        // half4 G3 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv3, duvdx, duvdy);

        // return w1 * G1 + w2 * G2 + w3 * G3;
    }

    half1 sampleProceduralHalf(Texture2D sampleTex, SamplerState samplerTex, float2 uv, float2 uv1, float2 uv2, float2 uv3, half w1, half w2, half w3, float2 duvdx, float2 duvdy) {

        half G1; half G2; half G3; half G4;
        
        UNITY_BRANCH if (w1 > 0.95)
        {
            return SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv1, duvdx, duvdy).r;
        }
        else if (w2 > 0.95)
        {
            return SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv2, duvdx, duvdy).r; 
        }
        else if (w3 > 0.95)
        {
            return SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv3, duvdx, duvdy).r;
        }
        else
        {
            G1 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv1, duvdx, duvdy).r;
            G2 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv2, duvdx, duvdy).r;
            G3 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv3, duvdx, duvdy).r;
            return w1 * G1 + w2 * G2 + w3 * G3;
        }

        // half G1 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv1, duvdx, duvdy).r;
        // half G2 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv2, duvdx, duvdy).r;
        // half G3 = SAMPLE_TEXTURE2D_GRAD(sampleTex, samplerTex, uv3, duvdx, duvdy).r;

        // return w1 * G1 + w2 * G2 + w3 * G3;
    }


//  -----------------------------------------------------------------------------------------------



    // ---------------------------

    void InitializeInputData(Varyings IN, half3 normalTS, half3x3 tangentSpaceRotation, half3 viewDirWS, out InputData inputData)
    {
        inputData = (InputData)0;

        inputData.positionWS = IN.positionWS;
    //  Needed in deferred
        inputData.positionCS = IN.clipPos;

        half3 SH = half3(0, 0, 0);

        #if defined(_NORMALMAP) || defined (_PARALLAX) || defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
            inputData.normalWS = TransformTangentToWorld(normalTS, tangentSpaceRotation);
            SH = SampleSH(inputData.normalWS.xyz);
        #else
            inputData.normalWS = IN.normal;
            SH = IN.vertexSH;
        #endif

        inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
        inputData.viewDirectionWS = viewDirWS;
        
        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            inputData.shadowCoord = IN.shadowCoord;
        #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
            inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
        #else
            inputData.shadowCoord = float4(0, 0, 0, 0);
        #endif

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
            inputData.fogCoord = InitializeInputDataFog(float4(IN.positionWS, 1.0), IN.fogFactorAndVertexLight.x);
            inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
        #else
            inputData.fogCoord = InitializeInputDataFog(float4(IN.positionWS, 1.0), IN.fogFactor);
        #endif
        
        #if defined(DYNAMICLIGHTMAP_ON)
            inputData.bakedGI = SAMPLE_GI(IN.uvMainAndLM.zw, IN.dynamicLightmapUV, SH, inputData.normalWS);
            inputData.shadowMask = SAMPLE_SHADOWMASK(IN.uvMainAndLM.zw);
        #elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
            inputData.bakedGI = SAMPLE_GI(SH,
                GetAbsolutePositionWS(inputData.positionWS),
                inputData.normalWS,
                inputData.viewDirectionWS,
                inputData.positionCS.xy,
                IN.probeOcclusion,
                inputData.shadowMask);
        #else
            inputData.bakedGI = SAMPLE_GI(IN.uvMainAndLM.zw, SH, inputData.normalWS);
            inputData.shadowMask = SAMPLE_SHADOWMASK(IN.uvMainAndLM.zw);
        #endif

        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.clipPos.xy);

        #if defined(DEBUG_DISPLAY)
        #if defined(DYNAMICLIGHTMAP_ON)
        inputData.dynamicLightmapUV = IN.dynamicLightmapUV;
        #endif
        #if defined(LIGHTMAP_ON)
        inputData.staticLightmapUV = IN.uvMainAndLM.zw;
        #else
        inputData.vertexSH = SH;
        #endif
        #endif
    }


    #ifdef _TERRAIN_BLEND_HEIGHT
        void HeightBasedSplatModifyCombined(inout half4 splatControl, in half4 heights, inout half height) {
        #ifndef TERRAIN_SPLAT_ADDPASS   // disable for multi-pass
            half4 splatHeight = max(heights, HALF_MIN) * splatControl;
            half maxHeight = max(max(splatHeight.x, splatHeight.y), max(splatHeight.z, splatHeight.w)); // Go parallel!
            
            // Ensure that the transition height is not zero.
            half transition = max(_HeightTransition * maxHeight, HALF_MIN);
            
            half mthreshold = maxHeight - transition;
            splatHeight = saturate((splatHeight - mthreshold ) / transition);
            
            half sumHeight = splatHeight.x + splatHeight.y + splatHeight.z + splatHeight.w;
            half sumSplat = splatControl.x + splatControl.y + splatControl.z + splatControl.w;
            
            splatControl = (sumSplat == 0.0) ? 0.0 : splatHeight / sumHeight;
        //  Must not get more than before...
            splatControl *= sumSplat;
            height = maxHeight;
        #endif
        }

// latest
        void HeightBasedSplatModifyCombinedNew(inout half4 splatControl, in half4 heights, inout half height)
        {
        #ifndef TERRAIN_SPLAT_ADDPASS   // disable for multi-pass
            // heights are in mask blue channel, we multiply by the splat Control weights to get combined height
            half4 splatHeight = heights * splatControl.rgba;
            half maxHeight = max(splatHeight.r, max(splatHeight.g, max(splatHeight.b, splatHeight.a)));

            // Ensure that the transition height is not zero.
            half transition = max(_HeightTransition, 1e-5);

            // This sets the highest splat to "transition", and everything else to a lower value relative to that, clamping to zero
            // Then we clamp this to zero and normalize everything
            half4 weightedHeights = splatHeight + transition - maxHeight.xxxx;
            weightedHeights = max(0, weightedHeights);

            // We need to add an epsilon here for active layers (hence the blendMask again)
            // so that at least a layer shows up if everything's too low.
            weightedHeights = (weightedHeights + 1e-6) * splatControl;

            // Normalize (and clamp to epsilon to keep from dividing by zero)
            half sumHeight = max(dot(weightedHeights, half4(1, 1, 1, 1)), 1e-6);
            splatControl = weightedHeights / sumHeight.xxxx;

            height = maxHeight;
        #endif
        }



    #endif


    //  Splatting ----------------------------------------------

    #ifndef TERRAIN_SPLAT_BASEPASS

    void SplatmapMix(float4 uvMainAndLM, float4 uvSplat01, float4 uvSplat23, inout half4 splatControl, out half weight, out half4 mixedDiffuse, out half4 defaultSmoothness, inout half3 mixedNormal, bool isDepthNormalPass)
    {

    //  Sample albedo and smoothness
        half4 diffAlbedo[4];
        
    //  We may use procedural texturing but do not use height based blending
        #if defined(_PROCEDURALTEXTURING) && !defined(_TERRAIN_BLEND_HEIGHT)
            half4 diffAlbedoNull;
            float2 uv1, uv2, uv3;
            float w1, w2, w3;
            float2 duvdx, duvdy;
            GetProceduralBaseSample(_Splat0, sampler_Splat0, uvSplat01.xy, diffAlbedoNull, uv1, uv2, uv3, w1, w2, w3, duvdx, duvdy);
            diffAlbedo[0] = diffAlbedoNull;
        #else
            diffAlbedo[0] = SAMPLE_TEXTURE2D(_Splat0, sampler_Splat0, uvSplat01.xy);
        #endif
        diffAlbedo[1] = SAMPLE_TEXTURE2D(_Splat1, sampler_Splat0, uvSplat01.zw);
        diffAlbedo[2] = SAMPLE_TEXTURE2D(_Splat2, sampler_Splat0, uvSplat23.xy);
        diffAlbedo[3] = SAMPLE_TEXTURE2D(_Splat3, sampler_Splat0, uvSplat23.zw);

        defaultSmoothness = half4(diffAlbedo[0].a, diffAlbedo[1].a, diffAlbedo[2].a, diffAlbedo[3].a);
        defaultSmoothness *= half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);

        // Now that splatControl has changed, we can compute the final weight and normalize
        weight = dot(splatControl, 1.0h);

        #ifdef TERRAIN_SPLAT_ADDPASS
            clip(weight <= 0.005h ? -1.0h : 1.0h);
        #endif

        #ifndef _TERRAIN_BASEMAP_GEN
            // Normalize weights before lighting and restore weights in final modifier functions so that the overal
            // lighting result can be correctly weighted.
            splatControl /= (weight + HALF_MIN);
        #endif

        mixedDiffuse = 0.0h;
        mixedDiffuse += diffAlbedo[0] * half4(_DiffuseRemapScale0.rgb * splatControl.rrr, 1.0h);
        mixedDiffuse += diffAlbedo[1] * half4(_DiffuseRemapScale1.rgb * splatControl.ggg, 1.0h);
        mixedDiffuse += diffAlbedo[2] * half4(_DiffuseRemapScale2.rgb * splatControl.bbb, 1.0h);
        mixedDiffuse += diffAlbedo[3] * half4(_DiffuseRemapScale3.rgb * splatControl.aaa, 1.0h);

        #ifdef _NORMALMAP
            half4 normalSamples[4];
            #if defined(_PROCEDURALTEXTURING) && !defined(_TERRAIN_BLEND_HEIGHT)
                normalSamples[0] = sampleProcedural(_Normal0, sampler_Normal0, uvSplat01.xy, uv1, uv2, uv3, w1, w2, w3, duvdx, duvdy);
            #else
                normalSamples[0] = SAMPLE_TEXTURE2D(_Normal0, sampler_Normal0, uvSplat01.xy);
            #endif
            normalSamples[1] = SAMPLE_TEXTURE2D(_Normal1, sampler_Normal0, uvSplat01.zw);
            normalSamples[2] = SAMPLE_TEXTURE2D(_Normal2, sampler_Normal0, uvSplat23.xy);
            normalSamples[3] = SAMPLE_TEXTURE2D(_Normal3, sampler_Normal0, uvSplat23.zw);
            
            half4 normalSample = 0;

            if (isDepthNormalPass)
            {
                half splatSum = dot(splatControl, half4(1,1,1,1));
                splatSum = splatControl.r + splatControl.g + splatControl.b + splatControl.a;

                #if defined(UNITY_ASTC_NORMALMAP_ENCODING)  // UnpackNormalAG
                    half4 nfix = half4(0, 0.5, 0, 0.5);
                #elif defined(UNITY_NO_DXT5nm)              // UnpackNormalRGB
                    half4 nfix = half4(0.5, 0.5, 0.5, 1.0);
                #else                                       // UnpackNormalmapRGorAG -> packedNormal.a *= packedNormal.r;
                    half4 nfix = half4(0.5, 0.5, 0.5, 1.0);
                #endif

                normalSample += nfix * (1.0 - splatSum);
            }

            normalSample += splatControl.r * normalSamples[0];
            normalSample += splatControl.g * normalSamples[1];
            normalSample += splatControl.b * normalSamples[2];
            normalSample += splatControl.a * normalSamples[3];

            #if BUMP_SCALE_NOT_SUPPORTED
                half3 nrm = UnpackNormal(normalSample);
            #else
                half normalScale = dot(half4(_NormalScale0, _NormalScale1, _NormalScale2, _NormalScale3), splatControl);
                half3 nrm = UnpackNormalScale(normalSample, normalScale);
            #endif

            // avoid risk of NaN when normalizing.
            #if HAS_HALF
                nrm.z += 0.01h;     
            #else
                nrm.z += 1e-5f;
            #endif
            mixedNormal = normalize(nrm.xyz);
        #endif
    }


    void SplatmapMixProcedural(float4 uvMainAndLM, float4 uvSplat01, float4 uvSplat23, inout half4 splatControl, out half weight, out half4 mixedDiffuse, out half4 defaultSmoothness, inout half3 mixedNormal,
        float2 uv1, float2 uv2, float2 uv3, half w1, half w2, half w3, float2 duvdx, float2 duvdy, bool isDepthNormalPass)
    {

    //  Sample albedo and smoothness
        half4 diffAlbedo[4];
        diffAlbedo[0] = sampleProcedural(_Splat0, sampler_Splat0, uvSplat01.xy, uv1, uv2, uv3, w1, w2, w3, duvdx, duvdy);
        diffAlbedo[1] = SAMPLE_TEXTURE2D(_Splat1, sampler_Splat0, uvSplat01.zw);
        diffAlbedo[2] = SAMPLE_TEXTURE2D(_Splat2, sampler_Splat0, uvSplat23.xy);
        diffAlbedo[3] = SAMPLE_TEXTURE2D(_Splat3, sampler_Splat0, uvSplat23.zw);

        defaultSmoothness = half4(diffAlbedo[0].a, diffAlbedo[1].a, diffAlbedo[2].a, diffAlbedo[3].a);
        defaultSmoothness *= half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);

        // Now that splatControl has changed, we can compute the final weight and normalize
        weight = dot(splatControl, 1.0h);

        #ifdef TERRAIN_SPLAT_ADDPASS
            clip(weight <= 0.005h ? -1.0h : 1.0h);
        #endif

        #ifndef _TERRAIN_BASEMAP_GEN
            // Normalize weights before lighting and restore weights in final modifier functions so that the overal
            // lighting result can be correctly weighted.
            splatControl /= (weight + HALF_MIN);
        #endif

        mixedDiffuse = 0.0h;
        mixedDiffuse += diffAlbedo[0] * half4(_DiffuseRemapScale0.rgb * splatControl.rrr, 1.0h);
        mixedDiffuse += diffAlbedo[1] * half4(_DiffuseRemapScale1.rgb * splatControl.ggg, 1.0h);
        mixedDiffuse += diffAlbedo[2] * half4(_DiffuseRemapScale2.rgb * splatControl.bbb, 1.0h);
        mixedDiffuse += diffAlbedo[3] * half4(_DiffuseRemapScale3.rgb * splatControl.aaa, 1.0h);

        #ifdef _NORMALMAP
            half4 normalSamples[4];
            normalSamples[0] = sampleProcedural(_Normal0, sampler_Normal0, uvSplat01.xy, uv1, uv2, uv3, w1, w2, w3, duvdx, duvdy);
            normalSamples[1] = SAMPLE_TEXTURE2D(_Normal1, sampler_Normal0, uvSplat01.zw);
            normalSamples[2] = SAMPLE_TEXTURE2D(_Normal2, sampler_Normal0, uvSplat23.xy);
            normalSamples[3] = SAMPLE_TEXTURE2D(_Normal3, sampler_Normal0, uvSplat23.zw);
            
            half4 normalSample = 0;

            if (isDepthNormalPass)
            {
                half splatSum = dot(splatControl, half4(1,1,1,1));
                splatSum = splatControl.r + splatControl.g + splatControl.b + splatControl.a;

                #if defined(UNITY_ASTC_NORMALMAP_ENCODING)  // UnpackNormalAG
                    half4 nfix = half4(0, 0.5, 0, 0.5);
                #elif defined(UNITY_NO_DXT5nm)              // UnpackNormalRGB
                    half4 nfix = half4(0.5, 0.5, 0.5, 1.0);
                #else                                       // UnpackNormalmapRGorAG -> packedNormal.a *= packedNormal.r;
                    half4 nfix = half4(0.5, 0.5, 0.5, 1.0);
                #endif

                normalSample += nfix * (1.0 - splatSum); 
            }

            normalSample += splatControl.r * normalSamples[0];
            normalSample += splatControl.g * normalSamples[1];
            normalSample += splatControl.b * normalSamples[2];
            normalSample += splatControl.a * normalSamples[3];

            #if BUMP_SCALE_NOT_SUPPORTED
                half3 nrm = UnpackNormal(normalSample);
            #else
                half normalScale = dot(half4(_NormalScale0, _NormalScale1, _NormalScale2, _NormalScale3), splatControl);
                half3 nrm = UnpackNormalScale(normalSample, normalScale);
            #endif
            
            // avoid risk of NaN when normalizing.
            #if HAS_HALF
                nrm.z += 0.01h;     
            #else
                nrm.z += 1e-5f;
            #endif
            mixedNormal = normalize(nrm.xyz);
        #endif
    }
    #endif

    void SplatmapFinalColor(inout half4 color, half fogCoord)
    {
        color.rgb *= color.a;
        #ifndef TERRAIN_GBUFFER
            #ifdef TERRAIN_SPLAT_ADDPASS
                color.rgb = MixFogColor(color.rgb, half3(0,0,0), fogCoord);
            #else
                color.rgb = MixFog(color.rgb, fogCoord);
            #endif
        #endif
    }

    void TerrainInstancing(inout float4 positionOS, inout float3 normal, inout float2 uv)
    {
    #ifdef UNITY_INSTANCING_ENABLED
        float2 patchVertex = positionOS.xy;
        float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);

        float2 sampleCoords = (patchVertex.xy + instanceData.xy) * instanceData.z;
        float height = UnpackHeightmap(_TerrainHeightmapTexture.Load(int3(sampleCoords, 0)));

        positionOS.xz = sampleCoords * _TerrainHeightmapScale.xz;
        positionOS.y = height * _TerrainHeightmapScale.y;

        #ifdef ENABLE_TERRAIN_PERPIXEL_NORMAL
            normal = half3(0, 1, 0);
        #else
            normal = _TerrainNormalmapTexture.Load(int3(sampleCoords, 0)).rgb * 2 - 1;
        #endif
        uv = sampleCoords * _TerrainHeightmapRecipSize.zw;
    #endif
    }

    void TerrainInstancing(inout float4 positionOS, inout float3 normal)
    {
        float2 uv = { 0, 0 };
        TerrainInstancing(positionOS, normal, uv);
    }


    ///////////////////////////////////////////////////////////////////////////////
    //                  Vertex and Fragment functions                            //
    ///////////////////////////////////////////////////////////////////////////////

    // Used in Standard Terrain shader
    Varyings SplatmapVert(Attributes v)
    {
        Varyings o = (Varyings)0;
        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
        TerrainInstancing(v.positionOS, v.normalOS, v.texcoord);
        
        VertexPositionInputs Attributes = GetVertexPositionInputs(v.positionOS.xyz);

        o.uvMainAndLM.xy = v.texcoord;
        o.uvMainAndLM.zw = v.texcoord * unity_LightmapST.xy + unity_LightmapST.zw;

        #ifndef TERRAIN_SPLAT_BASEPASS
            #if defined(_PROCEDURALTEXTURING)
                o.uvSplat01.xy = Attributes.positionWS.xz / _ProceduralTiling;       
            #else
                o.uvSplat01.xy = TRANSFORM_TEX(v.texcoord, _Splat0);
            #endif
            o.uvSplat01.zw = TRANSFORM_TEX(v.texcoord, _Splat1);
            o.uvSplat23.xy = TRANSFORM_TEX(v.texcoord, _Splat2);
            o.uvSplat23.zw = TRANSFORM_TEX(v.texcoord, _Splat3);
        #endif

        #if defined(DYNAMICLIGHTMAP_ON)
            o.dynamicLightmapUV = v.texcoord * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
        #endif

        #if ( defined(_NORMALMAP) || defined(_PARALLAX) ) && !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
            half4 vertexTangent = half4(cross(half3(0.0, 0.0, 1.0), v.normalOS), 1.0);
            VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, vertexTangent);
//  fix orientation
normalInput.tangentWS *= -1;
            o.normal = normalInput.normalWS;
            real sign = vertexTangent.w * GetOddNegativeScale();
            o.tangent = half4(normalInput.tangentWS, sign);
        #else
            o.normal = TransformObjectToWorldNormal(v.normalOS);
            OUTPUT_SH4(Attributes.positionWS, o.normal.xyz, GetWorldSpaceNormalizeViewDir(Attributes.positionWS), o.vertexSH, o.probeOcclusion);
        #endif

        half fogFactor = 0;
        #if !defined(_FOG_FRAGMENT)
            fogFactor = ComputeFogFactor(Attributes.positionCS.z);
        #endif

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
            o.fogFactorAndVertexLight.x = fogFactor;
            o.fogFactorAndVertexLight.yzw = VertexLighting(Attributes.positionWS, o.normal.xyz);
        #else
            o.fogFactor = fogFactor;
        #endif
        
        o.positionWS = Attributes.positionWS;
        o.clipPos = Attributes.positionCS;

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            o.shadowCoord = GetShadowCoord(Attributes);
        #endif

        return o;
    }

    // Used in Standard Terrain shader

#ifdef TERRAIN_GBUFFER
    FragmentOutput SplatmapFragment(Varyings IN)
#else
    void SplatmapFragment(
        Varyings IN
        , out half4 outColor : SV_Target0
    #ifdef _WRITE_RENDERING_LAYERS
        , out float4 outRenderingLayers : SV_Target1
    #endif
    )
#endif
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

        #ifdef _ALPHATEST_ON
            half hole = SAMPLE_TEXTURE2D(_TerrainHolesTexture, sampler_TerrainHolesTexture, IN.uvMainAndLM.xy).r;
            clip(hole == 0.0h ? -1 : 1);
        #endif

        half3 normalTS = half3(0.0h, 0.0h, 1.0h);

        half3x3 tangentSpaceRotation = 0;
        half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);

        #if defined(_NORMALMAP) || defined(_PARALLAX) || defined(TERRAIN_SPLAT_BASEPASS)
            #if !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL) && ( defined(_NORMALMAP) || defined(_PARALLAX) )
            //  Same matrix we need to transfer the normalTS
                half3 bitangentWS = cross(IN.normal, IN.tangent.xyz) * -1;
                tangentSpaceRotation =  half3x3(IN.tangent.xyz, bitangentWS, IN.normal.xyz);
                half3 tangentWS = IN.tangent.xyz;
                half3 viewDirTS = normalize( mul(tangentSpaceRotation, viewDirectionWS ) );
            #elif defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
                float2 sampleCoords = (IN.uvMainAndLM.xy / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
                half3 normalWS = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
            //  fix orientation
                half3 tangentWS = cross( /*GetObjectToWorldMatrix()._13_23_33*/ half3(0, 0, 1), normalWS) * -1;
            //  Ups: * -1?
                half3 bitangentWS = cross(normalWS, tangentWS) * -1;
                tangentSpaceRotation =  half3x3(tangentWS, bitangentWS, normalWS);
                half3 viewDirTS = normalize( mul(tangentSpaceRotation, viewDirectionWS) );
            #endif
        #endif
        
        #ifdef TERRAIN_SPLAT_BASEPASS
            half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uvMainAndLM.xy).rgb;
            half smoothness = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uvMainAndLM.xy).a;
// Unity 2019.1
            half metallic = 0; //SAMPLE_TEXTURE2D(_MetallicTex, sampler_MetallicTex, IN.uvMainAndLM.xy).r;
            half alpha = 1;
            half occlusion = 1;
        
        #else
            half4 splatControl;
            half weight;
            half4 mixedDiffuse;
            half4 defaultSmoothness;

            float2 splatUV = (IN.uvMainAndLM.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
            splatControl = SAMPLE_TEXTURE2D(_Control, sampler_Control, splatUV);

        //  Sample heights
            #ifdef _TERRAIN_BLEND_HEIGHT
                half4 heights;
                #if defined(_PROCEDURALTEXTURING)
                    half proceduralHeight;
                    float2 uv1, uv2, uv3;
                    float w1, w2, w3;
                    float2 duvdx, duvdy;
                    GetProceduralBaseSample(_HeightMaps, sampler_Splat0, IN.uvSplat01.xy, proceduralHeight, uv1, uv2, uv3, w1, w2, w3, duvdx, duvdy);
                    heights.x = proceduralHeight;
                #else
                    heights.x = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Splat0, IN.uvSplat01.xy).r;
                #endif
                heights.y = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Splat0, IN.uvSplat01.zw).g;
                heights.z = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Splat0, IN.uvSplat23.xy).b;
                heights.w = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Splat0, IN.uvSplat23.zw).a;

                half height;
            //  Adjust splatControl and calculate 1st height
                HeightBasedSplatModifyCombined(splatControl, heights, height);

            //  Parallax Extrusion
                #if defined(_PARALLAX)
                    float3 v = viewDirTS;
                    v.z += 0.42;
                    v.xy /= v.z;
                    half halfParallax = _Parallax * 0.5h;
                    
                    half parallax = height * _Parallax - halfParallax;
                    float2 offset1 =  parallax * v.xy;

                    float4 splatUV1 = IN.uvSplat01 + offset1.xyxy;
                    float4 splatUV2 = IN.uvSplat23 + offset1.xyxy;

                    #if defined(_PROCEDURALTEXTURING)
                        float2 uv1_o = uv1 + offset1;
                        float2 uv2_o = uv2 + offset1;
                        float2 uv3_o = uv3 + offset1;
                        heights.x = sampleProceduralHalf(_HeightMaps, sampler_Splat0, splatUV1.xy, uv1_o, uv2_o, uv3_o, w1, w2, w3, duvdx, duvdy);
                    #else
                        heights.x = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Splat0, splatUV1.xy).r;
                    #endif
                    heights.y = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Splat0, splatUV1.zw).g;
                    heights.z = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Splat0, splatUV2.xy).b;
                    heights.w = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Splat0, splatUV2.zw).a;

                //  Calculate 2nd height
                    half height1 = max( max(heights.x, heights.y), max(heights.z, heights.w) );
                    parallax = height1 * _Parallax - halfParallax;
                    float2 offset2 =  parallax * v.xy;

                    offset1 = (offset1 + offset2) * 0.5;
                    IN.uvSplat01 += offset1.xyxy;
                    IN.uvSplat23 += offset1.xyxy;

                    #if defined(_PROCEDURALTEXTURING)
                        uv1 += offset1;
                        uv2 += offset1;
                        uv3 += offset1;
                    #endif

                #endif
            #endif

            #if defined(_PROCEDURALTEXTURING)
                #ifdef _TERRAIN_BLEND_HEIGHT
                    SplatmapMixProcedural(IN.uvMainAndLM, IN.uvSplat01, IN.uvSplat23, splatControl, weight, mixedDiffuse, defaultSmoothness, normalTS,
                    uv1, uv2, uv3, w1, w2, w3, duvdx, duvdy, false);
                #else
                    SplatmapMix(IN.uvMainAndLM, IN.uvSplat01, IN.uvSplat23, splatControl, weight, mixedDiffuse, defaultSmoothness, normalTS, false);
                #endif
            #else
                SplatmapMix(IN.uvMainAndLM, IN.uvSplat01, IN.uvSplat23, splatControl, weight, mixedDiffuse, defaultSmoothness, normalTS, false);
            #endif
        
            half3 albedo = mixedDiffuse.rgb;
// Looks broken...
            defaultSmoothness *= dot(half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3), splatControl);
            half smoothness = dot(defaultSmoothness, splatControl);
            half metallic = dot(half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3), splatControl);
            half occlusion = 1;
            half alpha = weight;
        #endif

        InputData inputData;
        InitializeInputData(IN, normalTS, tangentSpaceRotation, viewDirectionWS, inputData);

        SurfaceData surfaceData = (SurfaceData)0;
        surfaceData.albedo = albedo;
        surfaceData.alpha = alpha;
        surfaceData.normalTS = normalTS;
        surfaceData.smoothness = smoothness;
        surfaceData.occlusion = (half)1.0;
        surfaceData.metallic = metallic;
        surfaceData.specular = half3(0.0, 0.0, 0.0);

    // #if defined(_DBUFFER)
    //     half3 specular = half3(0.0, 0.0, 0.0);
    //     ApplyDecal(IN.clipPos,
    //         albedo,
    //         specular,
    //         inputData.normalWS,
    //         metallic,
    //         occlusion,
    //         smoothness);
    // #endif

    #ifdef _DBUFFER
        ApplyDecalToSurfaceData(IN.clipPos, surfaceData, inputData);
    #endif

    #ifdef TERRAIN_GBUFFER

    //  crazy alpha
        #ifndef TERRAIN_SPLAT_BASEPASS
            alpha *= dot(splatControl, 1.0h);
        #endif

        BRDFData brdfData;
        //InitializeBRDFData(albedo, metallic, /* specular */ half3(0.0h, 0.0h, 0.0h), smoothness, alpha, brdfData);
        InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

        // Baked lighting.
        half4 color;
        Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
        color.rgb = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
        color.a = surfaceData.alpha;
        SplatmapFinalColor(color, inputData.fogCoord);

        // Dynamic lighting: emulate SplatmapFinalColor() by scaling gbuffer material properties. This will not give the same results
        // as forward renderer because we apply blending pre-lighting instead of post-lighting.
        // Blending of smoothness and normals is also not correct but close enough?
        brdfData.albedo.rgb *= surfaceData.alpha;
        brdfData.diffuse.rgb *= surfaceData.alpha;
        brdfData.specular.rgb *= surfaceData.alpha;
        brdfData.reflectivity *= surfaceData.alpha;
    //  We can not bend normals when using _GBUFFER_NORMALS_OCT
        #if defined(_GBUFFER_NORMALS_OCT)
            #if defined(TERRAIN_SPLAT_ADDPASS)
                inputData.normalWS = 0;
            #endif
            inputData.normalWS = inputData.normalWS;
        #else 
            inputData.normalWS = inputData.normalWS * surfaceData.alpha;
        #endif
        smoothness *= surfaceData.alpha;

        return BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, color.rgb, surfaceData.occlusion);

    #else
        //half4 color = UniversalFragmentPBR(inputData, albedo, metallic, /* specular */ half3(0.0h, 0.0h, 0.0h), smoothness, occlusion, /* emission */ half3(0, 0, 0), alpha);
        half4 color = UniversalFragmentPBR(inputData, surfaceData);
        SplatmapFinalColor(color, inputData.fogCoord);
        outColor = half4(color.rgb, 1.0h);

        #ifdef _WRITE_RENDERING_LAYERS
            uint renderingLayers = GetMeshRenderingLayer();
            outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
        #endif
    #endif
    }


    // -----------------------------------------------------------------------------
    // Shadow pass

    // x: global clip space bias, y: normal world space bias
    float3 _LightDirection;
    float3 _LightPosition;

    struct AttributesLean {
        float4 positionOS     : POSITION;
        float3 normalOS       : NORMAL;
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    #ifdef _ALPHATEST_ON
        Varyings ShadowPassVertex (Attributes v)
        {
            Varyings o = (Varyings)0;
            UNITY_SETUP_INSTANCE_ID(v);
            TerrainInstancing(v.positionOS, v.normalOS, v.texcoord);
            o.uvMainAndLM.xy = v.texcoord;
            float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
            float3 normalWS = TransformObjectToWorldNormal(v.normalOS);

            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
                float3 lightDirectionWS = _LightDirection;
            #endif

            float4 clipPos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
            #if UNITY_REVERSED_Z
                clipPos.z = min(clipPos.z, UNITY_NEAR_CLIP_VALUE);
            #else
                clipPos.z = max(clipPos.z, UNITY_NEAR_CLIP_VALUE);
            #endif
            o.clipPos = clipPos;
            return o;
        }
        half4 ShadowPassFragment(Varyings input) : SV_TARGET {
            //ClipHoles(IN.tc.xy);
            half hole = SAMPLE_TEXTURE2D(_TerrainHolesTexture, sampler_TerrainHolesTexture, input.uvMainAndLM.xy).r;
            clip(hole == 0.0h ? -1 : 1);
            return 0;
        }
    #else
        float4 ShadowPassVertex(AttributesLean v) : SV_POSITION {
            Varyings o;
            UNITY_SETUP_INSTANCE_ID(v);
            TerrainInstancing(v.positionOS, v.normalOS);
            float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
            float3 normalWS = TransformObjectToWorldNormal(v.normalOS);

            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
                float3 lightDirectionWS = _LightDirection;
            #endif

            float4 clipPos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
            #if UNITY_REVERSED_Z
                clipPos.z = min(clipPos.z, UNITY_NEAR_CLIP_VALUE);
            #else
                clipPos.z = max(clipPos.z, UNITY_NEAR_CLIP_VALUE);
            #endif
            return clipPos;
        }
        half4 ShadowPassFragment(Varyings input) : SV_TARGET {
            return 0;
        }
    #endif



    // -----------------------------------------------------------------------------
    // Depth pass

    //
    #ifdef _ALPHATEST_ON
        Varyings DepthOnlyVertex(Attributes v) {
            Varyings o = (Varyings)0;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
            TerrainInstancing(v.positionOS, v.normalOS, v.texcoord);
            o.uvMainAndLM.xy = v.texcoord;
            o.clipPos = TransformObjectToHClip(v.positionOS.xyz);
            return o;
        }

        half4 DepthOnlyFragment(Varyings input) : SV_TARGET {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            //ClipHoles(input.tc.xy);
            half hole = SAMPLE_TEXTURE2D(_TerrainHolesTexture, sampler_TerrainHolesTexture, input.uvMainAndLM.xy).r;
            clip(hole == 0.0h ? -1 : 1);
            
            #ifdef SCENESELECTIONPASS
            // We use depth prepass for scene selection in the editor, this code allow to output the outline correctly
                return half4(_ObjectId, _PassValue, 1.0, 1.0);
            #endif

            return input.clipPos.z;
        }

    #else
        //float4 DepthOnlyVertex(AttributesLean v) : SV_POSITION {
        Varyings DepthOnlyVertex(AttributesLean v) {
            Varyings o = (Varyings)0;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
            TerrainInstancing(v.positionOS, v.normalOS);
            //return TransformObjectToHClip(v.positionOS.xyz);
            o.clipPos = TransformObjectToHClip(v.positionOS.xyz);
            return o;
        }

        half4 DepthOnlyFragment(Varyings input) : SV_TARGET {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            #ifdef SCENESELECTIONPASS
            // We use depth prepass for scene selection in the editor, this code allow to output the outline correctly
                return half4(_ObjectId, _PassValue, 1.0, 1.0);
            #endif

            return input.clipPos.z;
        }
    #endif

    // -----------------------------------------------------------------------------
    // DepthNormal pass
    
    struct AttributesDepthNormal
    {
        float4 positionOS : POSITION;
        float3 normalOS : NORMAL;
        float2 texcoord : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct VaryingsDepthNormal
    {
        float4 uvMainAndLM                  : TEXCOORD0; // xy: control, zw: lightmap
        #ifndef TERRAIN_SPLAT_BASEPASS
            float4 uvSplat01                : TEXCOORD1; // xy: splat0, zw: splat1
            float4 uvSplat23                : TEXCOORD2; // xy: splat2, zw: splat3
        #endif

        #if defined(_NORMALMAP) && !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
            half3 normal                   : TEXCOORD3;   
            half4 tangent                  : TEXCOORD4;  
        #else
            half3 normal                   : TEXCOORD3;
        #endif

        float3 positionWS                  : TEXCOORD6;

        float4 clipPos                     : SV_POSITION;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    VaryingsDepthNormal DepthNormalOnlyVertex(AttributesDepthNormal v)
    {
        VaryingsDepthNormal o = (VaryingsDepthNormal)0;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
        TerrainInstancing(v.positionOS, v.normalOS, v.texcoord);

        VertexPositionInputs Attributes = GetVertexPositionInputs(v.positionOS.xyz);

        o.uvMainAndLM.xy = v.texcoord;
        o.uvMainAndLM.zw = v.texcoord * unity_LightmapST.xy + unity_LightmapST.zw;
        #ifndef TERRAIN_SPLAT_BASEPASS
            #if defined(_PROCEDURALTEXTURING)
                o.uvSplat01.xy = Attributes.positionWS.xz / _ProceduralTiling;       
            #else
                o.uvSplat01.xy = TRANSFORM_TEX(v.texcoord, _Splat0);
            #endif
            o.uvSplat01.zw = TRANSFORM_TEX(v.texcoord, _Splat1);
            o.uvSplat23.xy = TRANSFORM_TEX(v.texcoord, _Splat2);
            o.uvSplat23.zw = TRANSFORM_TEX(v.texcoord, _Splat3);
        #endif

        #if defined(_NORMALMAP) && !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL) && defined(_NORMALINDEPTHNORMALPASS)
            float4 vertexTangent = float4(cross(float3(0, 0, 1), v.normalOS), 1.0);
            VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, vertexTangent);
            o.normal = normalInput.normalWS;
            real sign = vertexTangent.w * GetOddNegativeScale();
            o.tangent = half4(normalInput.tangentWS, sign);
        #else
            o.normal = TransformObjectToWorldNormal(v.normalOS);
        #endif

        o.positionWS = Attributes.positionWS;
        o.clipPos = Attributes.positionCS;
        return o;
    }


    void DepthNormalOnlyFragment(
        VaryingsDepthNormal IN
        , out half4 outNormalWS : SV_Target0
    #ifdef _WRITE_RENDERING_LAYERS
        , out float4 outRenderingLayers : SV_Target1
    #endif
        )
    {

        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

        #ifdef _ALPHATEST_ON
            ClipHoles(IN.uvMainAndLM.xy);
        #endif

    //  -----

        half3 fnormalWS;
        half3 normalTS = half3(0.0h, 0.0h, 1.0h);
        half3x3 tangentSpaceRotation = 0;
        half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);

        #if defined(_NORMALINDEPTHNORMALPASS)
            #if defined(_NORMALMAP) || defined(_PARALLAX) || defined(TERRAIN_SPLAT_BASEPASS)
                
                #if !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL) && ( defined(_NORMALMAP) || defined(_PARALLAX) )
                //  Same matrix we need to transfer the normalTS
                    half3 tangentWS = -IN.tangent.xyz;
                    half3 bitangentWS = cross(IN.normal, IN.tangent.xyz);
                    tangentSpaceRotation = half3x3(tangentWS.xyz, bitangentWS, IN.normal.xyz);
                    half3 viewDirTS = normalize( mul(tangentSpaceRotation, viewDirectionWS ) );
                
                #elif defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
                    float2 sampleCoords = (IN.uvMainAndLM.xy / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
                    half3 normalWS = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
                //  fix orientation
                    half3 tangentWS = cross( /*GetObjectToWorldMatrix()._13_23_33*/ half3(0, 0, 1), normalWS) * -1;
                //  Ups: * -1?
                    half3 bitangentWS = cross(normalWS, tangentWS) * -1;
                    tangentSpaceRotation =  half3x3(tangentWS, bitangentWS, normalWS);
                    half3 viewDirTS = normalize( mul(tangentSpaceRotation, viewDirectionWS) );
                #endif
            
            #endif
        #endif

        #if defined(TERRAIN_SPLAT_BASEPASS) || !defined(_NORMALINDEPTHNORMALPASS) || !defined(_NORMALMAP)
            fnormalWS = IN.normal;
        #else
            half4 splatControl;
            half weight;
            half4 mixedDiffuse;
            half4 defaultSmoothness;

            float2 splatUV = (IN.uvMainAndLM.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
            splatControl = SAMPLE_TEXTURE2D(_Control, sampler_Control, splatUV);

        //  Sample heights // sampler_Splat0 not defined -> sampler_Normal0
            #ifdef _TERRAIN_BLEND_HEIGHT
                half4 heights;
                #if defined(_PROCEDURALTEXTURING)
                    half proceduralHeight;
                    float2 uv1, uv2, uv3;
                    float w1, w2, w3;
                    float2 duvdx, duvdy;
                    GetProceduralBaseSample(_HeightMaps, sampler_Normal0, IN.uvSplat01.xy, proceduralHeight, uv1, uv2, uv3, w1, w2, w3, duvdx, duvdy);
                    heights.x = proceduralHeight;
                #else
                    heights.x = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Normal0, IN.uvSplat01.xy).r;
                #endif
                heights.y = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Normal0, IN.uvSplat01.zw).g;
                heights.z = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Normal0, IN.uvSplat23.xy).b;
                heights.w = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Normal0, IN.uvSplat23.zw).a;

                half height;
            //  Adjust splatControl and calculate 1st height
                HeightBasedSplatModifyCombined(splatControl, heights, height);

            //  Parallax Extrusion
                #if defined(_PARALLAX)
                    float3 v = viewDirTS;
                    v.z += 0.42;
                    v.xy /= v.z;
                    half halfParallax = _Parallax * 0.5h;
                    
                    half parallax = height * _Parallax - halfParallax;
                    float2 offset1 = parallax * v.xy;

                    float4 splatUV1 = IN.uvSplat01 + offset1.xyxy;
                    float4 splatUV2 = IN.uvSplat23 + offset1.xyxy;

                    #if defined(_PROCEDURALTEXTURING)
                        float2 uv1_o = uv1 + offset1;
                        float2 uv2_o = uv2 + offset1;
                        float2 uv3_o = uv3 + offset1;
                        heights.x = sampleProceduralHalf(_HeightMaps, sampler_Normal0, splatUV1.xy, uv1_o, uv2_o, uv3_o, w1, w2, w3, duvdx, duvdy);
                    #else
                        heights.x = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Normal0, splatUV1.xy).r;
                    #endif
                    heights.y = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Normal0, splatUV1.zw).g;
                    heights.z = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Normal0, splatUV2.xy).b;
                    heights.w = SAMPLE_TEXTURE2D(_HeightMaps, sampler_Normal0, splatUV2.zw).a;

                //  Calculate 2nd height
                    half height1 = max( max(heights.x, heights.y), max(heights.z, heights.w) );
                    parallax = height1 * _Parallax - halfParallax;
                    float2 offset2 =  parallax * v.xy;
                    
                    offset1 = (offset1 + offset2) * 0.5;
                    IN.uvSplat01 += offset1.xyxy;
                    IN.uvSplat23 += offset1.xyxy;
                    
                    #if defined(_PROCEDURALTEXTURING)
                        uv1 += offset1;
                        uv2 += offset1;
                        uv3 += offset1;
                    #endif

                #endif
            #endif

            #if defined(_PROCEDURALTEXTURING)
                #ifdef _TERRAIN_BLEND_HEIGHT
                    SplatmapMixProcedural(IN.uvMainAndLM, IN.uvSplat01, IN.uvSplat23, splatControl, weight, mixedDiffuse, defaultSmoothness, normalTS,
                    uv1, uv2, uv3, w1, w2, w3, duvdx, duvdy, true);
                #else
                    SplatmapMix(IN.uvMainAndLM, IN.uvSplat01, IN.uvSplat23, splatControl, weight, mixedDiffuse, defaultSmoothness, normalTS, true);
                #endif
            #else
                SplatmapMix(IN.uvMainAndLM, IN.uvSplat01, IN.uvSplat23, splatControl, weight, mixedDiffuse, defaultSmoothness, normalTS, true);
            #endif
        
            fnormalWS = TransformTangentToWorld(normalTS, tangentSpaceRotation);

        #endif

    //  -----

        #if defined(_GBUFFER_NORMALS_OCT)
            fnormalWS = normalize(fnormalWS);
            float2 octNormalWS = PackNormalOctQuadEncode(fnormalWS);           // values between [-1, +1], must use fp32 on some platforms.
            float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
            half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
            outNormalWS = half4(packedNormalWS, 0.0);
        #else
            fnormalWS = NormalizeNormalPerPixel(fnormalWS);
            outNormalWS = half4(fnormalWS, 0.0);
        #endif

        #ifdef _WRITE_RENDERING_LAYERS
            uint renderingLayers = GetMeshRenderingLayer();
            outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
        #endif
    }

#endif