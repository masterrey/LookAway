#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

//  Structs
struct Attributes
{
    float4 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    float2 uv               : TEXCOORD0;
    float2 uv1              : TEXCOORD1;
    float2 uv2              : TEXCOORD2;
    #ifdef _TANGENT_TO_WORLD
        float4 tangentOS    : TANGENT;
    #endif
    #if defined(_USEVERTEXCOLORS)
        half4 color         : COLOR;
    #endif
};

struct Varyings
{
    float4 positionCS       : SV_POSITION;
    float2 uv               : TEXCOORD0;
    float3 positionWS       : TEXCOORD1;

    #if defined(_USEVERTEXCOLORS)
        half4 color         : COLOR;
    #endif
};

// Include the surface function
// #include "Includes/Lux URP MeshTerrain SurfaceData.hlsl"

//  As we may not use _TOPDOWNPROJECTION
inline void InitializeStandardLitSurfaceData(Varyings input, out SurfaceData outSurfaceData, out half3 topdownNormal)
{
    
    topdownNormal = 0;

    float2 detailUV = input.uv * _SplatTiling;
    half4 splatControl = 0;
    half4 albedoAlpha = 0;

    #if defined(_USEVERTEXCOLORS)
        splatControl = input.color;
    #else
        splatControl.rgb = SAMPLE_TEXTURE2D(_SplatMap, sampler_SplatMap, input.uv.xy).rgb;
    #endif
    splatControl.a = 1.0h - splatControl.r - splatControl.g - splatControl.b;

//  As we may not use _TOPDOWNPROJECTION   
    if(_ApplyTopDownProjection) {
        float2 uvWS = input.positionWS.xz * _TopDownTiling;
        albedoAlpha = SAMPLE_TEXTURE2D(_DetailA0, sampler_DetailA0, uvWS) * splatControl.r;
    }
    else {
        albedoAlpha = SAMPLE_TEXTURE2D(_DetailA0, sampler_DetailA0, detailUV) * splatControl.r;
    }
    
    albedoAlpha += SAMPLE_TEXTURE2D(_DetailA1, sampler_DetailA0, detailUV) * splatControl.g;
    albedoAlpha += SAMPLE_TEXTURE2D(_DetailA2, sampler_DetailA0, detailUV) * splatControl.b;
    albedoAlpha += SAMPLE_TEXTURE2D(_DetailA3, sampler_DetailA0, detailUV) * splatControl.a;

    half3 normalTS = 0;

    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.smoothness = albedoAlpha.a; 
    outSurfaceData.normalTS = normalTS;
    outSurfaceData.emission = 0;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
    outSurfaceData.occlusion = 1.0h - _Occlusion;
    outSurfaceData.alpha = 1;

    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}


Varyings LuxVertexMeta(Attributes input)
{
    Varyings output;
    output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2, unity_LightmapST, unity_DynamicLightmapST);

    output.uv = input.uv;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionWS = vertexInput.positionWS;

    #if defined(_USEVERTEXCOLORS)
        output.color = input.color;
    #endif

    return output;
}

half4 LuxFragmentMeta(Varyings input) : SV_Target
{
    half3 topdownNormal;

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input, surfaceData, topdownNormal);

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    MetaInput metaInput;
    metaInput.Albedo = brdfData.diffuse + brdfData.specular * brdfData.roughness * 0.5;
    //metaInput.SpecularColor = surfaceData.specular;
    metaInput.Emission = surfaceData.emission;

    return MetaFragment(metaInput);
}