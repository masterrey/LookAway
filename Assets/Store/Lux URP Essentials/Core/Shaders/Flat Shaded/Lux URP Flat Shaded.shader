Shader "Lux URP/Flat Shaded"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(3omvzsrriztm)]

        [Header(Surface Options)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                       ("Culling", Float) = 2
        [Toggle(_ALPHATEST_ON)]
        _AlphaClip                  ("Alpha Clipping", Float) = 0.0
        _Cutoff                     ("     Threshold", Range(0.0, 1.0)) = 0.5
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0

        [Toggle(_SSAO_ENABLED)]
        _ReceiveSSAO                ("Receive SSAO*", Float) = 1.0
        [Toggle(_SSAO_FLATSHADED)]
        _FlatShadedDepthNormal      ("     Flat Shaded*", Float) = 1.0
        [Space(4)]
        [LuxURPHelpDrawer]
        _HelpA ("* Only used in forward rendering.", Float) = 0.0
        
        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal     ("Enable Normal in Depth Normal Pass", Float) = 1.0
        
        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals              ("Receive Decals", Float) = 1.0


        [Header(Surface Inputs)]
        [Space(8)]
        [MainColor]
        _BaseColor                  ("Color", Color) = (1,1,1,1)

        [Toggle(_ENABLEBASEMAP)]
        _EnableBaseMap              ("Enable Base Map", Float) = 1
        [LuxURPHelpDrawer]
        _Help ("If unchecked Alpha Clipping and Smoothness from Alpha will be disabled.", Float) = 0.0
        [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}

        [Space(5)]
        [Toggle(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)]
        _SmoothnessTextureChannel   ("Albedo Alpha contains Smoothness", Float) = 0
        [LuxURPHelpDrawer]
        _Help ("Checking this will disable Alpha Clipping.", Float) = 0.0
        _Smoothness                 ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor                  ("Specular", Color) = (0.2, 0.2, 0.2)

        [Space(5)]

        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Map", Float) = 0.0
        [NoScaleOffset] _BumpMap    ("     Normal Map", 2D) = "bump" {}
        _BumpScale                  ("     Normal Scale", Float) = 1.0

        [Header(Rim Lighting)]
        [Space(8)]
        [Toggle(_RIMLIGHTING)]
        _Rim                        ("Enable Rim Lighting", Float) = 0
        [HDR] _RimColor             ("Rim Color", Color) = (0.5,0.5,0.5,1)
        _RimPower                   ("Rim Power", Float) = 2
        _RimFrequency               ("Rim Frequency", Float) = 0
        _RimMinPower                ("     Rim Min Power", Float) = 1
        _RimPerPositionFrequency    ("     Rim Per Position Frequency", Range(0.0, 1.0)) = 1


        [Header(Stencil)]
        [Space(8)]
        [IntRange] _Stencil         ("Stencil Reference", Range (0, 255)) = 0
        [IntRange] _ReadMask        ("     Read Mask", Range (0, 255)) = 255
        [IntRange] _WriteMask       ("     Write Mask", Range (0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _StencilComp                ("Stencil Comparison", Int) = 8     // always – terrain should be the first thing being rendered anyway
        [Enum(UnityEngine.Rendering.StencilOp)]
        _StencilOp                  ("Stencil Operation", Int) = 0      // 0 = keep, 2 = replace
        [Enum(UnityEngine.Rendering.StencilOp)]
        _StencilFail                ("Stencil Fail Op", Int) = 0           // 0 = keep
        [Enum(UnityEngine.Rendering.StencilOp)] 
        _StencilZFail               ("Stencil ZFail Op", Int) = 0          // 0 = keep


        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0
        [Space(5)]
        [Toggle(_RECEIVE_SHADOWS_OFF)]
        _Shadows                    ("Disable Receive Shadows", Float) = 0.0


        [Header(Render Queue)]
        [Space(8)]
        [IntRange] _QueueOffset     ("Queue Offset", Range(-50, 50)) = 0


    //  Needed by the inspector
        [HideInInspector] _Culling  ("Culling", Float) = 0.0

    //  URP 10.+
        [HideInInspector] _Surface("__surface", Float) = 0.0 

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _MainTex  ("Albedo", 2D) = "white" {}
        [HideInInspector] _Color    ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags{
        	"RenderType" = "Opaque"
        	"RenderPipeline" = "UniversalPipeline"
        	"UniversalMaterialType" = "Lit"
        	"IgnoreProjector" = "True"
        	"ShaderModel"="4.5"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
			// Using "UniversalForward" here as we have a proper GBuffer pass
            Tags{"LightMode" = "UniversalForward"}

            Stencil {
                Ref   [_Stencil]
                ReadMask [_ReadMask]
                WriteMask [_WriteMask]
                Comp  [_StencilComp]
                Pass  [_StencilOp]
                Fail  [_StencilFail]
                ZFail [_StencilZFail]
            }
            
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
        	#pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _RIMLIGHTING

            #pragma shader_feature_local _SSAO_ENABLED // not per fragment

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

        //  We have to sample SH per pixel
            #if defined (EVALUATE_SH_VERTEX)
                #undef EVALUATE_SH_VERTEX
            #endif
            #if defined(EVALUATE_SH_MIXED)
                #undef EVALUATE_SH_MIXED
            #endif

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local_fragment _RECEIVEDECALS

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY


            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
			#include "Includes/Lux URP FlatShaded ForwardLit Pass.hlsl"            

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON      // not per fragment
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords
            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Includes/Lux URP FlatShaded ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

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

			#define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ALPHATEST_ON      // not per fragment
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            
			#pragma shader_feature_local_fragment _RIMLIGHTING

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

            #pragma shader_feature_local_fragment _RECEIVEDECALS

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
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT


            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment

            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
            #include "Includes/Lux URP FlatShaded GBuffer Pass.hlsl"
            ENDHLSL
        }

    //  Depth -----------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON // not per fragment
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
            #include "Includes/Lux URP FlatShaded DepthOnly Pass.hlsl"

            ENDHLSL
        }

    //  Depth Normal -----------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON      // not per fragment
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _SSAO_FLATSHADED

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
            #include "Includes/Lux URP FlatShaded DepthNormal Pass.hlsl"

            ENDHLSL
        }

        //  Meta -----------------------------------------------------
        
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #define _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

        //  First include all our custom stuff
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"

        //--------------------------------------
        //  Fragment shader and functions

            inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
            {
                half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

                outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
                outSurfaceData.metallic = 0;
                outSurfaceData.specular = _SpecColor.rgb;
                outSurfaceData.smoothness = _Smoothness;
                outSurfaceData.normalTS = half3(0,0,1);
                outSurfaceData.occlusion = 1;
                outSurfaceData.emission = 0;

                outSurfaceData.clearCoatMask = 0;
                outSurfaceData.clearCoatSmoothness = 0;
            }

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }


    }

// ------------------------------------------------------------------

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Stencil {
                Ref   [_Stencil]
                ReadMask [_ReadMask]
                WriteMask [_WriteMask]
                Comp  [_StencilComp]
                Pass  [_StencilOp]
                Fail  [_StencilFail]
                ZFail [_StencilZFail]
            }
            
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
        //  Shader target needs to be 3.0 due to tex2Dlod in the vertex shader or VFACE
            #pragma target 3.0

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _RIMLIGHTING

            #pragma shader_feature_local_fragment _SSAO_ENABLED

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

        //  We have to sample SH per pixel
            #if defined (EVALUATE_SH_VERTEX)
                #undef EVALUATE_SH_VERTEX
            #endif
            #if defined(EVALUATE_SH_MIXED)
                #undef EVALUATE_SH_MIXED
            #endif

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
			#include "Includes/Lux URP FlatShaded ForwardLit Pass.hlsl"            

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            ENDHLSL
        }


    //  Shadows -----------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Includes/Lux URP FlatShaded ShadowCaster Pass.hlsl"

            ENDHLSL
        }

    //  Depth -----------------------------------------------------

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
            #include "Includes/Lux URP FlatShaded DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Normal -----------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _SSAO_FLATSHADED

            #pragma shader_feature_local _ENABLEBASEMAP
            #if !defined(_ENABLEBASEMAP)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    #undef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                #endif
            #endif

            #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                #if defined(_ALPHATEST_ON)
                    #undef _ALPHATEST_ON
                #endif
            #endif

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            
            #define DEPTHNORMALONLYPASS
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"
            #include "Includes/Lux URP FlatShaded DepthNormal Pass.hlsl"
            
            ENDHLSL
        }

    //  Meta -----------------------------------------------------
        
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #define _SPECULAR_SETUP

        //  First include all our custom stuff
            #include "Includes/Lux URP FlatShaded Inputs.hlsl"

        //--------------------------------------
        //  Fragment shader and functions

            inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
            {
                half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
                
                outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
                outSurfaceData.metallic = 0;
                outSurfaceData.specular = _SpecColor.rgb;
                outSurfaceData.smoothness = _Smoothness;
                outSurfaceData.normalTS = half3(0,0,1);
                outSurfaceData.occlusion = 1;
                outSurfaceData.emission = 0;

                outSurfaceData.clearCoatMask = 0;
                outSurfaceData.clearCoatSmoothness = 0;
            }

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }
    FallBack "Hidden/InternalErrorShader"
    CustomEditor "LuxURPUniversalCustomShaderGUI"
}