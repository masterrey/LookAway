Shader "Lux URP/Fast Outline Double Pass"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(gpukpasbzt01)]

        [Header(Stencil Pass)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CompareFunction)] _SPZTest ("ZTest", Int) = 4
        [Enum(UnityEngine.Rendering.CullMode)] _SPCull ("Culling", Float) = 2
        
        [Header(Outline Pass)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Int) = 4
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Culling", Float) = 2

        [Header(Shared Stencil Settings)]
        [Space(8)]
        [IntRange] _StencilRef ("Stencil Reference", Range (0, 255)) = 0
        [IntRange] _ReadMask ("     Read Mask", Range (0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilCompare ("Stencil Comparison", Int) = 6


        [Header(Outline)]
        [Space(8)]
        _BaseColor ("Color", Color) = (1,1,1,1)
        _Border ("Width", Float) = 3

        [Space(5)]
        [Toggle(_APPLYFOG)] _ApplyFog("Enable Fog", Float) = 0.0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
            "IgnoreProjector" = "True"
            "Queue"= "Transparent+60" // +59 smalltest to get drawn on top of transparents
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
        
    //  Second pass which draws the outline

        Pass
        {

            Name "ForwardLit"
            Tags{ 
                "LightMode" = "UniversalForwardOnly"
                //"Queue"= "Transparent+60"
            }

            Stencil {
                Ref      [_StencilRef]
                ReadMask [_ReadMask]
                Comp     [_StencilCompare]
                Pass     Keep
            }

            Blend SrcAlpha OneMinusSrcAlpha
            Cull [_Cull]
            ZTest [_ZTest]
        //  Make sure we do not get overridden
            ZWrite On

            HLSLPROGRAM
            #pragma target 2.0

            #pragma shader_feature_local _APPLYFOG

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
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

        //  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
            #ifdef UNITY_DOTS_INSTANCING_ENABLED
                UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
                    UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
                UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
                #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
            #endif

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };


            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                #if defined(_APPLYFOG)
                    half fogCoord   : TEXCOORD0;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                #if defined(_APPLYFOG)
                    output.fogCoord = ComputeFogFactor(output.positionCS.z);
                #endif
            //  Extrude
                if (_Border > 0.0h) {
                    //float3 normal = mul(UNITY_MATRIX_MVP, float4(input.normal, 0)).xyz; // to clip space
                    float3 normal = mul(GetWorldToHClipMatrix(), mul(GetObjectToWorldMatrix(), float4(input.normalOS, 0.0))).xyz;
                    float2 offset = normalize(normal.xy);
                    float2 ndc = _ScreenParams.xy * 0.5;
                    output.positionCS.xy += ((offset * _Border) / ndc * output.positionCS.w);
                }
                return output;
            }

            half4 frag (Varyings input ) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif

                half4 color = _BaseColor;

                #if defined(_APPLYFOG)
                    color.rgb = MixFog(color.rgb, input.fogCoord);
                #endif

                return half4(color);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}

