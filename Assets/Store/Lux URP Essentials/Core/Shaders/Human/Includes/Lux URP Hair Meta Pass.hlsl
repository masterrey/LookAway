//  Fragment function

inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, half4(1.0h, 1.0h, 1.0h, 1.0h), _Cutoff);
    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
    outSurfaceData.smoothness = _Smoothness;
    outSurfaceData.normalTS = half3(0,0,1);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;

    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}