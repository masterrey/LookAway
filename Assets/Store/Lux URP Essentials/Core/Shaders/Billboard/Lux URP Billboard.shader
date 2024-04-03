Shader "Lux URP/Billboard"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(miywznst4xsx)]

        [Header(Surface Options)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _ZTest                      ("ZTest", Int) = 4
        [Enum(Tested,0,Blended,1)]
        _Surface                    ("Alpha", Float) = 0.0
        _Cutoff                     ("    Threshold", Range(0.0, 1.0)) = 0.5
        [Enum(Off,0,On,1)]
        _Coverage                   ("    Alpha To Coverage*", Float) = 0
        [Space(4)]
        [LuxURPHelpDrawer]
        _HelpA ("* Might break if any Depth Prepass is active.", Float) = 0.0
        [Enum(Transparent,0,Additive,1,SoftAdditive,2)]
        _Blend                      ("    Blending", Float) = 0.0
        [Space(5)]
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0
        _ShadowOffset               ("Billboard Shadow Offset", Float) = 1.0


        [Header(Billboard Options)]
        [Space(8)]
        [Toggle(_UPRIGHT)]
        _Upright                    ("Enable upright oriented Billboard", Float) = 0.0
        [Toggle(_PIVOTTOBOTTOM)]
        _Pivot                      ("Set Pivot to Bottom", Float) = 0.0
        
        _Shrink                     ("Expand X", Range(0.0, 1.0)) = 1.0


        [Header(Surface Inputs)]
        [MainColor]
        [Space(8)]
        [HDR]_BaseColor             ("Base Color", Color) = (1,1,1,1)
        [NoScaleOffset] [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}


        [Header(Lighting)]
        [Space(8)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Lighting", Float) = 0.0
        [Space(4)]
        [LuxURPHelpDrawer]
        _HelpB ("* Unlit alpha tested billboards are not supported in deferred.", Float) = 0.0
        [Space(5)]
        [NoScaleOffset]
        _BumpMap                    ("    Normal Map", 2D) = "bump" {}
        _BumpScale                  ("    Normal Scale", Float) = 1.0

        _Smoothness                 ("    Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor                  ("    Specular", Color) = (0.2, 0.2, 0.2)


        [Header(Fog)]
        [Space(8)]
        //[Toggle(_APPLYFOG)] _ApplyFog("Enable Fog", Float) = 1.0
        [Toggle] _ApplyFog          ("Enable Fog", Float) = 1.0

        [Header(Render Queue)]
        [Space(8)]
        [IntRange] _QueueOffset     ("Queue Offset", Range(-50, 50)) = 0

        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0

        [HideInInspector] _ZWrite   ("__zw", Float) = 1.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0

    //  ObsoleteProperties
    //  MainTex neeed to quiet editor
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}

    }

//  Shader uses target 2.0 features only.

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "Queue" = "Transparent"
            "DisableBatching" = "True"
            "PreviewType" = "Plane"
            "ShaderModel"="4.5"
        }
        LOD 300
        
    //  ForwardLit -----------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend[_SrcBlend][_DstBlend]
            Cull Back
            ZTest [_ZTest]
            ZWrite[_ZWrite]
            AlphaToMask [_Coverage]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ALPHATEST_ON

            #pragma shader_feature_local _UPRIGHT
            #pragma shader_feature_local _PIVOTTOBOTTOM
            #pragma shader_feature_local _ _APPLYFOG _APPLYFOGADDITIVELY

            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

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
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // Lighting include is needed because of GI
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            
            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard ForwardLit Pass.hlsl"
            
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
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON 1

            #pragma shader_feature_local _UPRIGHT
            #pragma shader_feature_local _PIVOTTOBOTTOM

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

    //  GBuffer ---------------------------------------------------
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
            #pragma shader_feature_local _ALPHATEST_ON

            #pragma shader_feature_local_vertex _UPRIGHT
            #pragma shader_feature_local_vertex _PIVOTTOBOTTOM

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

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

            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard GBuffer Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Only -----------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ZTest [_ZTest]
            ColorMask R
            // ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON 1

            #pragma shader_feature_local _UPRIGHT
            #pragma shader_feature_local _PIVOTTOBOTTOM

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Normals --------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            ZTest [_ZTest]
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _NORMALMAP
            #define _ALPHATEST_ON 1

            #pragma shader_feature_local _UPRIGHT
            #pragma shader_feature_local _PIVOTTOBOTTOM

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            
            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard DepthNormal Pass.hlsl"
            
            ENDHLSL
        }

    }

//  --------------------------------------------------

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "Queue" = "Transparent"
            "DisableBatching" = "True"
            "PreviewType" = "Plane"
            "ShaderModel"="2.0"
        }
        LOD 300
        
    //  ForwardLit -----------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend[_SrcBlend][_DstBlend]
            Cull Back
            ZTest [_ZTest]
            ZWrite[_ZWrite]
            AlphaToMask [_Coverage]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ALPHATEST_ON

            #pragma shader_feature_local _UPRIGHT
            #pragma shader_feature_local _PIVOTTOBOTTOM
            #pragma shader_feature_local _ _APPLYFOG _APPLYFOGADDITIVELY

            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

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
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            // Lighting include is needed because of GI
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            
            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard ForwardLit Pass.hlsl"
            
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
            Cull Off

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON 1

            #pragma shader_feature_local _UPRIGHT
            #pragma shader_feature_local _PIVOTTOBOTTOM

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Only -----------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ZTest [_ZTest]
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON 1

            #pragma shader_feature_local _UPRIGHT
            #pragma shader_feature_local _PIVOTTOBOTTOM

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Normals --------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            ZTest [_ZTest]
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _NORMALMAP
            #define _ALPHATEST_ON 1

            #pragma shader_feature_local _UPRIGHT
            #pragma shader_feature_local _PIVOTTOBOTTOM

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Includes/Lux URP Billboard Inputs.hlsl"
        //  Include pass
            #include "Includes/Lux URP Billboard DepthNormal Pass.hlsl"
            
            ENDHLSL
        }

    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LuxURPCustomBillboardShaderGUI"
}