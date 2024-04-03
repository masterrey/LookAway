// Shader uses custom editor to set double sided GI.
// Needs _Culling to be set properly.

Shader "Lux URP/Human/Skin"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(snoamqpqhtdl)]

        [Space(8)]
        [LuxURPHelpDrawer]
        _HelpX ("Due to the custom lighting model this shader will always render in forward.", Float) = 0.0

        [Header(Surface Options)]
        [Space(8)]
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0
        _SkinShadowBias             ("     Shadow Caster Bias", Range(.1, 1.0)) = 1.0
        _SkinShadowSamplingBias     ("     Shadow Sampling Bias", Range(0, 0.05)) = 0

        [Space(5)]
        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal     ("Enable Normal in Depth Normal Pass", Float) = 1.0
        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals              ("Receive Decals", Float) = 1.0
        
        [Header(Surface Inputs)]
        [Space(8)]
        [NoScaleOffset] [MainTexture]
        _BaseMap                    ("Albedo (RGB) Smoothness (A)", 2D) = "white" {}
        [MainColor]
        _BaseColor                  ("Color", Color) = (1,1,1,1)
        
        [Space(5)]
        _Smoothness                 ("Smoothness", Range(0.0, 1.0)) = 0.5
    //  For some reason android did not like _SpecColor!?
        _SpecularColor              ("Specular", Color) = (0.2, 0.2, 0.2)

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Map", Float) = 0.0
        [NoScaleOffset]
        _BumpMap                    ("     Normal Map", 2D) = "bump" {}
        _BumpScale                  ("     Normal Scale", Float) = 1.0
        [Toggle(_NORMALMAPDIFFUSE)]
        _ApplyNormalDiffuse         ("     Enable Diffuse Normal Sample", Float) = 0.0
        _Bias                       ("     Bias", Range(0.0, 8.0)) = 3.0
        [Toggle]_VertexNormal       ("          Use Vertex Normal for Diffuse", Float) = 1

        [Space(5)]
        [Toggle(_DETAILNORMALMAP)]
        _ApplyDetailNormal          ("Enable Detail Normal Map", Float) = 0.0
        _DetailBumpMap              ("     Detail Normal Map", 2D) = "bump" {}
        _DetailBumpScale            ("     Detail Normal Scale", Float) = 1.0

        [Header(Skin Lighting)]
        [Space(8)]
        [NoScaleOffset] _SSSAOMap   ("Skin Mask (R) Thickness (G) Curvature (B) Occlusion (A)", 2D) = "white" {}
        
        _OcclusionStrength          ("Occlusion Strength", Range(0.0, 1.0)) = 1.0

        [Toggle]
        _SampleCurvature            ("Sample Curvature", Float) = 0
        _Curvature                  ("Curvature", Range(0.0, 1.0)) = 0.5

        _SubsurfaceColor            ("Subsurface Color", Color) = (1.0, 0.4, 0.25, 1.0)
        _TranslucencyPower          ("Transmission Power", Range(0.0, 10.0)) = 7.0
        _TranslucencyStrength       ("Transmission Strength", Range(0.0, 1.0)) = 1.0
        _ShadowStrength             ("Shadow Strength", Range(0.0, 1.0)) = 0.7
        _MaskByShadowStrength       ("Mask by incoming Shadow Strength", Range(0.0, 1.0)) = 1.0
        _Distortion                 ("Transmission Distortion", Range(0.0, 0.1)) = 0.01
        _DecalTransmission          ("Decal Transmission", Range(0.0, 1)) = 1

        [Space(5)]
        [Toggle(_BACKSCATTER)]
        _EnableBackscatter          ("Enable Ambient Back Scattering", Float) = 0
        _Backscatter                ("Ambient Back Scattering", Range(0.0, 8.0)) = 1

        [Space(5)]
        _AmbientReflectionStrength  ("Ambient Reflection Strength", Range(0.0, 1)) = 1

        [Space(5)]
        [NoScaleOffset] _SkinLUT    ("Skin LUT", 2D) = "white" {}

        [Header(Distance Fading)]
        [Space(8)]
        [Toggle(_DISTANCEFADE)]
        _EnableDistanceFade         ("Enable Distance Fade", Float) = 0.0
        [LuxURPDistanceFadeDrawer]
        _DistanceFade               ("Distance Fade Params", Vector) = (2500, 0.001, 0, 0)


        [Header(Rim Lighting)]
        [Space(8)]
        [Toggle(_RIMLIGHTING)]
        _Rim                        ("Enable Rim Lighting", Float) = 0
        [HDR] _RimColor             ("Rim Color", Color) = (0.5,0.5,0.5,1)
        _RimPower                   ("Rim Power", Float) = 2
        _RimFrequency               ("Rim Frequency", Float) = 0
        _RimMinPower                ("     Rim Min Power", Float) = 1
        _RimPerPositionFrequency    ("     Rim Per Position Frequency", Range(0.0, 1.0)) = 1

        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0


        [Header(Stencil)]
        [Space(8)]
        [IntRange] _Stencil         ("Stencil Reference", Range (0, 255)) = 0
        [IntRange] _ReadMask        ("     Read Mask", Range (0, 255)) = 255
        [IntRange] _WriteMask       ("     Write Mask", Range (0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _StencilComp                ("Stencil Comparison", Int) = 8     // always 
        [Enum(UnityEngine.Rendering.StencilOp)]
        _StencilOp                  ("Stencil Operation", Int) = 0      // 0 = keep, 2 = replace
        [Enum(UnityEngine.Rendering.StencilOp)]
        _StencilFail                ("Stencil Fail Op", Int) = 0        // 0 = keep
        [Enum(UnityEngine.Rendering.StencilOp)] 
        _StencilZFail               ("Stencil ZFail Op", Int) = 0       // 0 = keep

    //  Needed by the inspector
        [HideInInspector] _Culling  ("Culling", Float) = 0.0

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _MainTex  ("Albedo", 2D) = "white" {}
        [HideInInspector] _Color    ("Color", Color) = (1,1,1,1)
        [HideInInspector] _Cutoff   ("Alpha Cutoff", Range(0.0, 1.0)) = 0.0

        [HideInInspector] _Surface("__surface", Float) = 0.0
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

    //  ForwardLit -----------------------------------------------------
        Pass
        {
            Name "ForwardLit"
        //  Needs "UniversalForwardOnly" to render in deferred
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
            #define _SPECULAR_SETUP
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _DETAILNORMALMAP
            #pragma shader_feature_local_fragment _NORMALMAPDIFFUSE
            #pragma shader_feature_local _DISTANCEFADE                  // not per fragment
            #pragma shader_feature_local_fragment _RIMLIGHTING
            #pragma shader_feature_local_fragment _BACKSCATTER

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
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin ForwardLit Pass.hlsl"

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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin ShadowCaster Pass.hlsl"
        
            ENDHLSL
        }

    //  GBuffer Pass not needed any more? It is - fucking decals and ortho normals
    //  GBuffer Pass - minimalized which only outputs depth and writes into the normal buffers  
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite On
            Cull Back
            
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
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS
            #pragma shader_feature_local _NORMALMAPDIFFUSE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment
            
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
            
            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif
           
            struct Attributes {
                float3 positionOS                   : POSITION;
                #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) && defined(_NORMALMAPDIFFUSE)
                    float2 texcoord                 : TEXCOORD0;
                #endif
                float3 normalOS                     : NORMAL;
                #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) && defined(_NORMALMAPDIFFUSE)
                    float4 tangentOS                : TANGENT;
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS     : SV_POSITION;
                #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) && defined(_NORMALMAPDIFFUSE)
                    float2 uv         : TEXCOORD0;
                #endif
                half3 normalWS        : TEXCOORD1;
                #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) && defined(_NORMALMAPDIFFUSE)
                    half4 tangentWS   : TEXCOORD2;
                #endif
                //UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };


            Varyings LitGBufferPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                //UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) && defined(_NORMALMAPDIFFUSE)
                    output.uv = input.texcoord; //TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) && defined(_NORMALMAPDIFFUSE)
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                    half sign = input.tangentOS.w * GetOddNegativeScale();
                    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
                #else
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
                #endif
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
                
                #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) && defined(_NORMALMAPDIFFUSE)
                    
                    half4 sampleNormalDiffuse = SAMPLE_TEXTURE2D_BIAS(_BumpMap, sampler_BumpMap, input.uv, _Bias);
                    half3 normalTS = UnpackNormalScale(sampleNormalDiffuse, _BumpScale);

                    float sgn = input.tangentWS.w;      // should be either +1 or -1
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    half3x3 ToW = half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz);
                    input.normalWS = TransformTangentToWorld(normalTS, ToW);

                #endif

                half3 packedNormalWS = PackNormal(input.normalWS);
                FragmentOutput output = (FragmentOutput)0;
                output.GBuffer2 = half4(packedNormalWS, 1);  
                return output;
            }

            ENDHLSL
        }

    //  Depth Only -----------------------------------------------------
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
            
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin DepthOnly Pass.hlsl"

            ENDHLSL
        }

    //  Depth Normals --------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS
            #pragma shader_feature_local _NORMALMAPDIFFUSE

            // -------------------------------------
            // Unity defined keywords
//  Breaks decals
//          #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin DepthNormal Pass.hlsl"
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

        //  First include all our custom stuff
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin Meta Pass.hlsl"
        

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

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
            #define _SPECULAR_SETUP
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _DETAILNORMALMAP
            #pragma shader_feature_local_fragment _NORMALMAPDIFFUSE
            #pragma shader_feature_local _DISTANCEFADE 					// not per fragment
            #pragma shader_feature_local_fragment _RIMLIGHTING
            #pragma shader_feature_local_fragment _BACKSCATTER

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
            

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin ForwardLit Pass.hlsl"

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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin ShadowCaster Pass.hlsl"
        
            ENDHLSL
        }

    //  Depth Only -----------------------------------------------------
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
            
            
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Normals --------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS
            #pragma shader_feature_local _NORMALMAPDIFFUSE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin DepthNormal Pass.hlsl"
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
            #include "Includes/Lux URP Skin Inputs.hlsl"
            #include "Includes/Lux URP Skin Meta Pass.hlsl"
        

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }
    CustomEditor "LuxURPCustomSkinShaderGUI"
    FallBack "Hidden/InternalErrorShader"
}
