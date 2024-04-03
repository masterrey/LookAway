// Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly

Shader "Lux URP/Vegetation/Grass"
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
        [Enum(Off,0,On,1)]_Coverage ("Alpha To Coverage*", Float) = 0
        [Space(4)]
        [LuxURPHelpDrawer]
        _HelpA ("* Might break if any Depth Prepass is active.", Float) = 0.0
        
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0
        
        [Space(5)]
        _LightMapBoost              ("Light Map Boost", Float) = 1.0
        [Toggle(_NORMALVS)]
        _EnableNormalVS             ("Enable Screen Space Normals", Float) = 0

        [Space(5)]
        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal     ("Enable Normal in Depth Normal Pass", Float) = 1.0
        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals              ("Receive Decals", Float) = 1.0

        [Header(Surface Inputs)]
        [Space(8)]
        [MainColor]
        _BaseColor                  ("Color", Color) = (1,1,1,1)
        [NoScaleOffset] [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _EnableNormal               ("Enable Normal Map", Float) = 0
        [NoScaleOffset] _BumpMap    ("     Normal Map", 2D) = "bump" {}
        _BumpScale                  ("     Normal Scale", Float) = 1.0

        [Space(5)]
        [Toggle(_SPECMASK)]
        _EnableSpecMask             ("Enable Specular Mask", Float) = 0
        [NoScaleOffset] _SpecMask   ("     Specular (G) Smoothness (B) Mask", 2D) = "black" {}
        _OcclusionFromSpecMask      ("     Occlusion from Spec Mask", Range(0.0, 1.0)) = 1.0

        [Space(5)]
        _Smoothness                 ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor                  ("Specular", Color) = (0.2, 0.2, 0.2)
        _Occlusion                  ("Vertex Occlusion", Range(0.0, 1.0)) = 1.0

        [Header(Wind)]
        [Space(8)]
        [KeywordEnum(Blue, Alpha)]
        _BendingMode                ("Main Bending", Float) = 0
        [Space(5)]
        [LuxURPWindGrassDrawer]
        _WindMultiplier             ("Wind Strength (X) Normal Strength (Y) Sample Size (Z) Lod Level (W)", Vector) = (1, 2, 1, 0)
        _Jitter                     ("Jitter", Range(0.0, 1.0)) = .1

        [Header(Distance Fading)]
        [Space(8)]
        [LuxURPDistanceFadeDrawer]
        _DistanceFade               ("Distance Fade Params", Vector) = (900, 0.005, 0, 0)

        [Header(Displacement)]
        [Space(8)]
        [Toggle(_DISPLACEMENT)]
        _Displacement               ("Enable Displacement", Float) = 0
        _DisplacementSampleSize     ("Sample Size", Range(0.0, 1)) = .5
        _DisplacementStrength       ("Displacement XZ", Range(0.0, 16.0)) = 4
        _DisplacementStrengthVertical ("Displacement Y", Range(0.0, 16.0)) = 4
        _NormalDisplacement         ("Normal Displacement", Range(-2, 2)) = 1

        [Header(Advanced)]
        [Space(8)]
        [Toggle(_BLINNPHONG)]
        _BlinnPhong                 ("Enable Blinn Phong Lighting", Float) = 0.0
        [Space(5)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0

    //  Needed by the inspector
        [HideInInspector] _Culling  ("Culling", Float) = 0.0

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _MainTex  ("Albedo", 2D) = "white" {}
        [HideInInspector] _Color    ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"                     //"RenderType" = "TransparentCutout"
            "IgnoreProjector" = "True"
            "Queue"="Geometry"
            "ShaderModel"="4.5"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull [_Cull]
            AlphaToMask [_Coverage]

            Stencil {
                Ref   1
                ReadMask 1
                WriteMask 1
                Comp  Always
                Pass  Replace
            }

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            //#pragma shader_feature_local_vertex _NORMALVS
            #pragma shader_feature_local _NORMALVS
            #pragma shader_feature_local _ALPHATEST_ON  // not per fragment!

            #pragma shader_feature_local_fragment _SPECMASK
            
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local_fragment _BLINNPHONG
            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA

            #pragma shader_feature_local_vertex _DISPLACEMENT

            #pragma shader_feature_local_fragment _RECEIVEDECALS

        //  Needed to make BlinnPhong work
            #define _SPECULAR_COLOR

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
        //  This breaks lighting when placed within the terrain engine and light layers are active
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass ForwardLit Pass.hlsl"

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
            #pragma shader_feature_local _ALPHATEST_ON              // Not per fragment!
            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA
            #pragma shader_feature_local_vertex _DISPLACEMENT

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

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass ShadowCaster Pass.hlsl"
            ENDHLSL
        }

    //  GBuffer ---------------------------
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
            
            #pragma shader_feature_local _NORMALMAP     //not per fragment!
            #pragma shader_feature_local _NORMALVS
            #pragma shader_feature_local _ALPHATEST_ON  //not per fragment!

            #pragma shader_feature_local_fragment _SPECMASK

            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA
            #pragma shader_feature_local_vertex _DISPLACEMENT

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
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

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass GBuffer Pass.hlsl"

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

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON          // not per fragment!
            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA
            #pragma shader_feature_local_vertex _DISPLACEMENT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass DepthOnly Pass.hlsl"

            ENDHLSL
        }

    //  DepthNormals -----------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON              // not per fragment!
            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA
            #pragma shader_feature_local_vertex _DISPLACEMENT
            
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS

            // -------------------------------------
            // Unity defined keywords
//  Breaks decals
//          #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            #define DEPTHNORMALPASS
            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass DepthNormal Pass.hlsl"

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

            #define _SPECULAR_SETUP 1
            #pragma shader_feature_local_fragment _ALPHATEST_ON

        //  First include all our custom stuff
            #include "Includes/Lux URP Grass Inputs.hlsl"

        //--------------------------------------
        //  Fragment shader and functions - usually defined in LitInput.hlsl

            inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
            {
                half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                outSurfaceData.alpha = Alpha(albedoAlpha.a, half4(1.0h, 1.0h, 1.0h, 1.0h), _Cutoff);
                outSurfaceData.albedo = albedoAlpha.rgb;
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

// ------------------------------------------------------------

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"                     //"RenderType" = "TransparentCutout"
            "IgnoreProjector" = "True"
            "Queue"="Geometry"
            "ShaderModel"="2.0"
        }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull [_Cull]
            AlphaToMask [_Coverage]

            Stencil {
                Ref   1
                ReadMask 1
                WriteMask 1
                Comp  Always
                Pass  Replace
            }

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ALPHATEST_ON  // not per fragment!

            #pragma shader_feature_local_fragment _SPECMASK
            
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local_fragment _BLINNPHONG
            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA
            #pragma shader_feature_local_vertex _DISPLACEMENT

            #pragma shader_feature_local_fragment _RECEIVEDECALS

        //  Needed to make BlinnPhong work
            #define _SPECULAR_COLOR

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
            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass ForwardLit Pass.hlsl"

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
            #pragma shader_feature_local _ALPHATEST_ON              // Not per fragment!
            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA
            #pragma shader_feature_local_vertex _DISPLACEMENT

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
            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass ShadowCaster Pass.hlsl"
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

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON          // not per fragment!
            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA
            #pragma shader_feature_local_vertex _DISPLACEMENT

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            

            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass DepthOnly Pass.hlsl"

            ENDHLSL
        }

    //  DepthNormals -----------------------------------------------------

        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON              // not per fragment!
            #pragma shader_feature_local_vertex _BENDINGMODE_ALPHA
            #pragma shader_feature_local_vertex _DISPLACEMENT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
            #define DEPTHNORMALPASS
            #include "Includes/Lux URP Grass Inputs.hlsl"
            #include "Includes/Lux URP Grass DepthNormal Pass.hlsl"

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

            #define _SPECULAR_SETUP 1
            #pragma shader_feature_local_fragment _ALPHATEST_ON

        //  First include all our custom stuff
            #include "Includes/Lux URP Grass Inputs.hlsl"

        //--------------------------------------
        //  Fragment shader and functions - usually defined in LitInput.hlsl

            inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
            {
                half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                outSurfaceData.alpha = Alpha(albedoAlpha.a, half4(1.0h, 1.0h, 1.0h, 1.0h), _Cutoff);
                outSurfaceData.albedo = albedoAlpha.rgb;
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
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LuxURPCustomSingleSidedShaderGUI"
}