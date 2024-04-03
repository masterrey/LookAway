inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    #if defined(_ALPHATEST_ON)
        clip (albedoAlpha.a * _BaseColor.a - _Cutoff);
    #endif

    outSurfaceData = (SurfaceData)0;

    outSurfaceData.alpha = 1;
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
    outSurfaceData.smoothness = _Smoothness;
    outSurfaceData.normalTS = half3(0,0,1);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;
}