Shader "Lux URP/Depth Only"
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

    //  Depth -----------------------------------------------------
    //  Pass needed to receive proper shadows

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            //  Material Inputs
            CBUFFER_START(UnityPerMaterial)
                half    _Cutoff;
                half    _BumpScale;
                float4  _BaseMap_ST;
                float4  _BumpMap_ST;
            CBUFFER_END

            #if defined(_ALPHATEST_ON)
                TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            #endif

            struct Attributes {
                float3 positionOS                   : POSITION;
                float2 texcoord                     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS     : SV_POSITION;
                float2 uv             : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };


            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                #if defined(_ALPHATEST_ON)
                    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif

                #if defined(_ALPHATEST_ON)
                    half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy).a;
                    clip (mask - _Cutoff);
                #endif
                
                return input.positionCS.z;
            }

            ENDHLSL
        }
    
    //  End Passes -----------------------------------------------------
    
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
