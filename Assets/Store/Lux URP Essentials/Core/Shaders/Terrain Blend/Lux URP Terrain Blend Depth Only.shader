Shader "Lux URP/Terrain/Blend Depth Only"
{
    Properties
    {
        [NoScaleOffset]
        _TerrainHeightNormal        ("Terrain Height Normal", 2D) = "white" {}
        [LuxURPVectorThreeDrawer]
        _TerrainPos                 ("Terrain Position", Vector) = (0,0,0,0)
        [LuxURPVectorThreeDrawer]
        _TerrainSize                ("Terrain Size", Vector) = (1,1,1,0)

        [Space(5)]
        _NormalShift                ("Normal Shift", Range(-5, 5)) = 0
        _NormalWidth                ("Normal Contraction", Range(0, 20)) = 0
        _NormalThreshold            ("Normal Threshold", Range(0,1)) = .2

        
        [Header(Surface Inputs)]
        [Space(8)]
        [MainColor]
        _BaseColor                  ("Color", Color) = (1,1,1,1)
        [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}

        [Space(5)]
        _Smoothness                 ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor                  ("Specular", Color) = (0.2, 0.2, 0.2)

        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Map", Float) = 0.0
        _BumpMap                    ("     Normal Map", 2D) = "bump" {}
        _BumpScale                  ("     Normal Scale", Float) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry-2"
        }
        LOD 100


    //  Depth Only in Lit Pass -----------------------------------------------------

        Pass
        {
        Name "ForwardLit"
        Tags{"LightMode" = "UniversalForward"}

            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //  Material Inputs
            CBUFFER_START(UnityPerMaterial)
                float3  _TerrainPos;
                float3  _TerrainSize;
                float4  _TerrainHeightNormal_TexelSize;
                half    _NormalShift;
                half    _NormalWidth;
                half    _NormalThreshold;
                half    _BumpScale;
                float4  _BaseMap_ST;
                half3   _BaseColor;
                half3   _SpecColor;
            CBUFFER_END
 
            struct VertexInput {
                float3 positionOS                   : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput {
                float4 positionCS     : SV_POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };


            VertexOutput DepthOnlyVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 DepthOnlyFragment(VertexOutput input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                return 0;
            }

            ENDHLSL
        }


    //  GBuffer Pass - minimalized which only outputs depth and writes into the normal buffers  
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _NORMALMAP

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            //#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

        //  As we do not store the alpha mask with the base map we have to use custom functions 
            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            //  Material Inputs
            CBUFFER_START(UnityPerMaterial)
                float3  _TerrainPos;
                float3  _TerrainSize;
                float4  _TerrainHeightNormal_TexelSize;
                half    _NormalShift;
                half    _NormalWidth;
                half    _NormalThreshold;
                half    _BumpScale;
                float4  _BaseMap_ST;
                half3   _BaseColor;
                half3   _SpecColor;
            CBUFFER_END
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            TEXTURE2D(_TerrainHeightNormal); SAMPLER(sampler_TerrainHeightNormal);

            struct Attributes {
                float3 positionOS                   : POSITION;
                float2 texcoord                     : TEXCOORD0;
                float3 normalOS                     : NORMAL;
                #if defined(_NORMALMAP)
                    float4 tangentOS                : TANGENT;
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS     : SV_POSITION;
                float2 uv             : TEXCOORD0;
                half3 normalWS        : TEXCOORD1;
                #if defined(_NORMALMAP)
                    half4 tangentWS   : TEXCOORD2;
                #endif
                float3 positionWS     : TEXCOORD3;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord              : TEXCOORD5;
                #endif

                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
                #ifdef DYNAMICLIGHTMAP_ON
                    float2  dynamicLightmapUV       : TEXCOORD8; // Dynamic lightmap UVs
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings LitGBufferPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

            //  Normal output is only really needed if SSAO is enabled
                #if defined(_NORMALMAP)
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                    half sign = input.tangentOS.w * GetOddNegativeScale();
                    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
                #else
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
                #endif
                output.normalWS = normalInput.normalWS;

                OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
                #ifdef DYNAMICLIGHTMAP_ON
                    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

                return output;
            }

            inline float DecodeFloatRG( float2 enc ) {
                float2 kDecodeDot = float2(1.0, 1/255.0);
                return dot( enc, kDecodeDot );
            }

            FragmentOutput LitGBufferPassFragment(Varyings input, half facing : VFACE)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;
                half smoothness = albedoAlpha.a;

            //  Get terrain uv
                float2 terrainUV = (input.positionWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
                terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;
                half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
                float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;
            //  Blend geometry normal towards the terrain normal
                half3 terrainNormal;
            //  This is not a tangent normal! So we have to swizzle y and z.
                terrainNormal.xz = terrainSample.ba * 2.0 - 1.0;
                terrainNormal.y = sqrt(1.0 - saturate(dot(terrainNormal.xz, terrainNormal.xz)));
                half normalBlend = saturate( (terrainHeight - input.positionWS.y + _NormalShift) * _NormalWidth );  
                normalBlend = normalBlend * (smoothstep( 0, _NormalThreshold, saturate(dot(terrainNormal.xyz, input.normalWS.xyz ))));
                normalBlend = 1.0h - normalBlend;
                input.normalWS.xyz = lerp( terrainNormal.xyz, input.normalWS.xyz, normalBlend);
                
                #if defined(_NORMALMAP)
                    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv), _BumpScale);
                    normalTS.z *= facing;
                    float sgn = input.tangentWS.w;      // should be either +1 or -1
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    half3x3 ToW = half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz);
                    input.normalWS = TransformTangentToWorld(normalTS, ToW);
                #else
                    input.normalWS *= facing;
                #endif



                half3 packedNormalWS = PackNormal(input.normalWS);
                // FragmentOutput output = (FragmentOutput)0;

                // output.GBuffer0 = half4(albedo, 1); 
                // output.GBuffer2 = half4(packedNormalWS, 1);  
                // return output;

                InputData inputData = (InputData)0;
                inputData.normalWS = input.normalWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = input.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif

                #if defined(DYNAMICLIGHTMAP_ON)
                    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
                #else
                    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
                #endif
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

                half metallic = 0;
                half3 specular = _SpecColor;
                half alpha = 1;
                half occlusion = 1;

                BRDFData brdfData;
                InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);
                Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
                MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
                half3 color = GlobalIllumination(brdfData, inputData.bakedGI, occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);


                return BRDFDataToGbuffer(brdfData, inputData, smoothness, 0 + color, 1); //surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);
            }
            ENDHLSL
        }


        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float3  _TerrainPos;
                float3  _TerrainSize;
                float4  _TerrainHeightNormal_TexelSize;
                half    _NormalShift;
                half    _NormalWidth;
                half    _NormalThreshold;
                half    _BumpScale;
                float4  _BaseMap_ST;
                half3   _BaseColor;
                half3   _SpecColor;
            CBUFFER_END

            struct Attributes
            {
                float4 position     : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.position.xyz);
                return output;
            }

            half DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                return input.positionCS.z;
            }

            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            #pragma shader_feature_local _NORMALMAP

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //  Material Inputs
            CBUFFER_START(UnityPerMaterial)
                float3  _TerrainPos;
                float3  _TerrainSize;
                float4  _TerrainHeightNormal_TexelSize;
                half    _NormalShift;
                half    _NormalWidth;
                half    _NormalThreshold;
                half    _BumpScale;
                float4  _BaseMap_ST;
                half3   _BaseColor;
                half3   _SpecColor;
            CBUFFER_END
            TEXTURE2D(_TerrainHeightNormal); SAMPLER(sampler_TerrainHeightNormal);
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
 
            struct Attributes {
                float3 positionOS     : POSITION;
                float2 texcoord       : TEXCOORD0;
                float3 normal         : NORMAL;
                float4 tangentOS      : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS     : SV_POSITION;
            #if defined(_NORMALMAP)
                float2 uv             : TEXCOORD0;
            #endif
                float3 normalWS       : TEXCOORD1;
            #if defined(_NORMALMAP)
                half4 tangentWS       : TEXCOORD2;
            #endif
                float3 positionWS     : TEXCOORD3;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };


            Varyings DepthNormalsVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normal, input.tangentOS);
                output.normalWS = half3(normalInput.normalWS);
                
                #if defined(_NORMALMAP)
                    float sign = input.tangentOS.w * float(GetOddNegativeScale());
                    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
                    output.tangentWS = tangentWS;
                    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif

                return output;
            }

            inline float DecodeFloatRG( float2 enc ) {
                float2 kDecodeDot = float2(1.0, 1/255.0);
                return dot( enc, kDecodeDot );
            }

            void DepthNormalsFragment(
                Varyings input
                , out half4 outNormalWS : SV_Target0
            #ifdef _WRITE_RENDERING_LAYERS
                , out float4 outRenderingLayers : SV_Target1
            #endif
            )
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            //  Get terrain uv
                float2 terrainUV = (input.positionWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
                terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;
                half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
                float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;
            //  Blend geometry normal towards the terrain normal
                half3 terrainNormal;
            //  This is not a tangent normal! So we have to swizzle y and z.
                terrainNormal.xz = terrainSample.ba * 2.0 - 1.0;
                terrainNormal.y = sqrt(1.0 - saturate(dot(terrainNormal.xz, terrainNormal.xz)));
                half normalBlend = saturate( (terrainHeight - input.positionWS.y + _NormalShift) * _NormalWidth );  
                normalBlend = normalBlend * (smoothstep( 0, _NormalThreshold, saturate(dot(terrainNormal.xyz, input.normalWS.xyz ))));
                normalBlend = 1.0h - normalBlend;
                input.normalWS.xyz = lerp( terrainNormal.xyz, input.normalWS.xyz, normalBlend);
                
                //float3 normalWS = input.normalWS;

                #if defined(_NORMALMAP)
                    float2 uv = input.uv;
                    float sgn = input.tangentWS.w;      // should be either +1 or -1
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    float3 normalTS = UnpackNormalScale( SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv), _BumpScale);
                    float3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
                #else 
                    half3 normalWS = input.normalWS.xyz;
                #endif

                outNormalWS = half4(NormalizeNormalPerPixel(normalWS), 0.0);

                #ifdef _WRITE_RENDERING_LAYERS
                    uint renderingLayers = GetMeshRenderingLayer();
                    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
                #endif
            }

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }
    FallBack "Hidden/InternalErrorShader"
}