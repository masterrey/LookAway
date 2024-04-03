#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

//  Structs
struct VertexInputMeta
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 uv0          : TEXCOORD0;
    float2 uv1          : TEXCOORD1;
    float2 uv2          : TEXCOORD2;
    #ifdef _TANGENT_TO_WORLD
        float4 tangentOS    : TANGENT;
    #endif
};

struct VertexOutputMeta
{
    float4 positionCS   : SV_POSITION;
    float4 uv           : TEXCOORD0;
};

inline void InitializeStandardLitSurfaceData(float4 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    #if defined(_ALPHATEST_ON) && defined(_MASKMAP)
        outSurfaceData.alpha = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, uv.zw).a;
        clip(outSurfaceData.alpha - _Cutoff);
    #else
        outSurfaceData.alpha = 1;
    #endif

    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
    outSurfaceData.smoothness = _Smoothness;
    outSurfaceData.normalTS = half3(0,0,1);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;

    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

VertexOutputMeta LuxVertexMeta(VertexInputMeta input)
{
    VertexOutputMeta output;
    output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2,
        unity_LightmapST, unity_DynamicLightmapST);
    output.uv = 0;
    output.uv.xy = TRANSFORM_TEX(input.uv0, _BaseMap);
    #if defined(_ALPHATEST_ON) && defined(_MASKMAP)
        output.uv.zw = TRANSFORM_TEX(input.uv0, _MaskMap);
    #endif
    return output;
}

half4 LuxFragmentMeta(VertexOutputMeta input) : SV_Target
{
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    MetaInput metaInput;
    metaInput.Albedo = brdfData.diffuse + brdfData.specular * brdfData.roughness * 0.5;
    metaInput.SpecularColor = surfaceData.specular;
    metaInput.Emission = surfaceData.emission;

    return MetaFragment(metaInput);
}