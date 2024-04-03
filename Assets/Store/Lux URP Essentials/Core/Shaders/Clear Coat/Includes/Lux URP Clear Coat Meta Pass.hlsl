inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    outSurfaceData = (SurfaceData)0;
    
    outSurfaceData.albedo = _BaseColor.rgb;
    #if defined (_BASECOLORMAP)
        float2 albedoUV = TRANSFORM_TEX( (uv - _BaseMap_ST.zw) / _BaseMap_ST.xy, _BaseMap);
        outSurfaceData.albedo *= SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, albedoUV).rgb;
    #endif

    outSurfaceData.alpha = 1;
    outSurfaceData.metallic = _Metallic;
    outSurfaceData.specular = 0;
    outSurfaceData.smoothness = _Smoothness;
    outSurfaceData.normalTS = half3(0,0,1);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;
}