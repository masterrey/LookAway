// Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly

Shader "Lux URP/Toon HLSL"
{
    Properties
    {
        [HeaderHelpLuxURPToon_URL(6zvjnfuiskj1)]

        [Space(8)]
        [LuxURPHelpDrawer]
        _HelpX ("Due to the custom lighting model this shader will always render in forward.", Float) = 0.0

        [Header(Surface Options)]
        [Space(8)]
        
        [Enum(Opaque,0,Transparent,1)]
        _LuxSurface                 ("Surface Type", Float) = 0.0
        [Enum(Alpha,0,Premultiply,1,Additive,2,Multiply,3)]
        _LuxBlend                   ("     Blending", Float) = 0.0
        [HideInInspector]
        _SrcBlend                   ("SrcBlend", Float) = 1.0
        [HideInInspector]
        _DstBlend                   ("DstBlend", Float) = 0.0
        [HideInInspector]
        _SrcBlendAlpha              ("SrcAlphaBlend", Float) = 1.0
        [HideInInspector]
        _DstBlendAlpha              ("DstAlphaBlend", Float) = 0.0
        //[HideInInspector]
        [Enum(Off,0,On,1)]  
        _ZWrite                     ("ZWrite", Float) = 1.0

        [Enum(UnityEngine.Rendering.CompareFunction)]
        _ZTest                      ("ZTest", Int) = 4
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                       ("Culling", Float) = 2
        [Toggle(_ALPHATEST_ON)]
        _AlphaClip                  ("Alpha Clipping", Float) = 0.0
        [LuxURPHelpDrawer]
        _Help ("Enabling Alpha Clipping needs you to enable and assign the Albedo (RGB) Alpha (A) Map as well.", Float) = 0.0
        _Cutoff                     ("     Threshold", Range(0.0, 1.0)) = 0.5
        [Enum(Off,0,On,1)]_Coverage ("     Alpha To Coverage*", Float) = 0
        [Space(4)]
        [LuxURPHelpDrawer]
        _HelpA ("* Will most likely break if any Depth Prepass is active.", Float) = 0.0

        [Space(5)]
        [Toggle(_SSAO_ENABLED)]
        _ReceiveSSAO                ("Receive SSAO", Float) = 1.0
        [Toggle(_RECEIVEDECALS)]
        _ReceiveDecals              ("Receive Decals", Float) = 1.0
        [Toggle(_NORMALINDEPTHNORMALPASS)]
        _ApplyNormalDepthNormal     ("Enable Normal in Depth Normal Pass", Float) = 1.0

        [Header(Decals)]
        [Space(8)]
        _ShadedDecalColor           ("Shaded Decal Color (multipier)", Color) = (0.5, 5.5, 0.5, 1)
        
        [Header(Toon Lighting)]
        [Space(8)]
        [IntRange] _Steps           ("Steps", Range(1, 8)) = 1
        _DiffuseFallOff             ("Diffuse Falloff", Range(0, 1)) = 0.01
        _DiffuseStep                ("Diffuse Step", Range(-1, 1)) = 0
        [Space(5)]
        [KeywordEnum(Off, SmoothSampling, PointSampling)] _Ramp ("Ramp Mode", Float) = 0
        [NoScaleOffset]
        _GradientMap                ("     Ramp", 2D) = "white" {}
        _OcclusionStrength          ("Occlusion (inverse)", Range(0.0, 1.0)) = 1

        [Header(Advanced Toon Lighting)]
        [Space(8)]
        //[Toggle(_COLORIZEMAIN)]
        _ColorizedShadowsMain       ("Colorize Main Light", Range(0, 1)) = 0.0
        //[Toggle(_COLORIZEADD)]
        _ColorizedShadowsAdd        ("Colorize Add Lights", Range(0, 1)) = 0.0
        _LightColorContribution     ("Light Color Contribution", Range(0, 1)) = 1
        _AddLightFallOff            ("Light Falloff", Range(0.0001, 1)) = 1

        [Header(Specular Toon Lighting)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [Toggle(_ANISOTROPIC)]
        _Anisotropic                ("     Anisotropic Specular", Float) = 0.0
        _Anisotropy                 ("          Anisotropy", Range(-1.0, 1.0)) = 0.0
        [Space(5)]
        [Toggle]
        _EnergyConservation         ("     EnergyConservation", Float) = 1
        [HDR] _SpecColor            ("     Specular", Color) = (0.2, 0.2, 0.2)
        [HDR] _SpecColor2nd         ("     Secondary Specular", Color) = (0.4, 0.4, 0.4)
        _Smoothness                 ("     Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecularStep               ("     Specular Step", Range(0.3, 0.5)) = 0.45
        _SpecularFallOff            ("     Specular Falloff", Range(0, 1)) = 0.01
        

        [Header(Toon Rim)]
        [Space(8)]
        [Toggle(_TOONRIM)]
        _EnableToonRim              ("Enable Toon Rim", Float) = 0.0
        [HDR] _ToonRimColor         ("     Rim Color", Color) = (1, 1, 1, 1)
        _ToonRimPower               ("     Rim Power", Range(0, 1)) = 0.5
        _ToonRimFallOff             ("     Rim Falloff", Range(0, 1)) = 1
        _ToonRimAttenuation         ("     Rim Attenuation", Range(0, 1)) = 0


        [Header(Toon Shadows)]
        [Space(8)]
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0
        _ShadowOffset               ("     Shadow Offset", Float) = 1.0
        _ShadowFallOff              ("     Shadow Falloff", Range(0.5, 1)) = 0.75
        _ShadoBiasDirectional       ("     Shadow Bias Directional", Range(0, 1)) = 0
        _ShadowBiasAdditional       ("     Shadow Bias Additional", Range(0, 1)) = 0
        

        [Header(Surface Inputs)]
        [Space(8)]
        [MainColor]
        _BaseColor                  ("Color (RGB) Alpha (A)", Color) = (1,1,1,1)
        _ShadedBaseColor            ("Shaded Color (RGB)", Color) = (0,0,0,1)

        [Space(5)]
        [KeywordEnum(Off, One, Two)] _TexMode ("TextureMode", Float) = 0
        [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
        [NoScaleOffset]
        _ShadedBaseMap              ("Shaded Albedo (RGB)", 2D) = "white" {}

        [Space(5)]
        [Toggle(_MASKMAP)]
        _EnableMaskMap              ("Enable Mask Map", Float) = 0.0
        [NoScaleOffset]
        _MaskMap                    ("     Emission (R) Specular (G) Occlusion (B) Smoothness (A)", 2D) = "white" {}
        [HDR] _EmissionColor        ("     Emission Color", Color) = (0,0,0,0)

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Map", Float) = 0.0
        [NoScaleOffset]
        _BumpMap                    ("     Normal Map", 2D) = "bump" {}
        _BumpScale                  ("     Normal Scale", Float) = 1.0

        
    //  Lux URP standards 
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
        _StencilFail                ("Stencil Fail Op", Int) = 0        // 0 = keep
        [Enum(UnityEngine.Rendering.StencilOp)] 
        _StencilZFail               ("Stencil ZFail Op", Int) = 0       // 0 = keep

        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 0.0
        
        [Header(Render Queue)]
        [Space(8)]
        [IntRange] _QueueOffset     ("Queue Offset", Range(-50, 50)) = 0


    //  Needed by the inspector
        [HideInInspector] _Culling  ("Culling", Float) = 0.0
        [HideInInspector] _AlphaFromMaskMap  ("AlphaFromMaskMap", Float) = 1.0

    //  URP 10.+
        [HideInInspector] _Surface("__surface", Float) = 0.0 

    //  ObsoleteProperties
        [HideInInspector] _MainTex  ("Albedo", 2D) = "white" {}
        [HideInInspector] _Color    ("Color", Color) = (1,1,1,1)
        [HideInInspector] _GlossMapScale("Smoothness", Float) = 0.0
        [HideInInspector] _Glossiness("Smoothness", Float) = 0.0
        [HideInInspector] _GlossyReflections("EnvironmentReflections", Float) = 0.0

        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
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
            
            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Cull [_Cull]
            AlphaToMask [_Coverage]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
            #pragma shader_feature_local_fragment _COLORIZEMAIN
            #pragma shader_feature_local_fragment _COLORIZEADD
            #pragma shader_feature_local_fragment _TOONRIM
            //#pragma shader_feature_local GRADIENT_ON
            #pragma shader_feature_local _ _RAMP_SMOOTHSAMPLING _RAMP_POINTSAMPLING
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO

            #pragma shader_feature_local_fragment _SSAO_ENABLED
            #pragma shader_feature_local_fragment _RECEIVEDECALS

            #pragma shader_feature_local _MASKMAP

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _RIMLIGHTING

            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT 
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local _ANISOTROPIC       // Also affects vertex shader! (vertex input)

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
            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon ForwardLit Pass.hlsl"

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
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon ShadowCaster Pass.hlsl"

            ENDHLSL
        }


    //  GBuffer Pass not needed any more? - It is because of fucking decals and octha normals!
    //  GBuffer Pass - minimalized which only outputs depth and writes into the normal buffers  
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Cull [_Cull]

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
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO
            #pragma shader_feature_local _NORMALMAP

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

        //  As we do not store the alpha mask with the base map we have to use custom functions 
            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment

            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            //  Material Inputs
            //  We include LitInput.hlsl - so no cbuffer definition here

            struct Attributes {
                float3 positionOS                   : POSITION;
                #if defined(_ALPHATEST_ON) || defined(_NORMALMAP)
                    float2 texcoord                 : TEXCOORD0;
                #endif
                float3 normalOS                     : NORMAL;
                #if defined(_NORMALMAP)
                    float4 tangentOS                : TANGENT;
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS     : SV_POSITION;
                #if defined(_ALPHATEST_ON) || defined (_NORMALMAP)
                    float2 uv         : TEXCOORD0;
                #endif
                half3 normalWS        : TEXCOORD1;
                #if defined(_NORMALMAP) // && defined(_SCREEN_SPACE_OCCLUSION)
                    half4 tangentWS   : TEXCOORD2;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings LitGBufferPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if defined(_NORMALMAP)
                    output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif
                #if defined(_ALPHATEST_ON) || defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
                    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

            //  Normal output is only really needed if SSAO is enabled
                #if defined(_NORMALMAP) // && defined(_SCREEN_SPACE_OCCLUSION)
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                    half sign = input.tangentOS.w * GetOddNegativeScale();
                    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
                #else
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
                #endif
                output.normalWS = normalInput.normalWS;
                return output;
            }

            FragmentOutput LitGBufferPassFragment(Varyings input, half facing : VFACE)
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                #ifdef LOD_FADE_CROSSFADE
                    LODFadeCrossFade(input.positionCS);
                #endif
                
                #if defined(_ALPHATEST_ON)
                    half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;
                    clip (mask * _BaseColor.a - _Cutoff);
                #endif

                #if defined(_NORMALMAP) // && defined(_SCREEN_SPACE_OCCLUSION)
                    half3 normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
                    normalTS.z *= facing;
                    float sgn = input.tangentWS.w;
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    half3x3 ToW = half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz);
                    input.normalWS = TransformTangentToWorld(normalTS, ToW);
                #else
                    input.normalWS *= facing;
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
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Normals -----------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon DepthNormal Pass.hlsl"
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
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO

        //  First include all our custom stuff
            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon Meta Pass.hlsl"
        
        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }
    }


// ----------------------------------------------------------------------


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
            
            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Cull [_Cull]
            AlphaToMask [_Coverage]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
            #pragma shader_feature_local_fragment _COLORIZEMAIN
            #pragma shader_feature_local_fragment _COLORIZEADD
            #pragma shader_feature_local_fragment _TOONRIM
            //#pragma shader_feature_local GRADIENT_ON
            #pragma shader_feature_local _ _RAMP_SMOOTHSAMPLING _RAMP_POINTSAMPLING
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO

            #pragma shader_feature_local_fragment _SSAO_ENABLED
            #pragma shader_feature_local_fragment _RECEIVEDECALS

            #pragma shader_feature_local _MASKMAP

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _RIMLIGHTING

            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT 
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local _ANISOTROPIC       // Also affects vertex shader! (vertex input)

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
            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon ForwardLit Pass.hlsl"

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
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO


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
            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon ShadowCaster Pass.hlsl"

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
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth Normals -----------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO
            #pragma shader_feature_local _NORMALINDEPTHNORMALPASS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon DepthNormal Pass.hlsl"
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
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ _TEXMODE_ONE _TEXMODE_TWO

        //  First include all our custom stuff
            #include "Includes/Lux URP Toon Inputs.hlsl"
            #include "Includes/Lux URP Toon Meta Pass.hlsl"
        
        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }
    }

    FallBack "Hidden/InternalErrorShader"
    CustomEditor "LuxURPUniversalCustomShaderGUI"
}
