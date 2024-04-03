// Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly

Shader "Lux URP/Fast Outline AlphaTested"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(uj834ddvqvmq)]

        [Header(Surface Options)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _ZTest                      ("ZTest", Int) = 4
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                       ("Culling", Float) = 2
        [Enum(Off,0,On,1)]
        _Coverage                   ("Alpha To Coverage", Float) = 0

        [Space(5)]
        [IntRange] _StencilRef      ("Stencil Reference", Range (0, 255)) = 1
        [IntRange] _ReadMask        ("     Read Mask", Range (0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _StencilCompare             ("Stencil Comparison", Int) = 6

        [Header(Outline)]
        [Space(8)]
        _OutlineColor               ("Color", Color) = (1,1,1,1)
        _Border                     ("Width", Float) = 3
        [Toggle(_ADAPTIVEOUTLINE)]
        _AdaptiveOutline            ("Do not calculate width in Screen Space", Float) = 0

        [Space(5)]
        [Toggle(_APPLYFOG)]
        _ApplyFog                   ("Enable Fog", Float) = 0.0      

        [Header(Surface Inputs)]
        [Space(8)]
        [MainColor]
        _BaseColor                  ("Color", Color) = (1,1,1,1)
        [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
        _Cutoff                     ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _MainTex  ("Albedo", 2D) = "white" {}
        [HideInInspector] _Color    ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Transparent+60" // +59 smallest to get drawn on top of transparents
        }
        LOD 100

        Pass
        {
            Name "StandardUnlit"
            Tags{"LightMode" = "UniversalForward"}

            Stencil {
                Ref      [_StencilRef]
                ReadMask [_ReadMask]
                Comp     [_StencilCompare]
                Pass     Keep
            }

            ZWrite On
            ZTest [_ZTest]
            Cull [_Cull]

            AlphaToMask [_Coverage]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ADAPTIVEOUTLINE
            #pragma shader_feature _APPLYFOG                  // not per fragment!

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Fast Outlines AlphaTested Inputs.hlsl"

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

        //--------------------------------------
        //  Vertex shader

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput;
                vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                // #if defined(_APPLYFOG)
                    output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                // #endif
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;
                return output;
            }

        //--------------------------------------
        //  Fragment shader and functions

            inline void InitializeSurfaceData(
                float2 uv,
                out SurfaceDescriptionSimple outSurfaceData)
            {
                half innerAlpha = SampleAlbedoAlpha(uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a;

            //  Outline

                float2 offset = float2(1,1);
                #if defined(_ADAPTIVEOUTLINE)
                    float2 shift = _Border.xx * 0.5 * _BaseMap_TexelSize.xy;
                #else
                    float2 shift = fwidth(uv) * _Border * 0.5f;
                #endif

                float2 sampleCoord = uv + shufflefast(offset, shift); 
                half shuffleAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(-1,1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(1,-1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(-1,-1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;
            //  Mask inner parts - which is not really needed when using the stencil buffer. Let's do it anyway, just in case.
                shuffleAlpha = lerp(shuffleAlpha, 0, step(_Cutoff, innerAlpha) );
            //  Apply clip
                outSurfaceData.alpha = Alpha(shuffleAlpha, 1, _Cutoff);
            }

            void InitializeInputData(Varyings input, out InputData inputData)
            {
                inputData = (InputData)0;
                #if defined(_APPLYFOG)
                    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
                #endif
            }

            half4 LitPassFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            //  Get the surface description
                SurfaceDescriptionSimple surfaceData;
                InitializeSurfaceData(input.uv, surfaceData);

            //  Prepare surface data (like bring normal into world space and get missing inputs like gi). Super simple here.
                InputData inputData;
                InitializeInputData(input, inputData);

            //  Apply color – as we do not have any lighting.
                half4 color = half4(_OutlineColor.rgb, surfaceData.alpha);    
            //  Add fog
                #if defined(_APPLYFOG)
                    color.rgb = MixFog(color.rgb, inputData.fogCoord);
                #endif

                return color;
            }

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ADAPTIVEOUTLINE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Fast Outlines AlphaTested Inputs.hlsl"

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment


        //--------------------------------------
        //  Vertex shader

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput;
                vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = vertexInput.positionCS;

                return output;
            }

        //--------------------------------------
        //  Fragment shader and functions

            inline void InitializeSurfaceData(
                float2 uv,
                out SurfaceDescriptionSimple outSurfaceData)
            {
                half innerAlpha = SampleAlbedoAlpha(uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a;

            //  Outline

                float2 offset = float2(1,1);
                #if defined(_ADAPTIVEOUTLINE)
                    float2 shift = _Border.xx * _BaseMap_TexelSize.xy * float2(0.5, 0.5);
                #else
                    float2 shift = fwidth(uv) * (_Border * 0.5f);
                #endif

                float2 sampleCoord = uv + shufflefast(offset, shift); 
                half shuffleAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(-1,1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(1,-1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(-1,-1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;
            //  Mask inner parts - which is not really needed when using the stencil buffer. Let's do it anyway, just in case.
                shuffleAlpha = lerp(shuffleAlpha, 0, step(_Cutoff, innerAlpha) );
            //  Apply clip
                outSurfaceData.alpha = Alpha(shuffleAlpha, 1, _Cutoff);
            }

            half4 DepthOnlyFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            //  Get the surface description
                SurfaceDescriptionSimple surfaceData;
                InitializeSurfaceData(input.uv, surfaceData);

                return input.positionCS.z;  
            }

            ENDHLSL

        }

        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ADAPTIVEOUTLINE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Fast Outlines AlphaTested Inputs.hlsl"

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment


        //--------------------------------------
        //  Vertex shader

            Varyings DepthNormalVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput;
                vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = vertexInput.positionCS;
                return output;
            }

        //--------------------------------------
        //  Fragment shader and functions

            inline void InitializeSurfaceData(
                float2 uv,
                out SurfaceDescriptionSimple outSurfaceData)
            {
                half innerAlpha = SampleAlbedoAlpha(uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a;

            //  Outline

                float2 offset = float2(1,1);
                #if defined(_ADAPTIVEOUTLINE)
                    float2 shift = _Border.xx * _BaseMap_TexelSize.xy * float2(0.5, 0.5);
                #else
                    float2 shift = fwidth(uv) * (_Border * 0.5f);
                #endif

                float2 sampleCoord = uv + shufflefast(offset, shift); 
                half shuffleAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(-1,1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(1,-1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

                offset = float2(-1,-1);
                sampleCoord = uv + shufflefast(offset, shift);
                shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;
            //  Mask inner parts - which is not really needed when using the stencil buffer. Let's do it anyway, just in case.
                shuffleAlpha = lerp(shuffleAlpha, 0, step(_Cutoff, innerAlpha) );
            //  Apply clip
                outSurfaceData.alpha = Alpha(shuffleAlpha, 1, _Cutoff);
            }

            half4 DepthNormalFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            //  Get the surface description
                SurfaceDescriptionSimple surfaceData;
                InitializeSurfaceData(input.uv, surfaceData);

                return 0;  
            }

            ENDHLSL

        }


    //  End Passes -----------------------------------------------------
    
    }
    FallBack "Hidden/InternalErrorShader"
}