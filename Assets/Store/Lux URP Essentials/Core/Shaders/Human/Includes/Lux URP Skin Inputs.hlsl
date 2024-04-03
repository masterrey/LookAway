#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

//  Has to be declared before lighting gets included!
    struct AdditionalSurfaceData {
        half3 diffuseNormalTS;
        half translucency;
        half skinMask;
        half curvature;
    };

//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "../Includes/Lux URP Skin Lighting.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)

        half4   _BaseColor;
        half4   _SpecularColor;

        float4  _BaseMap_ST;
        half    _Smoothness;
        
        half    _BumpScale;
        half    _Bias;

        half    _DetailBumpScale;

        half    _SkinShadowBias;
        half    _SkinShadowSamplingBias;

        half    _OcclusionStrength;

        half4   _SubsurfaceColor;
        half    _SampleCurvature;
        half    _Curvature;        
        float2  _DistanceFade;

        half    _TranslucencyPower;
        half    _TranslucencyStrength;
        half    _ShadowStrength;
        half    _MaskByShadowStrength;
        half    _Distortion;
        half    _AmbientReflectionStrength;

        half    _DecalTransmission;

        half4   _RimColor;
        half    _RimPower;
        half    _RimMinPower;
        half    _RimFrequency;
        half    _RimPerPositionFrequency;

    //  Needed by URP 10.1. and depthnormal
        half    _Cutoff;
        half    _Surface;

        half    _Backscatter;
        half    _VertexNormal;

        float4 _DetailBumpMap_ST;

    CBUFFER_END

//  Additional textures
    TEXTURE2D(_SSSAOMap); SAMPLER(sampler_SSSAOMap);
    TEXTURE2D(_DetailBumpMap); 

//  Global Inputs

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
            UNITY_DOTS_INSTANCED_PROP(float , _Surface)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
        #define _Surface                UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Surface)
    #endif

#endif