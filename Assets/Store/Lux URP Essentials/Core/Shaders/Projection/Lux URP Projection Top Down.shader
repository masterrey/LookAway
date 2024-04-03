// Shader might write to emission, so it needs a custom inspector

Shader "Lux URP/Projection/Top Down"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(80kxmwjj8akf)]

        [Header(Surface Options)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                           ("Culling", Float) = 2
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows                 ("Receive Shadows", Float) = 1.0
        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal         ("Enable Normal in Depth Normal Pass", Float) = 1.0
        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals                  ("Receive Decals", Float) = 1.0


        [Header(Surface Inputs)]
        [Space(8)]
        [MainTexture]_BaseMap           ("Albedo (RGB) Smoothness (A)", 2D) = "white" {}
        [MainColor] _BaseColor          ("Base Color", Color) = (1,1,1,1)
        [Toggle(_DYNSCALE)]
        _ApplyDynScale                  ("Enable dynamic tiling", Float) = 0.0
        
        [Space(5)]
        _GlossMapScale                  ("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        _SpecColor                      ("Specular", Color) = (0.2, 0.2, 0.2)
        
        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                    ("Enable Normal Map", Float) = 1.0
        [NoScaleOffset] _BumpMap        ("     Normal Map", 2D) = "bump" {}
        _BumpScale                      ("     Normal Scale", Float) = 1.0
        
        [Header(Mask Map)]
        [Space(8)]
        [Toggle(_COMBINEDTEXTURE)]
        _CombinedTexture                ("Enable Mask Map", Float) = 0.0
        [NoScaleOffset] _MaskMap        ("     Metallness (R) Occlusion (G) Height (B) Emission (A) ", 2D) = "bump" {}
    
        [HDR] _EmissionColor            ("     Emission Color", Color) = (0,0,0)
        [Toggle(_EMISSION)]
        _Emission                       ("     Bake Emission", Float) = 0.0
        _Occlusion                      ("     Occlusion", Range(0.0, 1.0)) = 1.0
        
        [Header(Top Down Projection)]
        [Space(8)]
        [Toggle(_TOPDOWNPROJECTION)]
        _ApplyTopDownProjection         ("Enable top down Projection", Float) = 1.0
        [NoScaleOffset]_TopDownBaseMap  ("     Albedo (RGB) Smoothness (A)", 2D) = "white" {}
        _GlossMapScaleDyn               ("     Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Space(5)]
        [Toggle(_MASKFROMNORMAL)]
        _MaskFromNormal                 ("     Get Mask from Normal", Float) = 0.0
        [NoScaleOffset]_TopDownNormalMap("     Normal (RGB) or Normal (AG) Mask (B)", 2D) = "bump" {}
        _BumpScaleDyn                   ("     Normal Scale", Float) = 1.0
        [Space(5)]
        _TopDownTiling                  ("     Tiling", Float) = 1.0
        [LuxURPVectorThreeDrawer]
        _TerrainPosition                ("     Terrain Position (XYZ)", Vector) = (0,0,0,0)

        [Header(Blending)]
        [Space(8)]
        _NormalLimit                    ("Angle Limit", Range(0.05,1)) = 0.5
        _NormalFactor                   ("Strength", Range(0.0,2)) = 1
        [Space(5)]
        _LowerNormalInfluence           ("Base Normal Influence", Range(0,1)) = 1
        _LowerNormalMinStrength         ("Base Normal Strength", Range(0,1)) = 0.2
        [Space(5)]
        _HeightBlendSharpness           ("Height Influence", Range(0.0, 1.0)) = 1.0

        [Header(Fuzz Lighting)]
        [Space(8)]
        [Toggle(_SIMPLEFUZZ)]
        _EnableFuzzyLighting            ("Enable Fuzzy Lighting", Float) = 0
        _FuzzWrap                       ("     Diffuse Wrap*", Range(0, 1)) = 0.5 
        _FuzzStrength                   ("     Fuzz Strength", Range(0, 8)) = 1 
        _FuzzPower                      ("     Fuzz Power", Range(1, 16)) = 4        
        _FuzzBias                       ("     Fuzz Bias", Range(0, 1)) = 0
        _FuzzAmbient                    ("     Ambient Strength*", Range(0, 1)) = 1
        [Space(4)]
        [LuxURPHelpDrawer]
        _HelpA ("* Only used in forward rendering.", Float) = 0.0

    //	In order to get rid of any errors/warnings
        [HideInInspector] _EmissionColor("Color", Color) = (0,0,0)
        [HideInInspector] _EmissionMap("Emission", 2D) = "white" {}


        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights             ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections         ("Environment Reflections", Float) = 1.0

    //  DepthNormal compatibility
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0
    //  URP 10.+
        [HideInInspector] _Surface("__surface", Float) = 0.0 

        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (1, 1, 1, 1)
        [HideInInspector] _GlossMapScale("Smoothness", Float) = 0.0
        [HideInInspector] _Glossiness("Smoothness", Float) = 0.0
        [HideInInspector] _GlossyReflections("EnvironmentReflections", Float) = 0.0

        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
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

    //  Forward -----------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull [_Cull]
            ZTest LEqual

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _DYNSCALE
            #pragma shader_feature_local_fragment _COMBINEDTEXTURE
            #pragma shader_feature_local_fragment _MASKFROMNORMAL

            #pragma shader_feature_local_fragment _SIMPLEFUZZ

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

            #include "Includes/Lux URP TopDown Inputs.hlsl"

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Includes/Lux URP TopDown ForwardLit Pass.hlsl"


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
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Includes/Lux URP TopDown ShadowCaster Pass.hlsl"

            ENDHLSL
        }

    //	GBuffer ---------------------------------------------------
    	Pass
    	{
    		Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP

            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _DYNSCALE
            #pragma shader_feature_local_fragment _COMBINEDTEXTURE
            #pragma shader_feature_local_fragment _MASKFROMNORMAL

            #pragma shader_feature_local_fragment _SIMPLEFUZZ

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

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

            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Includes/Lux URP TopDown GBuffer Pass.hlsl"
            
            ENDHLSL
    	}

    //  Depth -----------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Includes/Lux URP TopDown DepthOnly Pass.hlsl"

            ENDHLSL
        }

    //  Depth Normal ---------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _DYNSCALE
            #pragma shader_feature_local _COMBINEDTEXTURE
            #pragma shader_feature_local _MASKFROMNORMAL
            //#pragma shader_feature_local_fragment _ALPHATEST_ON
            //#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
//  Breaks decals
//          #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Includes/Lux URP TopDown DepthNormal Pass.hlsl"
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

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #define _SPECULAR_SETUP 1

            #pragma shader_feature _SPECGLOSSMAP

            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _DYNSCALE
            #pragma shader_feature_local _COMBINEDTEXTURE
            #pragma shader_feature_local _MASKFROMNORMAL

            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Includes/Lux URP TopDown Meta Pass.hlsl"

            ENDHLSL
        }

    }

// ---------------------------------------------------------------------    

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

    //  Base -----------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull [_Cull]
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _DYNSCALE
            #pragma shader_feature_local_fragment _COMBINEDTEXTURE
            #pragma shader_feature_local_fragment _MASKFROMNORMAL

            #pragma shader_feature_local_fragment _SIMPLEFUZZ

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
            

            #include "Includes/Lux URP TopDown Inputs.hlsl"

			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment

            #include "Includes/Lux URP TopDown ForwardLit Pass.hlsl"


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
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW


            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Includes/Lux URP TopDown ShadowCaster Pass.hlsl"

            ENDHLSL
        }

    //  Depth -----------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Includes/Lux URP TopDown DepthOnly Pass.hlsl"

            ENDHLSL
        }

    //  Depth Normal ---------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _DYNSCALE
            #pragma shader_feature_local _COMBINEDTEXTURE
            #pragma shader_feature_local _MASKFROMNORMAL
            //#pragma shader_feature_local_fragment _ALPHATEST_ON
            //#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Includes/Lux URP TopDown DepthNormal Pass.hlsl"
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

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #define _SPECULAR_SETUP 1

            #pragma shader_feature _SPECGLOSSMAP

            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _DYNSCALE
            #pragma shader_feature_local _COMBINEDTEXTURE
            #pragma shader_feature_local _MASKFROMNORMAL

            #include "Includes/Lux URP TopDown Inputs.hlsl"
            #include "Includes/Lux URP TopDown Meta Pass.hlsl"

            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
    CustomEditor "LuxURPUniversalCustomShaderGUI"
}