Shader "Lux URP/Minimal GBuffer Pass"
{   
    Properties
    {
        [Header(Surface Options)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                       ("Culling", Float) = 2
        [Toggle(_ALPHATEST_ON)]
        _AlphaClip                  ("Alpha Clipping", Float) = 0.0
        _Cutoff                     ("     Threshold", Range(0.0, 1.0)) = 0.5

        [Header(Surface Inputs)]
        [Space(8)]
        [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}

        [Space(5)]
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
            "Queue" = "Geometry"
        }
        LOD 100

    //  GBuffer Pass not needed any more? - It is because of fucking decals and octha normals!
    //  GBuffer Pass - minimalized which only outputs depth and writes into the normal buffers  
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

        //  We only write to the normals buffer
            ColorMask 0 0       // albedo, materialFlags
            ColorMask 0 1       // specular, occlusion
            ColorMask RGB 2     // encoded-normal(rgb), smoothness
            ColorMask 0 3       // GI (rgb)
            ColorMask 0 4       // ShadowMask
            

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
        //  We do not output the per pixel normal as it would influence coat lighting as well :(
            // #pragma shader_feature_local _NORMALMAP

            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
        //  Not per fragment as we use it to kill triangles in the vertex shader
            //#pragma multi_compile _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            //#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

        //  Material Inputs
        //  We include LitInput.hlsl - so no cbuffer definition here

            struct Attributes {
                float3 positionOS                   : POSITION;
                float3 normalOS                     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS     : SV_POSITION;
                half3 normalWS        : TEXCOORD1;
                //UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings LitGBufferPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
                output.normalWS = normalInput.normalWS;
                return output;
            }

            FragmentOutput LitGBufferPassFragment(Varyings input)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif
                
                half3 packedNormalWS = PackNormal(input.normalWS);
                FragmentOutput output = (FragmentOutput)0;
                output.GBuffer2 = half4(packedNormalWS, 1);  
                return output;
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

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON      // not per fragment!
            #pragma shader_feature_local _NORMALMAP         // not per fragment!

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            // #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl" // needs shader target 4.5
            
            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            #define DEPTHNORMALPASS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            CBUFFER_START(UnityPerMaterial)
                half    _Cutoff;
                half    _BumpScale;
                float4  _BaseMap_ST;
                float4  _BumpMap_ST;
            CBUFFER_END

            #if defined(_ALPHATEST_ON)
                TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            #endif

            #if defined(_NORMALMAP)
                TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            #endif

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
                float4 uv             : TEXCOORD0;
                half3 normalWS        : TEXCOORD1;
                #if defined(_NORMALMAP)
                    half4 tangentWS   : TEXCOORD2;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings DepthNormalVertex(Attributes input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                Varyings output = (Varyings)0;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if defined(_ALPHATEST_ON)
                    output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif
                #if defined(_NORMALMAP)
                    output.uv.zw = TRANSFORM_TEX(input.texcoord, _BumpMap);
                #endif

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                #if defined(_NORMALMAP)
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                    output.normalWS = normalInput.normalWS;
                    real sgn = input.tangentOS.w * GetOddNegativeScale();
                    half4 tangentWS = half4(normalInput.tangentWS, sgn);
                    output.tangentWS = tangentWS;
                #else
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1)); //input.tangentOS);
                    output.normalWS = normalInput.normalWS;
                #endif

                return output;
            }

            void DepthNormalFragment(
                Varyings input
                , out half4 outNormalWS : SV_Target0
            #ifdef _WRITE_RENDERING_LAYERS
                , out float4 outRenderingLayers : SV_Target1
            #endif
            )
            {

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #if defined(_ALPHATEST_ON)
                    half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy).a;
                    clip (mask - _Cutoff);
                #endif

                #if defined(_NORMALMAP)
                    half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.zw);
                    #if BUMP_SCALE_NOT_SUPPORTED
                        half3 normalTS = UnpackNormal(n);
                    #else
                        half3 normalTS = UnpackNormalScale(n, _BumpScale);
                    #endif
                    float sgn = input.tangentWS.w;      // should be either +1 or -1
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    input.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
                #endif

                #if defined(_GBUFFER_NORMALS_OCT)
                    half3 normalWS = normalize(input.normalWS);
                    float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
                    float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
                    half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
                    outNormalWS = half4(normalWS, 0.0);
                #else
                    half3 normalWS = NormalizeNormalPerPixel(input.normalWS);
                    outNormalWS = half4(normalWS, 0.0);
                #endif

                #ifdef _WRITE_RENDERING_LAYERS
                    uint renderingLayers = GetMeshRenderingLayer();
                    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
                #endif
            }
            ENDHLSL
        }



    }
}