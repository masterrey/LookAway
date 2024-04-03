#define oneMinusDielectricSpecConst half(1.0 - 0.04)
// derived from #define kDieletricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)

//  Surface function
inline void InitializeSurfaceData(
    float2 uv,
    out SurfaceData outSurfaceData,
    out AdditionalSurfaceData outAdditionalSurfaceData
)
{
    outSurfaceData = (SurfaceData)0;

//  Early alpha testing
    #if defined(_MASKMAP)
        half4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, uv);
        #if defined(_ALPHATEST_ON)
            outSurfaceData.alpha = Alpha(maskSample.a, 1, _Cutoff);
        #else
        outSurfaceData.alpha = 1;
        #endif
    #else
        outSurfaceData.alpha = 1;
    #endif

    half4 albedoSmoothness = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));

    #if defined(_MASKMAP)
        outAdditionalSurfaceData.fuzzMask = maskSample.r;
        outAdditionalSurfaceData.translucency = maskSample.g;
        outSurfaceData.occlusion = lerp(1.0h, maskSample.b, _OcclusionStrength);
    #else
        outAdditionalSurfaceData.fuzzMask = 1;
        outAdditionalSurfaceData.translucency = 1;
        outSurfaceData.occlusion = 1;
    #endif 

    outSurfaceData.albedo = albedoSmoothness.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor;
    outSurfaceData.smoothness = albedoSmoothness.a * _Smoothness;

//  Normal Map
    #if defined (_NORMALMAP)
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    #else
        outSurfaceData.normalTS = half3(0,0,1);
    #endif

    outSurfaceData.emission = 0;
}