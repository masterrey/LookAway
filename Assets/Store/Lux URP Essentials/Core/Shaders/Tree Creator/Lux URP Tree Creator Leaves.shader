// Shader uses custom editor to set double sided GI
// Needs _Culling to be set properly

Shader "Lux URP/Nature/Tree Creator Leaves"
{
    Properties
    {

        [Header(Surface Inputs)]
        [Space(5)]
        _Color                      ("Main Color", Color) = (1,1,1,1)
        [PowerSlider(5.0)] _Shininess ("Shininess", Range (0.01, 1)) = 0.078125
        _MainTex                    ("Base (RGB) Alpha (A)", 2D) = "white" {}
        _Cutoff                     ("Alpha cutoff", Range(0.0, 1.0)) = 0.5

        [Space(5)]
        [NoScaleOffset]
        _BumpMap                    ("Normalmap", 2D) = "bump" {}
        [NoScaleOffset]
        _GlossMap                   ("Gloss (A)", 2D) = "black" {}
        [NoScaleOffset]
        _TranslucencyMap            ("Translucency (A)", 2D) = "white" {}

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
        }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            // #define _SPECULAR_SETUP 1

            #define DUMMYSHADER

            #define _ALPHATEST_ON
            #define _NORMALMAP

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

        //  Trees do not support lightmapping
            // #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            // #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Tree Creator Inputs.hlsl"
            
            #include "Includes/Lux URP Creator Leaves ForwardLit Pass.hlsl"

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }
    FallBack "Hidden/InternalErrorShader"
    Dependency "OptimizedShader" = "Lux URP/Nature/Tree Creator Leaves Optimized"
}