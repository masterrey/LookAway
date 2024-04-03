 // Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly

Shader "Lux URP/Vegetation/Foliage"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(iwibq8un2c3h)]
        
        [Header(Surface Options)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                       ("Culling", Float) = 0
        [Toggle(_ALPHATEST_ON)]
        _AlphaClip                  ("Alpha Clipping", Float) = 1.0
        _Cutoff                     ("     Threshold", Range(0.0, 1.0)) = 0.5
        [Enum(Off,0,On,1)]
        _Coverage                   ("Alpha To Coverage*", Float) = 0
        [Space(4)]
        [LuxURPHelpDrawer]
        _HelpA ("* Might break if any Depth Prepass is active.", Float) = 0.0
        
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0

        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal     ("Enable Normal in Depth Normal Pass", Float) = 1.0

        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals              ("Receive Decals", Float) = 1.0

        [Space(8)]
        [KeywordEnum(Standard, Simple, VsNormals, Transmission)]
        _GbufferLighting ("Gbuffer Lighting", Float) = 1
        [Toggle(_SAMPLE_LIGHT_COOKIES)]
        _ApplyCookiesForTransmission    ("    Enable Cookies for Transmission", Float) = 0.0
        

        [Header(Surface Inputs)]
        [Space(8)]
        [MainColor]
        _BaseColor                  ("Color", Color) = (1,1,1,1)
        [NoScaleOffset][MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
        

        [Space(5)]
        _Smoothness                 ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor                  ("Specular", Color) = (0.2, 0.2, 0.2)

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Smoothness Trans Map", Float) = 0.0
        [NoScaleOffset] _BumpSpecMap
                                    ("     Normal (AG) Smoothness (B) Trans (R)", 2D) = "white" {}
        _BumpScale                  ("     Normal Scale", Range(0.0, 8.0)) = 1.0
        _GlossMapScale              ("     Smoothness Scale", Range(0.0, 1.0)) = 1.0

        [Header(Transmission)]
        [Space(8)]
        _TranslucencyPower          ("Power", Range(0.0, 10.0)) = 7.0
        _TranslucencyStrength       ("Strength", Range(0.0, 4.0)) = 1.0
        _ShadowStrength             ("Shadow Strength", Range(0.0, 1.0)) = 0.7
        _MaskByShadowStrength       ("Mask by incoming Shadow Strength", Range(0.0, 1.0)) = 0.0
        _Distortion                 ("Distortion", Range(0.0, 0.1)) = 0.01

        [Space(8)]
        [Toggle]
        _OverrideTransmission       ("Override Transmission Color", Float) = 0
        _TransmissionColor          ("     Custom Transmission Color", Color) = (0.73,0.85,0.41,1)

        [Header(Wind)]
        [Space(8)]
        [KeywordEnum(Texture, Math)]
        _Wind                       ("Wind Input", Float) = 0
        [LuxURPWindFoliageDrawer]
        _WindMultiplier             ("Wind Strength (X) Secondary Strength (Y) Edge Flutter (Z) Lod Level (W)", Vector) = (1, 2, 1, 0)
        _SampleSize                 ("Sample Size", Range(0.0, 1.0)) = 0.5

        [Space(8)]
        _PerInstanceVariation       ("Per Instance Variation", Range(0.0, 4.0)) = 1
        _SecondaryUp                ("Secondary Up", Range(0.0, 10.0)) = 0
        _Stretchiness               ("Stretchiness", Range(0.0, 1.0)) = 0

        [Space(8)]
        _Turbulence                 ("Turbulence", Range(0.0, 10.0)) = 0.0
        _TurbulenceFrequency        ("     Frequency", Float) = 1
        _TurbulenceMask             ("     Mask", Range(0.0, 1.0)) = 0

        [Space(8)]
        [Toggle(_DEBUG)] _Debug     ("Enable Debug", Float) = 0
        [Enum(Red,0,Green,1,Blue,2,Alpha,3)]
        _DebugVertexColor           ("     Debug Vertex Color", Float) = 0
        _DebugBrightness            ("     Brightness", Float) = 1

        [Header(Displacement)]
        [Space(8)]
        [Toggle(_DISPLACEMENT)]
        _Displacement               ("Enable Displacement", Float) = 0
        _DisplacementSampleSize     ("Sample Size", Range(0.0, 1)) = .5
        _DisplacementStrength       ("Displacement XZ", Range(0.0, 16.0)) = 4
        _DisplacementStrengthVertical ("Displacement Y", Range(0.0, 16.0)) = 4
        _NormalDisplacement         ("Normal Displacement", Range(-2, 2)) = 1

        [Header(Distance Fading)]
        [Space(8)]
        [LuxURPDistanceFadeDrawer]
        _DistanceFade               ("Distance Fade Params", Vector) = (2500, 0.001, 0, 0)

        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _MainTex  ("Albedo", 2D) = "white" {}
        [HideInInspector] _Color    ("Color", Color) = (1,1,1,1)
    }


    SubShader
    {
        Tags
        {
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
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull[_Cull]
            AlphaToMask [_Coverage]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1
            
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ALPHATEST_ON   // not per fragment
            
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local_fragment _RECEIVEDECALS

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT

            #pragma shader_feature_local _DEBUG

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
        //  Needed on foliage?
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

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage ForwardLit Pass.hlsl"

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
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON // not per fragment

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            // -------------------------------------
            // Universal Pipeline keywords
            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

    //  GBuffer -----------------------------------------------------
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
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
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ALPHATEST_ON

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT

            #pragma shader_feature_local_fragment _RECEIVEDECALS

            #pragma shader_feature_local_fragment _ _GBUFFERLIGHTING_SIMPLE _GBUFFERLIGHTING_VSNORMALS _GBUFFERLIGHTING_TRANSMISSION
        //  Needed in case Transmission is used
        //  Built in keyword mifght fail once cookies were activated...
            #pragma shader_feature_local_fragment _SAMPLE_LIGHT_COOKIES
            
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local _DEBUG

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

            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage GBuffer Pass.hlsl"
            
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

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON   // not per fragment

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            #define DEPTHONLYPASS

            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage DepthOnly Pass.hlsl"

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

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON   // not per fragment

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            #define DEPTNORMALPASS
            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage DepthNormal Pass.hlsl"

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

        //  First include all our custom stuff
            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage Meta Pass.hlsl"
        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }
    }


//  --------------------------------------------------------------------

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "ShaderModel"="2.0"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull[_Cull]
            AlphaToMask [_Coverage]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1
            
            #pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local _ALPHATEST_ON   // not per fragment
            
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local_fragment _RECEIVEDECALS

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT

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
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage ForwardLit Pass.hlsl"

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
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON // not per fragment

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT


            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            
            // -------------------------------------
            // Universal Pipeline keywords
            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage ShadowCaster Pass.hlsl"
            
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
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON   // not per fragment

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
            #define DEPTHONLYPASS

            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage DepthOnly Pass.hlsl"

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
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON   // not per fragment

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS

            #pragma shader_feature_local_vertex _WIND_MATH
            #pragma shader_feature_local_vertex _DISPLACEMENT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
            #define DEPTNORMALPASS
            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage DepthNormal Pass.hlsl"

            ENDHLSL
        }

    //  Meta -----------------------------------------------------
        Pass
        {
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #define _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _ALPHATEST_ON

        //  First include all our custom stuff
            #include "Includes/Lux URP Foliage Inputs.hlsl"
            #include "Includes/Lux URP Foliage Meta Pass.hlsl"
        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LuxURPCustomSingleSidedShaderGUI"
}