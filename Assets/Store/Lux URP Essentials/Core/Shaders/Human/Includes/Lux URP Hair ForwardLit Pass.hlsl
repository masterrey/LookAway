#ifndef HAIR_CORE_INCLUDED
#define HAIR_CORE_INCLUDED

#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs
struct Attributes
{
    float3 positionOS                   : POSITION;
    float3 normalOS                     : NORMAL;
    float4 tangentOS                    : TANGENT;
    float2 texcoord                     : TEXCOORD0;
    #if defined(LIGHTMAP_ON)
        float2 staticLightmapUV         : TEXCOORD1;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV        : TEXCOORD2;
    #endif
    half4 color                         : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
    
struct Varyings
{
    float2 uv                           : TEXCOORD0;
    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        float3 positionWS               : TEXCOORD1;
    #endif
    half3 normalWS                      : TEXCOORD2;
//  Hair lighting always needs tangent
    half4 tangentWS                     : TEXCOORD3;
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half4 fogFactorAndVertexLight   : TEXCOORD4;
    #else
        half  fogFactor                 : TEXCOORD4;
    #endif
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord              : TEXCOORD5;
    #endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 6);
    #ifdef DYNAMICLIGHTMAP_ON
        float2  dynamicLightmapUV       : TEXCOORD7;
    #endif

    float4 positionCS                   : SV_POSITION;
    
    half4 color                         : COLOR;

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


//--------------------------------------
//  Vertex shader

    Varyings LitPassVertex(Attributes input)
    {
        Varyings output = (Varyings)0;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_TRANSFER_INSTANCE_ID(input, output);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
        half fogFactor = 0.0h;
        #if !defined(_FOG_FRAGMENT)
            fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
        #endif

        output.uv.xy = input.texcoord;

    //  Hair lighting always needs tangent
        output.normalWS = normalInput.normalWS;
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = float4(normalInput.tangentWS.xyz, sign);

        OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
        #ifdef DYNAMICLIGHTMAP_ON
            output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
        #endif
        OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
        
        #ifdef _ADDITIONAL_LIGHTS_VERTEX
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
        #else
            output.fogFactor = fogFactor;
        #endif

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            output.positionWS = vertexInput.positionWS;
        #endif

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            output.shadowCoord = GetShadowCoord(vertexInput);
        #endif
        output.positionCS = vertexInput.positionCS;

        output.color = input.color;

        return output;
    }

//--------------------------------------
//  Fragment shader and functions

    float Dither32(float2 Pos, float frameIndexMod4)
    {
        uint3 k0 = uint3(13, 5, 15);
        float Ret = dot(float3(Pos.xy, frameIndexMod4 + 0.5f), k0 / 32.0f);
        return frac(Ret);
    }

    inline void InitializeHairLitSurfaceData(float2 uv, half4 vertexColor, out SurfaceData outSurfaceData, out AdditionalSurfaceData outAdditionalSurfaceData)
    {
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
        
            // a2c sharpened
            // (col.a - _Cutoff) / max(fwidth(col.a), 0.0001) + 0.5;
            
            // float2 ditherUV = screenPos.xy / screenPos.w;
            // ditherUV *= _ScreenParams.xy * _Dither_TexelSize.xy;
            // half BlueNoise = SAMPLE_TEXTURE2D(_Dither, sampler_Dither, ditherUV).a;
            // clip(albedoAlpha.a - clamp(BlueNoise, 0.1, _Cutoff));
            // outSurfaceData.alpha = 1;
            
            //clip( albedoAlpha.a - Dither32( screenPos.xy / screenPos.w * _ScreenParams.xy, _FrameIndexMod4  ));
        
        outSurfaceData.albedo = albedoAlpha.rgb;

        outSurfaceData.albedo *= lerp(_SecondaryColor.rgb, _BaseColor.rgb, vertexColor.a),

        outSurfaceData.metallic = half(0.0);
        outSurfaceData.specular = _SpecColor.rgb;
    
    //  Normal Map
        #if defined (_NORMALMAP)
            outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        #else
            outSurfaceData.normalTS = half3(0,0,1);
        #endif

        //outSurfaceData.occlusion = lerp(1.0h, SSSAOSample.a, _OcclusionStrength);

        #if defined(_MASKMAP)
            half4 MaskMapSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, uv);
            outSurfaceData.occlusion = MaskMapSample.g; //lerp(1.0h, SSSAOSample.a, _OcclusionStrength);
            outAdditionalSurfaceData.shift = MaskMapSample.b;
        #else
            outSurfaceData.occlusion = half(1.0);
            outAdditionalSurfaceData.shift = half(1.0);
        #endif

        outSurfaceData.smoothness = _Smoothness;
        outSurfaceData.emission = half(0.0);

        outSurfaceData.clearCoatMask = half(0.0);
        outSurfaceData.clearCoatSmoothness = half(0.0);

    }

    void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
    {
        inputData = (InputData)0;
        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            inputData.positionWS = input.positionWS;
        #endif
        
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
        
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
    
        inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
        inputData.viewDirectionWS = viewDirWS;
        
        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            inputData.shadowCoord = input.shadowCoord;
        #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
            inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
        #else
            inputData.shadowCoord = float4(0, 0, 0, 0);
        #endif
        
        #ifdef _ADDITIONAL_LIGHTS_VERTEX
            inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
            inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
        #else
            inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
        #endif
        
        #if defined(DYNAMICLIGHTMAP_ON)
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
        #else
            inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
        #endif

        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
        inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

        #if defined(DEBUG_DISPLAY)
        #if defined(DYNAMICLIGHTMAP_ON)
        inputData.dynamicLightmapUV = input.dynamicLightmapUV;
        #endif
        #if defined(LIGHTMAP_ON)
        inputData.staticLightmapUV = input.staticLightmapUV;
        #else
        inputData.vertexSH = input.vertexSH;
        #endif
        #endif
    }

    // half4 LitPassFragment(Varyings input
    //     #if defined(_ENABLEVFACE)
    //         , half facing : VFACE
    //     #endif
    //     ) : SV_Target
    // {

    void LitPassFragment(
        Varyings input
    #if defined(_ENABLEVFACE)
        , half facing : VFACE
    #endif
        , out half4 outColor : SV_Target0
    #ifdef _WRITE_RENDERING_LAYERS
        , out float4 outRenderingLayers : SV_Target1
    #endif
    )
    {

        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        #ifdef LOD_FADE_CROSSFADE
            LODFadeCrossFade(input.positionCS);
        #endif

    //  Get the surface description
        SurfaceData surfaceData;
        AdditionalSurfaceData additionalSurfaceData;
        InitializeHairLitSurfaceData(input.uv.xy, input.color, surfaceData, additionalSurfaceData);

    //  Handle VFACE
        #if defined(_ENABLEVFACE)
            surfaceData.normalTS.z *= facing;
        #endif

    //  Prepare surface data (like bring normal into world space and get missing inputs like gi
        InputData inputData;
        InitializeInputData(input, surfaceData.normalTS, inputData);

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif
#endif

        #if defined(_RIMLIGHTING)
            half rim = saturate(1.0h - saturate( dot(inputData.normalWS, inputData.viewDirectionWS) ) );
            half power = _RimPower;
            if(_RimFrequency > 0 ) {
                half perPosition = lerp(0.0h, 1.0h, dot(1.0h, frac(UNITY_MATRIX_M._m03_m13_m23) * 2.0h - 1.0h ) * _RimPerPositionFrequency ) * 3.1416h;
                power = lerp(power, _RimMinPower, (1.0h + sin(_Time.y * _RimFrequency + perPosition) ) * 0.5h );
            }
            surfaceData.emission += pow(rim, power) * _RimColor.rgb * _RimColor.a;
        #endif

    //  Apply lighting
        half4 color = LuxURPHairFragment(
            inputData,
            surfaceData,
            input.tangentWS.xyz,
            surfaceData.albedo, // noise
            _SpecularShift * additionalSurfaceData.shift,
            _SpecularTint.rgb,
            _SpecularExponent,
            _SecondarySpecularShift * additionalSurfaceData.shift,
            _SecondarySpecularTint.rgb,
            _SecondarySpecularExponent,
            _RimTransmissionIntensity,
            _AmbientReflection
        );
        color.a =  surfaceData.alpha;   
    //  Add fog
        color.rgb = MixFog(color.rgb, inputData.fogCoord);
        outColor = color;

        #ifdef _WRITE_RENDERING_LAYERS
            uint renderingLayers = GetMeshRenderingLayer();
            outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
        #endif
    }

#endif