#ifdef UNITY_COLORSPACE_GAMMA
    #define Lux_ColorSpaceDouble half4(2.0, 2.0, 2.0, 2.0)
#else
    #define Lux_ColorSpaceDouble half4(4.59479380, 4.59479380, 4.59479380, 2.0)
#endif

half3 LuxLerpWhiteTo(half3 val, half mask)
{
    return lerp( half3(1,1,1), val, mask.xxx);
}
half LuxLerpWhiteTo(half val, half mask)
{
    return lerp( half(1), val, mask);
}

half3 ReorientNormalTS_DT(half3 n1, half3 n2) {
    n1 += half3( 0,  0, 1);
    n2 *= half3(-1, -1, 1);
    return n1 * dot(n1, n2) / max(0.001, n1.z) - n2;
}

void DetailTexturing_half
(
    bool EnableDetailTexturing,

    float2 UV,
    float2 DetailTiling,
    UnityTexture2D DetailTexture,

    half DetailAlbedoScale,
    half DetailNormalScale,
    half DetailSmoothnessScale,

    half3 albedo,
    half3 normalTS,
    half smoothness,

    half  detailMask,

    out half3 o_albedo,
    out half3 o_normalTS,
    out half  o_smoothness
)
{

    o_albedo = albedo;
    o_normalTS = normalTS;
    o_smoothness = smoothness;

    if (EnableDetailTexturing)
    {
        float2 detailUV = UV * DetailTiling;
        half4 detailSample = SAMPLE_TEXTURE2D(DetailTexture, DetailTexture.samplerstate, detailUV);

        half detailAlbedo = detailSample.r;
        half detailSmoothness = detailSample.b;

    //  Albedo
        o_albedo = albedo * LuxLerpWhiteTo(detailAlbedo.rrr * Lux_ColorSpaceDouble.rgb, detailMask * DetailAlbedoScale);                           
    //  Normal
        half3 detailNormal = UnpackNormalAG(detailSample, 1.0);
        o_normalTS = lerp(normalTS, ReorientNormalTS_DT(normalTS, detailNormal), (detailMask * DetailNormalScale).xxx);
    //  Smoothness
        o_smoothness = smoothness * LuxLerpWhiteTo(detailSmoothness * 2.0, detailMask * DetailSmoothnessScale);
    }
}

void DetailTexturing_float
(
    bool EnableDetailTexturing,

    float2 UV,
    float2 DetailTiling,
    UnityTexture2D DetailTexture,

    half DetailAlbedoScale,
    half DetailNormalScale,
    half DetailSmoothnessScale,

    half3 albedo,
    half3 normalTS,
    half3 smoothness,

    half detailMask,

    out half3 o_albedo,
    out half3 o_normalTS,
    out half  o_smoothness
)
{
    DetailTexturing_half
    (
        EnableDetailTexturing,
        UV, DetailTiling, DetailTexture,
        DetailAlbedoScale, DetailNormalScale, DetailSmoothnessScale,
        albedo, normalTS, smoothness,
        detailMask,
        o_albedo, o_normalTS, o_smoothness
    );
}