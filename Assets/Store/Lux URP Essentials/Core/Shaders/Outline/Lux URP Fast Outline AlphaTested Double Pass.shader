// Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly

Shader "Lux URP/Fast Outline AlphaTested Double Pass"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(uj834ddvqvmq)]

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
        [IntRange] _StencilRef ("Stencil Reference", Range (0, 255)) = 1
        [IntRange] _ReadMask ("     Read Mask", Range (0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilCompare ("Stencil Comparison", Int) = 6


        [Header(Surface Options)]
        [Space(8)]
        [Enum(Off,0,On,1)]
        _Coverage                   ("Alpha To Coverage", Float) = 0

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
            "Queue" = "Transparent+60" // +59 smalltest to get drawn on top of transparents
        }
        LOD 100

    //  First pass which only prepares the stencil buffer

        Pass
        {
            
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
            
            #pragma vertex vert
            #pragma fragment frag

            // Lighting include is needed because of GI
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Fast Outlines AlphaTested Inputs.hlsl"
            

            Varyings vert (Attributes input)
            {
                Varyings o = (Varyings)0;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                o.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return o;
            }

            half4 frag (Varyings input ) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif

                half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;
                clip(alpha - _Cutoff);
                return 0;
            }
            ENDHLSL
        }

        
//  Second pass which draws the outline
        Pass
        {
            Name "StandardUnlit"
            Tags{"LightMode" = "UniversalForwardOnly"}

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
            #pragma shader_feature_local_fragment _APPLYFOG

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Fast Outlines AlphaTested Inputs.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

        //--------------------------------------
        //  Vertex shader

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput;
                vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                #if defined(_APPLYFOG)
                    output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                #endif
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
                    inputData.fogCoord = input.fogFactor;
                #endif
            }

            half4 LitPassFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif

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

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Fast Outlines AlphaTested Inputs.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment


        //--------------------------------------
        //  Vertex shader

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput;
                vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
            //    #if defined(_APPLYFOG)
            //        output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
            //    #endif
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
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif

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

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Fast Outlines AlphaTested Inputs.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment


        //--------------------------------------
        //  Vertex shader

            Varyings DepthNormalVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput;
                vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = vertexInput.positionCS;

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
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

            //half4 DepthNormalFragment(Varyings input) : SV_Target
            //{
            void DepthNormalFragment(
                Varyings input
                , out half4 outNormalWS : SV_Target0
            #ifdef _WRITE_RENDERING_LAYERS
                , out float4 outRenderingLayers : SV_Target1
            #endif
            )
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif

            //  Get the surface description
                SurfaceDescriptionSimple surfaceData;
                InitializeSurfaceData(input.uv, surfaceData);

                #if defined(_GBUFFER_NORMALS_OCT)
                    float3 normalWS = normalize(input.normalWS);
                    float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
                    float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   
                    half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      
                    outNormalWS = half4(packedNormalWS, 0.0);
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


    //  End Passes -----------------------------------------------------
    
    }
    FallBack "Hidden/InternalErrorShader"
}