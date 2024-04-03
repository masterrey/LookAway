#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

//  Has to be declared before lighting gets included!
    struct AdditionalSurfaceData {
        half translucency;
    };

//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "../Includes/Lux URP Cloth Lighting.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)
        half4   _BaseColor;
        half    _Cutoff;
        float4  _BaseMap_ST;
        half    _Smoothness;
        half4   _SpecColor;
        half    _Anisotropy;
        half4   _SheenColor;
        half    _BumpScale;
        float4  _MaskMap_ST;
        half    _OcclusionStrength;
        half    _TranslucencyPower;
        half    _TranslucencyStrength;
        half    _ShadowStrength;
        half    _Distortion;
        half    _ShadowOffset;
        half4   _RimColor;
        half    _RimPower;
        half    _RimMinPower;
        half    _RimFrequency;
        half    _RimPerPositionFrequency;
        half    _Surface;
    CBUFFER_END

//  Additional textures
    #if defined(_MASKMAP)
        TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
    #endif

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