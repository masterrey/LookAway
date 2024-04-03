// Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly

Shader "Lux URP/Clear Coat"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(vw98j94c4183)]

        [Space(8)]
        [LuxURPHelpDrawer]
        _HelpX ("Due to the custom lighting model this shader will always render in forward.", Float) = 0.0

        [Header(Surface Options)]
        [Space(8)]
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0

        [Space(5)]
        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal     ("Enable Normal in Depth Normal Pass", Float) = 1.0
        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals              ("Receive Decals", Float) = 1.0

        [Toggle]
        _DisableGBufferPass         ("Disable GBuffer Pass*", Float) = 0.0
        [Space(4)]
        [LuxURPHelpDrawer]
        _HelpY ("*GBuffer Pass is only needed if 'Accurate G-buffer normals' are enabled.", Float) = 0.0

        
        [Header(Clear Coat Inputs)]
        [Space(8)]
        _ClearCoatThickness         ("Clear Coat", Range(0.0, 1.0)) = 0.5
        _ClearCoatSmoothness        ("Clear Coat Smoothness", Range(0.0, 1.0)) = 0.5
        _ClearCoatSpecular          ("Clear Coat Specular", Color) = (0.2, 0.2, 0.2)

        [Toggle(_MASKMAP)]
        _EnableCoatMask             ("Enable Coat Mask Map", Float) = 0.0
        _CoatMask                   ("    Mask (G) Smoothness (A)", 2D) = "white" {}
        [Toggle(_STANDARDLIGHTING)]
        _EnableStandardLighting     ("    Enable Standard Lighting", Float) = 0.0
        

        [Header(Base Layer Inputs)]
        [Space(8)]
        [MainColor]
        _BaseColor                  ("Color", Color) = (1,1,1,1)
        
        [Toggle(_BASECOLORMAP)]
        _EnableBaseMap              ("Enable Base Layer Albedo Map", Float) = 0.0
        [MainTexture]
        _BaseMap                    ("Base Layer Albedo (RGB)", 2D) = "white" {}
        
        [Toggle(_SECONDARYCOLOR)]
        _EnableSecColor             ("Enable Secondary Color", Float) = 0.0
        _SecondaryColor             ("     Secondary Color", Color) = (1,1,1,1)

        [Space(5)]
        _Smoothness                 ("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic                   ("Metallic", Range(0.0, 1.0)) = 0.145
        //[Toggle(_ADJUSTSPEC)]
        //_AdjustSpec                 ("Adjust Specular", Float) = 0.0

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Map", Float) = 0.0
        _BumpMap                    ("     Normal Map", 2D) = "bump" {}
        _BumpScale                  ("     Normal Scale", Float) = 1.0

        [Toggle(_MASKMAPSECONDARY)]
        _EnableSecondaryMask        ("Enable Base Layer Mask Map", Float) = 0.0
        _SecondaryMask              ("     Metallic (R) Occlusion (G) Smoothness (A)", 2D) = "white" {}
        _Occlusion                  ("     Occlusion", Range(0.0, 1.0)) = 1.0

        [Toggle(_SECONDARYLOBE)]
        _EnableSecondaryLobe        ("Enable secondary Reflection Sample", Float) = 0.0


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
        //[ToggleOff]
        //_SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0

    //  Needed by the inspector
        [HideInInspector] _Culling  ("Culling", Float) = 0.0

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _MainTex  ("Albedo", 2D) = "white" {}
        [HideInInspector] _Color    ("Color", Color) = (1,1,1,1)
    
    //  URP 10.1. needs this for the depthnormal pass 
        [HideInInspector] _Cutoff   ("     Threshold", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Surface("__surface", Float) = 0.0
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
            Tags{"LightMode" = "UniversalForwardOnly"}

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
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _BASECOLORMAP
            #pragma shader_feature_local _SECONDARYCOLOR
            //#pragma shader_feature_local _ADJUSTSPEC
            #pragma shader_feature_local _MASKMAP
            #pragma shader_feature_local _STANDARDLIGHTING
            #pragma shader_feature_local _MASKMAPSECONDARY
            #pragma shader_feature_local _SECONDARYLOBE

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _RIMLIGHTING

            //#pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

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
            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Includes/Lux URP Clear Coat ForwardLit Pass.hlsl"

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

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Includes/Lux URP Clear Coat ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

    //  GBuffer Pass not needed any more? - It is because of fucking decals and octha normals!
    //  GBuffer Pass - minimalized which only outputs depth and writes into the normal buffers  
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

        //  We only write to the normals buffer
            ColorMask 0 0       // albedo, materialFlags
            ColorMask 0 1       // specular, occlusion
            ColorMask RGB 2     // encoded-normal(rgb), smoothness
            ColorMask 0 3       // GI (rgb)
            ColorMask 0 4       // ShadowMask
            

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
        //  We do not output the per pixel normal as it would influence coat lighting as well :(
            // #pragma shader_feature_local _NORMALMAP

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            //#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
        //  Not per fragment as we use it to kill triangles in the vertex shader
            #pragma multi_compile _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
        //  Note: Minimal GBuffer Pass does not need per pixel instance ID 

            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment

            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

        //  Material Inputs
        //  We include LitInput.hlsl - so no cbuffer definition here

            struct Attributes {
                float3 positionOS                   : POSITION;
                float3 normalOS                     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS     : SV_POSITION;
                half3 normalWS        : TEXCOORD1;
                //UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings LitGBufferPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                //UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
                output.normalWS = normalInput.normalWS;
                return output;
            }

            FragmentOutput LitGBufferPassFragment(Varyings input)
            {
                //UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif
                
                half3 packedNormalWS = PackNormal(input.normalWS);
                FragmentOutput output = (FragmentOutput)0;
                output.GBuffer2 = half4(packedNormalWS, 1);  
                return output;
            }
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

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            #define DEPTHONLYPASS
            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Includes/Lux URP Clear Coat DepthOnly Pass.hlsl"
          
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
        //  We do not output the per pixel normal as it would influence coat lighting as well :(
            // #pragma shader_feature_local _NORMALMAP

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

            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
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

            #pragma shader_feature_local _BASECOLORMAP

        //  First include all our custom stuff
            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Includes/Lux URP Clear Coat Meta Pass.hlsl"

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }
    
    }


//  ------------------------------------------

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
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _BASECOLORMAP
            #pragma shader_feature_local _SECONDARYCOLOR
            //#pragma shader_feature_local _ADJUSTSPEC
            #pragma shader_feature_local _MASKMAP
            #pragma shader_feature_local _STANDARDLIGHTING
            #pragma shader_feature_local _MASKMAPSECONDARY
            #pragma shader_feature_local _SECONDARYLOBE

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _RIMLIGHTING

            //#pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local_fragment _RECEIVEDECALS


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
            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Includes/Lux URP Clear Coat ForwardLit Pass.hlsl"

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

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Includes/Lux URP Clear Coat ShadowCaster Pass.hlsl"
            
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

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
            #define DEPTHONLYPASS
            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Includes/Lux URP Clear Coat DepthOnly Pass.hlsl"
          
            ENDHLSL
        }

    //  Depth Normal ---------------------------------------------
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
        //  We do not output the per pixel normal as it would influence coat lighting as well :(
            // #pragma shader_feature_local _NORMALMAP

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
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

            #pragma shader_feature_local _BASECOLORMAP

        //  First include all our custom stuff
            #include "Includes/Lux URP Clear Coat Inputs.hlsl"
            #include "Includes/Lux URP Clear Coat Meta Pass.hlsl"

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }
    
    }
    FallBack "Hidden/InternalErrorShader"
    CustomEditor "LuxURPUniversalCustomShaderGUI"
}
