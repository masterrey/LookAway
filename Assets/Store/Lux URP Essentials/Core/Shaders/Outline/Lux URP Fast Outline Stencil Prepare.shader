Shader "Lux URP/Fast Outline Stencil Prepare"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(gpukpasbzt01)]

        [Header(Stencil Pass)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CompareFunction)] _SPZTest ("ZTest", Int) = 4
        [Enum(UnityEngine.Rendering.CullMode)] _SPCull ("Culling", Float) = 2
        
        [Header(Shared Stencil Settings)]
        [Space(8)]
        [IntRange] _StencilRef ("Stencil Reference", Range (0, 255)) = 0
        [IntRange] _ReadMask ("     Read Mask", Range (0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilCompare ("Stencil Comparison", Int) = 6

    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
            "IgnoreProjector" = "True"
            "Queue"= "Transparent+59" // +59 smalltest to get drawn on top of transparents
        }


    //  First pass which only prepares the stencil buffer

        Pass
        {
            Tags
            {
                //"Queue"= "Transparent+59"
            }
            
            Name "Unlit"
            Stencil {
                Ref      [_StencilRef]
                ReadMask [_ReadMask]
                Comp     Always
                Pass     Replace
            }

            Cull [_SPCull]
            ZTest [_SPZTest]
        //  Make sure we do not get overridden
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
            #pragma vertex vert
            #pragma fragment frag

            // Lighting include is needed because of GI
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _Border;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };


            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                #if defined(_APPLYFOG)
                    half fogCoord : TEXCOORD0;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert (Attributes input)
            {
                Varyings o = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return o;
            }

            half4 frag (Varyings input ) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif

                return 0;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}

