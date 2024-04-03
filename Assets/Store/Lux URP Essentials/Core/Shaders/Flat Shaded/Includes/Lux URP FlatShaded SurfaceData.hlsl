#define oneMinusDielectricSpecConst half(1.0 - 0.04)
// derived from #define kDieletricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)

//  Surface function
inline void InitializeSurfaceData(
    float2 uv,
    out SurfaceData outSurfaceData)
{
    #if defined(_ENABLEBASEMAP)
        half4 albedoAlpha = SampleAlbedoAlpha(uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, 1, _Cutoff);
        outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    #else
        outSurfaceData.albedo = _BaseColor.rgb;
        outSurfaceData.alpha = 1;
    #endif
    
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
    outSurfaceData.smoothness = _Smoothness;
    
    #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
        outSurfaceData.smoothness *= albedoAlpha.a;
    #endif

    outSurfaceData.occlusion = 1;

//  Normal Map
    #if defined (_NORMALMAP)
        outSurfaceData.normalTS = SampleNormal(uv.xy, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    #else
        outSurfaceData.normalTS = half3(0.0h, 0.0h, 1.0h);
    #endif

    outSurfaceData.emission = 0.0h;

    outSurfaceData.clearCoatMask = 0.0h;
    outSurfaceData.clearCoatSmoothness = 0.0h;
}