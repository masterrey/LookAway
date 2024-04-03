inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    #if (defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO))
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
        albedoAlpha *= _BaseColor;
    #else 
        half4 albedoAlpha = _BaseColor;
    #endif 
    
    #if defined(_ALPHATEST_ON)
        clip (albedoAlpha.a - _Cutoff);
    #endif

    outSurfaceData = (SurfaceData)0;

    outSurfaceData.alpha = 1;
    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
    outSurfaceData.smoothness = _Smoothness;
    outSurfaceData.normalTS = half3(0,0,1);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;
}