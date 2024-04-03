Shader "Lux URP/Terrain/Mesh Terrain"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(v7hplahjb13)]

        [Header(Surface Options)]
        [Space(8)]
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0
        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal         ("Enable Normal in Depth Normal Pass", Float) = 1.0
        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals                  ("Receive Decals", Float) = 1.0

        [Header(Surface Inputs)]
        [Space(8)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Maps", Float) = 1.0
        [Toggle(_TOPDOWNPROJECTION)]
        _ApplyTopDownProjection     ("Enable Top Down Projection", Float) = 0.0
        _TopDownTiling              ("     Tiling in World Space", Float) = 1.0

        [Space(5)]
        [NoScaleOffset] _DetailA0   ("Detail 0  Albedo (RGB) Smoothness (A)", 2D) = "gray" {}
        [NoScaleOffset] _Normal0    ("     Normal 0", 2D) = "bump" {}
        [NoScaleOffset] _DetailA1   ("Detail 1  Albedo (RGB) Smoothness (A)", 2D) = "gray" {}
        [NoScaleOffset] _Normal1    ("     Normal 1", 2D) = "bump" {}
        [NoScaleOffset] _DetailA2   ("Detail 2  Albedo (RGB) Smoothness (A)", 2D) = "gray" {}
        [NoScaleOffset] _Normal2    ("     Normal 2", 2D) = "bump" {}
        [NoScaleOffset] _DetailA3   ("Detail 3  Albedo (RGB) Smoothness (A)", 2D) = "gray" {}
        [NoScaleOffset] _Normal3    ("     Normal 3", 2D) = "bump" {}
        
        [Space(5)]
        [Toggle(_USEVERTEXCOLORS)] 
        _VertexColors               ("Use Vertex Colors", Float) = 0.0
        [NoScaleOffset] _SplatMap   ("Splat Map (RGB)", 2D) = "red" {}

        [Space(5)]
        [LuxURPVectorTwoDrawer] _SplatTiling("Detail Tiling (UV)", Vector) = (1,1,0,0)
        _SpecColor("Specular", Color) = (0.2,0.2,0.2,0)
        _Occlusion("Occlusion", Range(0, 1)) = 0

        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0

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

            "Queue"="Geometry-100"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend One Zero
            Cull Back
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

        //  Tell Polybrush that this shader supports 4 texture channels
            #define Z_TEXTURE_CHANNELS 4
            #define Z_MESH_ATTRIBUTES COLOR

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _TOPDOWNPROJECTION
            #pragma shader_feature_local _USEVERTEXCOLORS

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
            // Does this make sense here? Well: maybe
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex vert
            #pragma fragment frag

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain ForwardLit Pass.hlsl"

            ENDHLSL
        }

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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #define LUX_PASS_SHADOWCASTER

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain ShadowCaster Pass.hlsl"

            ENDHLSL
        }

    //  GBuffer --------------------------------------------------------------
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            //Blend One Zero
            Cull Back
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _TOPDOWNPROJECTION
            #pragma shader_feature_local _USEVERTEXCOLORS

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
            //#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain GBuffer Pass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            // #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Normal ---------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS
            #pragma shader_feature_local _TOPDOWNPROJECTION // Not per fragment!
            #pragma shader_feature_local _USEVERTEXCOLORS

            // -------------------------------------
            // Unity defined keywords
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain DepthNormal Pass.hlsl"

            ENDHLSL
        }

    //  Meta -------------------------------------

        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

        //  We need a custom vertex shader here to handle the uvs!
            #pragma vertex LuxVertexMeta
            #pragma fragment LuxFragmentMeta

            #define _SPECULAR_SETUP
            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _USEVERTEXCOLORS

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain Meta Pass.hlsl"

            ENDHLSL
        }
    }


//  ----------------------------------------------------------------

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "ShaderModel"="2.0"

            "Queue"="Geometry-100"
        }
        LOD 300
        
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend One Zero
            Cull Back
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

        //  Tell Polybrush that this shader supports 4 texture channels
            #define Z_TEXTURE_CHANNELS 4
            #define Z_MESH_ATTRIBUTES COLOR

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _TOPDOWNPROJECTION
            #pragma shader_feature_local _USEVERTEXCOLORS

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
            //#pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            // Does this make sense here? Well: maybe
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex vert
            #pragma fragment frag

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain ForwardLit Pass.hlsl"

            ENDHLSL
        }

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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #define LUX_PASS_SHADOWCASTER

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain ShadowCaster Pass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Normal ---------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain DepthNormal Pass.hlsl"

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

        //  We need a custom vertex shader here to handle the uvs!
            #pragma vertex LuxVertexMeta
            #pragma fragment LuxFragmentMeta

            #define _SPECULAR_SETUP
            #pragma shader_feature_local _TOPDOWNPROJECTION
            #pragma shader_feature_local _USEVERTEXCOLORS

            #include "Includes/Lux URP MeshTerrain Inputs.hlsl"
            #include "Includes/Lux URP MeshTerrain Meta Pass.hlsl"

            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
    CustomEditor "LuxURPUniversalCustomShaderGUI"
}