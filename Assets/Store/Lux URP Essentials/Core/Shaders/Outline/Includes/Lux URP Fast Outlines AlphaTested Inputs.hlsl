#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  

//  SRP Batcher always complained - so we drop this    
    //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)
        half4   _BaseColor;
        float4  _BaseMap_ST;
        half    _Cutoff;
        half4   _OutlineColor;
        half    _Border;
        float4  _BaseMap_TexelSize;
        float4  _BaseMap_MipInfo;
    CBUFFER_END

    TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

//  Additional textures

//  Global Inputs

//  Helper functions as we do not include SurfaceInput.hlsl anymore
    half Alpha(half albedoAlpha, half4 color, half cutoff)
    {
    #if !defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A) && !defined(_GLOSSINESS_FROM_BASE_ALPHA)
        half alpha = albedoAlpha * color.a;
    #else
        half alpha = color.a;
    #endif

        alpha = AlphaDiscard(alpha, cutoff);

        return alpha;
    }
    
    half4 SampleAlbedoAlpha(float2 uv, TEXTURE2D_PARAM(albedoAlphaMap, sampler_albedoAlphaMap))
    {
        return half4(SAMPLE_TEXTURE2D(albedoAlphaMap, sampler_albedoAlphaMap, uv));
    }

//  Structs
    struct Attributes
    {
        float3 positionOS                   : POSITION;
        float2 texcoord                     : TEXCOORD0;
        float3 normalOS                     : NORMAL;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    
    struct Varyings
    {
        float4 positionCS                   : SV_POSITION;
        float2 uv                           : TEXCOORD0;
        half3 normalWS                      : TEXCOORD1;
        float3 positionWS                   : TEXCOORD2;
        // #if defined(_APPLYFOG)
            half fogFactor                  : TEXCOORD3;
        // #endif
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    struct SurfaceDescriptionSimple
    {
        half alpha;
    };

//  Helper
    inline float2 shufflefast (float2 offset, float2 shift) {
        return offset * shift;
    }

#endif