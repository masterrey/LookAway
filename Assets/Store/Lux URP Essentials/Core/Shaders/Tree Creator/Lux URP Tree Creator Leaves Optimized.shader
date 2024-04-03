// Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly

// Please note: This shader will never be batched as unity uses Materialpropertyblocks to write per instance properties.

Shader "Lux URP/Nature/Tree Creator Leaves Optimized"
{
    Properties
    {

        [Header(Surface Options)]
        [Space(8)]
        
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0
        [Toggle(_ENABLEDITHERING)]
        _EnableDither               ("Enable Dithering for VR", Float) = 0.0

        [Space(5)]
        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal     ("Enable Normal in Depth Normal Pass", Float) = 1.0
        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals              ("Receive Decals", Float) = 0.0

        [Space(8)]
        [KeywordEnum(Standard, Transmission)]
        _GbufferLighting ("Gbuffer Lighting", Float) = 1
        [Toggle(_SAMPLE_LIGHT_COOKIES)]
        _ApplyCookiesForTransmission    ("    Enable Cookies for Transmission", Float) = 0.0
        

        [Header(Surface Inputs)]
        [Space(8)]
        [MainColor]
        _Color                      ("Main Color", Color) = (1,1,1,1)
        [MainTexture]
        _MainTex                    ("Base (RGB) Alpha (A)", 2D) = "white" {}
        _Cutoff                     ("Alpha cutoff", Range(0.0, 1.0)) = 0.5

        [NoScaleOffset]
        _BumpSpecMap                ("Normalmap (GA) Spec (R)", 2D) = "bump" {}
        [NoScaleOffset]
        _TranslucencyMap            ("Trans (B) Gloss(A)", 2D) = "white" {}

        [HideInInspector]
        _SpecColor                  ("Specular Color", Color) = (0.2, 0.2, 0.2)


        [Header(Transmission)]
        [Space(8)]
        _TranslucencyColor          ("Translucency Color", Color) = (0.73,0.85,0.41,1) // (187,219,106,255)
        _TranslucencyViewDependency ("View dependency", Range(0,1)) = 0.7
        _ShadowStrength             ("Shadow Strength", Range(0,1)) = 0.8

        [Header(Wind)]
        [Space(8)]
        [Toggle(_WINDFROMSCRIPT)]
        _EnableWindFromScript       ("Enable Wind From Script", Float) = 0

        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0

        [HideInInspector] _ShadowOffsetScale ("Shadow Offset Scale", Float) = 1

        [HideInInspector] _TreeInstanceColor ("TreeInstanceColor", Vector) = (1,1,1,1)
        [HideInInspector] _TreeInstanceScale ("TreeInstanceScale", Vector) = (1,1,1,1)
        [HideInInspector] _SquashAmount ("Squash", Float) = 1

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff

    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "TransparentCutout"
            "IgnoreProjector" = "True"
            "Queue"="AlphaTest"
            "ShaderModel" = "4.5"
        }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            
            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            // #define _SPECULAR_SETUP 1

        //  We always have a combined normal map and alpha testing
            #define _ALPHATEST_ON
            #define _NORMALMAP

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT

            #pragma shader_feature _ENABLEDITHERING
            #pragma multi_compile __ BILLBOARD_FACE_CAMERA_POS

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

        //  Trees do not support lightmapping or cross fading
            // #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            // #pragma multi_compile _ SHADOWS_SHADOWMASK
            // #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            // #pragma multi_compile _ LIGHTMAP_ON
            // #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

// Property 'unity_LODFade' shares the same constant buffer offset with 'unity_RenderingLayer'. Ignoring.
#ifdef LOD_FADE_CROSSFADE
    #ifdef INSTANCING_ON 
        #undef INSTANCING_ON
    #endif 
#endif

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            
            #include "Includes/Lux URP Creator Leaves ForwardLit Pass.hlsl"

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
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT

        //  Usually no shadows during the transition...
            #pragma shader_feature _ENABLEDITHERING
            #pragma multi_compile __ BILLBOARD_FACE_CAMERA_POS

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

// Property 'unity_LODFade' shares the same constant buffer offset with 'unity_RenderingLayer'. Ignoring.
#ifdef LOD_FADE_CROSSFADE
    #ifdef INSTANCING_ON 
        #undef INSTANCING_ON
    #endif 
#endif

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            #include "Includes/Lux URP Creator Leaves ShadowCaster Pass.hlsl"
        
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            ENDHLSL
        }

    //  GBuffer -----------------------------------------------------
        
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _NORMALMAP
            #define _ALPHATEST_ON

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT
            #pragma shader_feature_local_fragment _RECEIVEDECALS

            #pragma shader_feature_local_fragment _ _GBUFFERLIGHTING_TRANSMISSION
        //  Needed in case Transmission is used
        //  Built in keyword might fail once cookies were activated...
            #pragma shader_feature_local_fragment _SAMPLE_LIGHT_COOKIES
            
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"


            // -------------------------------------
            // Unity defined keywords

            // Trees do not support lightmapping - but we have to define these to make lighting work
            // #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            // #pragma multi_compile _ SHADOWS_SHADOWMASK
            // #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            // #pragma multi_compile _ LIGHTMAP_ON
            // #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

// Property 'unity_LODFade' shares the same constant buffer offset with 'unity_RenderingLayer'. Ignoring.
#ifdef LOD_FADE_CROSSFADE
    #ifdef INSTANCING_ON 
        #undef INSTANCING_ON
    #endif 
#endif

            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            #include "Includes/Lux URP Creator Leaves GBuffer Pass.hlsl"

            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment
            
            ENDHLSL
        }


    //  Depth -----------------------------------------------------

        Pass
        {
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT

            #pragma shader_feature _ENABLEDITHERING
            #pragma multi_compile __ BILLBOARD_FACE_CAMERA_POS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

// Property 'unity_LODFade' shares the same constant buffer offset with 'unity_RenderingLayer'. Ignoring.
#ifdef LOD_FADE_CROSSFADE
    #ifdef INSTANCING_ON 
        #undef INSTANCING_ON
    #endif 
#endif
            
            
            #define DEPTHONLYPASS
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            #include "Includes/Lux URP Creator Leaves DepthOnly Pass.hlsl"

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            ENDHLSL
        }

    //  Depth Normal -----------------------------------------------------

        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT

            #pragma shader_feature _ENABLEDITHERING
            #pragma shader_feature _NORMALINDEPTHNORMALPASS
            #pragma multi_compile __ BILLBOARD_FACE_CAMERA_POS

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

// Property 'unity_LODFade' shares the same constant buffer offset with 'unity_RenderingLayer'. Ignoring.
#ifdef LOD_FADE_CROSSFADE
    #ifdef INSTANCING_ON 
        #undef INSTANCING_ON
    #endif 
#endif

            #define DEPTHNORMALONLYPASS
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            #include "Includes/Lux URP Creator Leaves DepthNormal Pass.hlsl"

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }


//  --------------------------------------------------------------------

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "TransparentCutout"
            "IgnoreProjector" = "True"
            "Queue"="AlphaTest"
            "ShaderModel"="2.0"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords

        //  We always have a combined normal map and alpha testing
            #define _ALPHATEST_ON
            #define _NORMALMAP

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT

            #pragma shader_feature _ENABLEDITHERING
            #pragma multi_compile __ BILLBOARD_FACE_CAMERA_POS

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

        //  Trees do not support lightmapping
            // #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            // #pragma multi_compile _ SHADOWS_SHADOWMASK
            // #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            // #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            
            #include "Includes/Lux URP Creator Leaves ForwardLit Pass.hlsl"

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
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT

        //  Usually no shadows during the transition...
            #pragma shader_feature _ENABLEDITHERING
            #pragma multi_compile __ BILLBOARD_FACE_CAMERA_POS

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

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            #include "Includes/Lux URP Creator Leaves ShadowCaster Pass.hlsl"
        
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            ENDHLSL
        }

    //  Depth -----------------------------------------------------

        Pass
        {
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT

            #pragma shader_feature _ENABLEDITHERING
            #pragma multi_compile __ BILLBOARD_FACE_CAMERA_POS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            #define DEPTHONLYPASS
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            #include "Includes/Lux URP Creator Leaves DepthOnly Pass.hlsl"

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            ENDHLSL
        }

    //  Depth Normal -----------------------------------------------------

        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON

            #pragma shader_feature_local_vertex _WINDFROMSCRIPT

            #pragma shader_feature _ENABLEDITHERING
            #pragma shader_feature _NORMALINDEPTHNORMALPASS
            #pragma multi_compile __ BILLBOARD_FACE_CAMERA_POS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            #define DEPTHNORMALONLYPASS
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            #include "Includes/Lux URP Creator Leaves DepthNormal Pass.hlsl"

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }

    FallBack "Hidden/InternalErrorShader"
    Dependency "BillboardShader" = "Hidden/Nature/Lux Tree Creator Leaves Rendertex"
}
