// Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly
// See: http://amd-dev.wpengine.netdna-cdn.com/wordpress/media/2012/10/Scheuermann_HairSketchSlides.pdf

Shader "Lux URP/Human/Hair"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(7a3r84ualf3h)]
        
        [Header(Surface Options)]
        [Space(5)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                       ("Culling", Float) = 0
        [Toggle(_ENABLEVFACE)]
        _EnableVFACE                ("     Enable VFACE", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)]
        _ShadowCull                 ("Shadow Culling", Float) = 0
        [Enum(Off,0,On,1)]_Coverage ("Alpha To Coverage", Float) = 1
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0

        [Header(Surface Inputs)]
        [Space(5)]
        [MainColor]
        _BaseColor                  ("Base Color", Color) = (1,1,1,1)
        _SecondaryColor             ("Secondary Color", Color) = (1,1,1,1)
        [NoScaleOffset] [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
        _Cutoff                     ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Map", Float) = 0.0
        [NoScaleOffset]
        _BumpMap                    ("     Normal Map", 2D) = "bump" {}
        _BumpScale                  ("     Normal Scale", Float) = 1.0

        [Space(5)]
        [Toggle(_MASKMAP)]
        _EnableMaskMap              ("Enable Mask Map", Float) = 0
        [NoScaleOffset] _MaskMap    ("     Shift (B) Occlusion (G)", 2D) = "white" {}
        
        [Space(5)]
        _SpecColor                  ("Specular", Color) = (0.2, 0.2, 0.2)
        _Smoothness                 ("Smoothness", Range(0.0, 1.0)) = 1

        [Header(Hair Lighting)]
        [Space(5)]
        [KeywordEnum(Bitangent,Tangent)]
        _StrandDir                  ("Strand Direction", Float) = 0

        [Space(5)]
        _SpecularShift              ("Primary Specular Shift", Range(-1.0, 1.0)) = 0.1
        [HDR] _SpecularTint         ("Primary Specular Tint", Color) = (1, 1, 1, 1)
        _SpecularExponent           ("Primary Smoothness", Range(0.0, 1)) = .85

        [Space(5)]
        [Toggle(_SECONDARYLOBE)]
        _SecondaryLobe              ("Enable Secondary Highlight", Float) = 1
        [Space(5)]
        _SecondarySpecularShift     ("Secondary Specular Shift", Range(-1.0, 1.0)) = 0.1
        [HDR] _SecondarySpecularTint("Secondary Specular Tint", Color) = (1, 1, 1, 1)
        _SecondarySpecularExponent  ("Secondary Smoothness", Range(0.0, 1)) = .8

        [Space(5)]
        _RimTransmissionIntensity   ("Rim Transmission Intensity", Range(0.0, 8.0)) = 0.5
        _AmbientReflection          ("Ambient Reflection Strength", Range(0.0, 1.0)) = 1

        [Header(Rim Lighting)]
        [Space(5)]
        [Toggle(_RIMLIGHTING)]
        _Rim                        ("Enable Rim Lighting", Float) = 0
        [HDR] _RimColor             ("Rim Color", Color) = (0.5,0.5,0.5,1)
        _RimPower                   ("Rim Power", Float) = 2
        _RimFrequency               ("Rim Frequency", Float) = 0
        _RimMinPower                ("     Rim Min Power", Float) = 1
        _RimPerPositionFrequency    ("     Rim Per Position Frequency", Range(0.0, 1.0)) = 1

        [Header(Advanced)]
        [Space(5)]
        //[ToggleOff]
        //_SpecularHighlights       ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0


        [Header(Stencil)]
        [Space(5)]
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
        
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
        }
        LOD 100

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
            Cull [_Cull]
            AlphaToMask [_Coverage]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

        //  Shader target needs to be 3.0 due to tex2Dlod in the vertex shader and VFACE
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1
            #define _ALPHATEST_ON 1

            #pragma shader_feature_local _ENABLEVFACE

            #pragma shader_feature_local _STRANDDIR_BITANGENT
            #pragma shader_feature_local _MASKMAP
            #pragma shader_feature_local _SECONDARYLOBE

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _RIMLIGHTING

            //#pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Lightweight Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Hair Inputs.hlsl"
            #include "Includes/Lux URP Hair Core.hlsl"

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
            Cull [_ShadowCull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #define _ALPHATEST_ON 1

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Hair Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
        //  Shadow caster specific input
            float3 _LightDirection;

            VertexOutput ShadowPassVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldDir(input.normalOS);

                output.uv = input.texcoord;

                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                return output;
            }

            half4 ShadowPassFragment(VertexOutput input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half alpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a;
                alpha *= _BaseColor.a;
                clip(alpha - _Cutoff);

                return 0;
            }
            ENDHLSL
        }

    //  Depth -----------------------------------------------------

        Pass
        {
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #define _ALPHATEST_ON 1

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #define DEPTHONLYPASS
            #include "Includes/Lux URP Hair Inputs.hlsl"

            VertexOutput DepthOnlyVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.texcoord;
                return output;
            }

            half4 DepthOnlyFragment(VertexOutput input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half alpha = SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a;
                alpha *= _BaseColor.a;
                clip(alpha - _Cutoff);

                return 0;
            }

            ENDHLSL
        }

    //  Meta -----------------------------------------------------
        
        Pass
        {
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMeta

            #define _SPECULAR_SETUP

        //  First include all our custom stuff
            #include "Includes/Lux URP Hair Inputs.hlsl"

        //--------------------------------------
        //  Fragment shader and functions

            inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
            {
                half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                outSurfaceData.alpha = 1;
                outSurfaceData.albedo = albedoAlpha.rgb;
                outSurfaceData.metallic = 0;
                outSurfaceData.specular = _SpecColor;
                outSurfaceData.smoothness = _Smoothness;
                outSurfaceData.normalTS = half3(0,0,1);
                outSurfaceData.occlusion = 1;
                outSurfaceData.emission = 0;
            }

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }
    CustomEditor "LuxURPUniversalCustomShaderGUI"
    FallBack "Hidden/InternalErrorShader"
}