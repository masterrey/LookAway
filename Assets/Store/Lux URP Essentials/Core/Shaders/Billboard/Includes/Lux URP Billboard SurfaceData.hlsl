//  Surface function

inline void InitializeSurfaceData(
    Varyings input,
    out SurfaceData outSurfaceData
)
{
    outSurfaceData = (SurfaceData)0;
    outSurfaceData.occlusion = 1;
    outSurfaceData.alpha = 1;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
    outSurfaceData.smoothness = _Smoothness;

    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    half alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
    albedoAlpha.rgb *= _BaseColor.rgb;

    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.alpha = alpha;

//  Normal Map
    #if defined (_NORMALMAP)
        outSurfaceData.normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    #else
        outSurfaceData.normalTS = half3(0,0,1);
    #endif
}