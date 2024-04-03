//  Surface function

inline void InitializeSurfaceData(Varyings input, half2 fadeOcclusion, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
//  Add fade
    albedoAlpha.a *= fadeOcclusion.x;
//  Early out
    outSurfaceData.alpha = Alpha(albedoAlpha.a, 1, _Cutoff);
    
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
//  Normal Map
    #if defined (_NORMALMAP)
        half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
        outSurfaceData.normalTS = UnpackNormalScale(sampleNormal, _BumpScale);
    #else
        outSurfaceData.normalTS = float3(0, 0, 1);
    #endif
    
    outSurfaceData.smoothness = _Smoothness;
    outSurfaceData.occlusion = fadeOcclusion.y;

    #if defined(_SPECMASK)
        half4 sampledSpecMask = SAMPLE_TEXTURE2D(_SpecMask, sampler_SpecMask, input.uv);
        outSurfaceData.occlusion *= lerp(1.0h, sampledSpecMask.g, _OcclusionFromSpecMask);
        outSurfaceData.specular  *= sampledSpecMask.g;
        outSurfaceData.smoothness *= sampledSpecMask.b;
    #endif

    outSurfaceData.emission = 0;
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}