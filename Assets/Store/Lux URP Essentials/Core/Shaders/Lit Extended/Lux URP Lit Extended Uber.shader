Shader "Lux URP/Lit Extended Uber"
{
    Properties
    {
        [Header(Surface Options)]
        [Space(8)]

        [Enum(UnityEngine.Rendering.CompareFunction)]
        _ZTest                              ("ZTest", Int) = 4
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                               ("Culling", Float) = 2
        [Toggle(_ALPHATEST_ON)]
        _AlphaClip                          ("Alpha Clipping", Float) = 0.0
        _Cutoff                             ("     Threshold", Range(0.0, 1.0)) = 0.5
        [Toggle(_FADING_ON)]
        _CameraFadingEnabled                ("     Enable Camera Fading", Float) = 0.0
        _CameraFadeDist                     ("     Fade Distance", Float) = 1.0
        [Toggle(_FADING_SHADOWS_ON)]
        _CameraFadeShadows                  ("     Fade Shadows", Float) = 0.0
        _CameraShadowFadeDist               ("     Shadow Fade Distance", Float) = 1.0
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows                     ("Receive Shadows", Float) = 1.0

       
        [Header(Surface Inputs)]
        [Space(8)]
        [MainTexture] _BaseMap              ("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor              ("Color", Color) = (1,1,1,1)

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _EnableNormal                       ("Enable Normal Map", Float) = 0
        [NoScaleOffset] _BumpMap            ("     Normal Map", 2D) = "bump" {}
        _BumpScale                          ("     Normal Scale", Float) = 1.0

        [Toggle(_BESTFITTINGNORMALS_ON)]
        _BestFittingNormalEnabled           ("Enable Best Fitting Normals", Float) = 0.0
        [NoScaleOffset] _BestFittingNormal  ("     Best Fitting Normal", 2D) = "black" {}



        [Toggle(_BENTNORMAL)]
        _EnableBentNormal ("Enable Bent Normal Map", Float) = 0
        _BentNormalMap                      ("Bent Normal Map*", 2D) = "bump" {}

        [Space(5)]
        [Toggle(_PARALLAX)]
        _EnableParallax                     ("Enable Height Map", Float) = 0
        [NoScaleOffset] _HeightMap          ("     Height Map (G)", 2D) = "black" {}
        _Parallax                           ("     Extrusion", Range (0.0, 0.1)) = 0.02
        [Toggle(_PARALLAXSHADOWS)]
        _EnableParallaxShadows              ("Enable Parallax Shadows", Float) = 0

        [Space(5)]
        [Toggle(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)]
        _SmoothnessTextureChannel           ("Sample Smoothness from Albedo Alpha", Float) = 0
        _Smoothness                         ("Smoothness", Range(0.0, 1.0)) = 0.5

        [Header(Work Flow)]

        [Space(5)]
        [NoScaleOffset] _SpecGlossMap       ("Specular Map", 2D) = "white" {}
        _SpecColor                          ("Specular Color", Color) = (0.2, 0.2, 0.2) // Order of props important for editor!?

        [ToggleOff(_SPECULAR_SETUP)]  
        _WorkflowMode                       ("Metal Workflow", Float) = 1.0
        [Space(5)]
        [NoScaleOffset] _MetallicGlossMap   ("     Metallic Map", 2D) = "white" {}  // Order of props important for editor!?
        [Gamma] _Metallic                   ("     Metallic", Range(0.0, 1.0)) = 0.0

        [Space(5)]
        [Toggle(_METALLICSPECGLOSSMAP)] 
        _EnableMetalSpec                    ("Enable Spec/Metal Map", Float) = 0.0

        [Header(Additional Maps)]
        [Space(8)]
        [Toggle(_OCCLUSIONMAP)] 
        _EnableOcclusion                    ("Enable Occlusion", Float) = 0.0
        [NoScaleOffset] _OcclusionMap       ("     Occlusion Map", 2D) = "white" {}
        _OcclusionStrength                  ("     Occlusion Strength", Range(0.0, 1.0)) = 1.0

        [Space(5)]
        [Toggle(_EMISSION)] 
        _Emission                           ("Enable Emission", Float) = 0.0
        [HDR] _EmissionColor                ("     Color", Color) = (0,0,0)
        [NoScaleOffset] _EmissionMap        ("     Emission", 2D) = "white" {}

        [Header(Detail Maps)]
        [Space(8)]
        _DetailMask                         ("Detail Mask", 2D) = "white" {}
        _DetailAlbedoMapScale               ("Scale", Range(0.0, 2.0)) = 1.0
        _DetailAlbedoMap                    ("Detail Albedo x2", 2D) = "linearGrey" {}
        _DetailNormalMapScale               ("Scale", Range(0.0, 2.0)) = 1.0
        [Normal] _DetailNormalMap           ("Normal Map", 2D) = "bump" {}


        [Header(Rim Lighting)]
        [Space(8)]
        [HideInInspector] _Dummy("Dummy", Float) = 0.0 // needed by custum inspector
        
        [Toggle(_RIMLIGHTING)]
        _Rim                                ("Enable Rim Lighting", Float) = 0
        [HDR] _RimColor                     ("Rim Color", Color) = (0.5,0.5,0.5,1)
        _RimPower                           ("Rim Power", Float) = 2
        _RimFrequency                       ("Rim Frequency", Float) = 0
        _RimMinPower                        ("     Rim Min Power", Float) = 1
        _RimPerPositionFrequency            ("     Rim Per Position Frequency", Range(0.0, 1.0)) = 1

        
        //[Header(Stencil)]
        //[Space(5)]

        [IntRange] _Stencil                 ("Stencil Reference", Range (0, 255)) = 0
        [IntRange] _ReadMask                ("     Read Mask", Range (0, 255)) = 255
        [IntRange] _WriteMask               ("     Write Mask", Range (0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _StencilComp                        ("Stencil Comparison", Int) = 8     // always – terrain should be the first thing being rendered anyway
        [Enum(UnityEngine.Rendering.StencilOp)]
        _StencilOp                          ("Stencil Operation", Int) = 0      // 0 = keep, 2 = replace
        [Enum(UnityEngine.Rendering.StencilOp)]
        _StencilFail                        ("Stencil Fail Op", Int) = 0           // 0 = keep
        [Enum(UnityEngine.Rendering.StencilOp)] 
        _StencilZFail                       ("Stencil ZFail Op", Int) = 0          // 0 = keep


        [Header(Advanced)]
        [Space(8)]
        [Toggle(_ENABLE_GEOMETRIC_SPECULAR_AA)]
        _GeometricSpecularAA                ("Geometric Specular AA", Float) = 0.0
        _ScreenSpaceVariance                ("     Screen Space Variance", Range(0.0, 1.0)) = 0.1
        _SAAThreshold                       ("     Threshold", Range(0.0, 1.0)) = 0.2

        [Space(5)]
        [Toggle(_ENABLE_AO_FROM_GI)]
        _AOfromGI                           ("Get ambient specular Occlusion from GI", Float) = 0.0
        _GItoAO                             ("     GI to AO Factor", Float) = 10
        _GItoAOBias                         ("     GI to AO Bias", Range(0,1)) = 0.0

        _HorizonOcclusion                   ("Horizon Occlusion", Range(0,1)) = 0.5

        [Space(5)]
        [ToggleOff]
        _SpecularHighlights                 ("Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections             ("Environment Reflections", Float) = 1.0
        
        // Blending state
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        //[HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _SrcBlendAlpha("__srcA", Float) = 1.0
        [HideInInspector] _DstBlendAlpha("__dstA", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        //[HideInInspector] _Cull("__cull", Float) = 2.0

        // _ReceiveShadows("Receive Shadows", Float) = 1.0        
        // Editmode props
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
        
        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (1, 1, 1, 1)
        [HideInInspector] _GlossMapScale("Smoothness", Float) = 0.0
        [HideInInspector] _Glossiness("Smoothness", Float) = 0.0
        [HideInInspector] _GlossyReflections("EnvironmentReflections", Float) = 0.0

        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}

        // GUI
        [HideInInspector] _FoldSurfaceOptions("Surface Options", Float) = 0.0
        [HideInInspector] _FoldSurfaceInputs("Surface Inputs", Float) = 1.0
        [HideInInspector] _FoldSurfaceDetailInputs("Detail Surface Inputs", Float) = 1.0
        [HideInInspector] _FoldAdvancedSurfaceInputs("Advanced Surface Inputs", Float) = 1.0
        [HideInInspector] _FoldRimLightingInputs("Rim Lighting Options", Float) = 0.0
        [HideInInspector] _FoldStencilOptions("Stencil Options", Float) = 0.0
        [HideInInspector] _FoldAdvanced("Advanced", Float) = 0.0
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

    //  Forward pass --------------------------------------------------------
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
                //replace
            }

            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZTest [_ZTest]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords

            #define _UBER

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _BENTNORMAL
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local _PARALLAX

            #pragma shader_feature_local_fragment _SAMPLENORMAL
            #pragma shader_feature_local_fragment _ENABLE_GEOMETRIC_SPECULAR_AA
            #pragma shader_feature_local_fragment _ENABLE_AO_FROM_GI
            #pragma shader_feature_local_fragment _RIMLIGHTING
            #pragma shader_feature_local_fragment _FADING_ON

            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
            #pragma shader_feature_local_fragment _EMISSION            
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _OCCLUSIONMAP

            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT           
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
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
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex LitPassVertexUber
            #pragma fragment LitPassFragmentUber

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber ForwardLit Pass.hlsl"

            ENDHLSL
        }

    //  Shadow Caster --------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest [_ZTest]
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Material Keywords
            
            #define _UBER

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature_local _PARALLAXSHADOWS
            #pragma shader_feature_local _FADING_SHADOWS_ON

            #if defined (_PARALLAXSHADOWS) && !defined(_NORMALMAP)
                #define _NORMALMAP
            #endif

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

    //  GBuffer --------------------------------------------------------
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite[_ZWrite]
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords

            #define _UBER

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _BENTNORMAL
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local _PARALLAX 

            #pragma shader_feature_local_fragment _BESTFITTINGNORMALS_ON
            #pragma shader_feature_local_fragment _SAMPLENORMAL
            #pragma shader_feature_local_fragment _ENABLE_GEOMETRIC_SPECULAR_AA
            //#pragma shader_feature_local_fragment _ENABLE_AO_FROM_GI
            #pragma shader_feature_local_fragment _RIMLIGHTING
            #pragma shader_feature_local_fragment _FADING_ON

            #pragma shader_feature_local_fragment _ALPHATEST_ON
            //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local_fragment _EMISSION            
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _OCCLUSIONMAP

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

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

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber GBuffer Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Only --------------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ZTest [_ZTest]
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords

            #define _UBER

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature_local _PARALLAX
            #pragma shader_feature_local_fragment _FADING_ON

            #if defined (_PARALLAX) && !defined(_NORMALMAP)
                #define _NORMALMAP
            #endif

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber DepthOnly Pass.hlsl"

            ENDHLSL
        }

    //  Depth Normal --------------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            ZTest [_ZTest]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords

            #define _UBER

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //#pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _PARALLAX
            #pragma shader_feature_local _FADING_ON

            #if defined (_PARALLAX) && !defined(_NORMALMAP)
                #define _NORMALMAP
            #endif

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            
            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber DepthNormal Pass.hlsl"

            ENDHLSL
        }        

    //  Meta -------------------------------------------------------------
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

            #define _UBER

            #define _PARALLAX

            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

            #pragma shader_feature_local_fragment _SPECGLOSSMAP

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    }


//  ---------------------------------------------------------------------------    

    SubShader
    {
        Tags{
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit" 
            "IgnoreProjector" = "True"
            "ShaderModel"="2.0"
        }
        LOD 300

    //  Forward pass --------------------------------------------------------
        Pass
        {
            // Lightmode matches the ShaderPassName set in LightweightRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Lightweight Render Pipeline
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
                //replace
            }

            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
			ZTest [_ZTest]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords

            #define _UBER

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAX
            #pragma shader_feature_local _BENTNORMAL
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

            #pragma shader_feature_local_fragment _SAMPLENORMAL
            #pragma shader_feature_local_fragment _ENABLE_GEOMETRIC_SPECULAR_AA
            #pragma shader_feature_local_fragment _ENABLE_AO_FROM_GI
            #pragma shader_feature_local_fragment _RIMLIGHTING
            #pragma shader_feature_local_fragment _FADING_ON

            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
            #pragma shader_feature_local_fragment _EMISSION            
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _OCCLUSIONMAP

            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
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
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #pragma vertex LitPassVertexUber
            #pragma fragment LitPassFragmentUber

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber ForwardLit Pass.hlsl"

            ENDHLSL
        }

    //  Shadow Caster --------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest [_ZTest]
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            // -------------------------------------
            // Material Keywords
            
            #define _UBER

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature_local _PARALLAXSHADOWS
            #pragma shader_feature_local _FADING_SHADOWS_ON

            #if defined (_PARALLAXSHADOWS) && !defined(_NORMALMAP)
                #define _NORMALMAP
            #endif

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Only --------------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ZTest [_ZTest]
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords

            #define _UBER

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //#pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _PARALLAX
            #pragma shader_feature_local_fragment _FADING_ON

            #if defined (_PARALLAX) && !defined(_NORMALMAP)
                #define _NORMALMAP
            #endif

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber DepthOnly Pass.hlsl"

            ENDHLSL
        }

    //  Depth Normal --------------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            ZTest [_ZTest]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords

            #define _UBER

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //#pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _PARALLAX
            #pragma shader_feature_local _FADING_ON

            #if defined (_PARALLAX) && !defined(_NORMALMAP)
                #define _NORMALMAP
            #endif

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            #include "Includes/Lux URP Uber DepthNormal Pass.hlsl"

            ENDHLSL
        }        

    //  Meta -------------------------------------------------------------
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

            #define _UBER

            #define _PARALLAX

            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

            #pragma shader_feature_local_fragment _SPECGLOSSMAP

            #include "Includes/Lux URP Lit Extended Inputs.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    }

    FallBack "Hidden/InternalErrorShader"
    CustomEditor "LuxUberShaderGUI"
}