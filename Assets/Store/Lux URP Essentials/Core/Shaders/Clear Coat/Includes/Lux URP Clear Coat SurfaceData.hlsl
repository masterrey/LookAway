//  Surface function

inline void InitializeSurfaceData(
    Varyings input,
    out SurfaceData outSurfaceData
)
{
    outSurfaceData = (SurfaceData)0;
    outSurfaceData.occlusion = 1;
    outSurfaceData.alpha = 1;
    outSurfaceData.metallic = _Metallic;
    outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
    outSurfaceData.smoothness = _Smoothness;

//  BaseMap
    #if defined (_BASECOLORMAP)
        float2 albedoUV = TRANSFORM_TEX(input.uv, _BaseMap);
        outSurfaceData.albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, albedoUV).rgb;
    #else 
        outSurfaceData.albedo = 1;
    #endif

//  Normal Map
    #if defined (_NORMALMAP)
        float2 normalUV = TRANSFORM_TEX(input.uv, _BumpMap);
        outSurfaceData.normalTS = SampleNormal(normalUV, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    #else
        outSurfaceData.normalTS = half3(0,0,1);
    #endif

//  Secondary Mask
    #if defined(_MASKMAPSECONDARY)
        float2 secondaryMaskUV = TRANSFORM_TEX(input.uv, _SecondaryMask);
        half4 secondaryMaskSample = SAMPLE_TEXTURE2D(_SecondaryMask, sampler_SecondaryMask, secondaryMaskUV);
        outSurfaceData.metallic *= secondaryMaskSample.r;
        outSurfaceData.occlusion = lerp(1, secondaryMaskSample.g, _Occlusion);
        outSurfaceData.smoothness *= secondaryMaskSample.a;
    #endif

//  Coat
    outSurfaceData.clearCoatSmoothness = _ClearCoatSmoothness;
    outSurfaceData.clearCoatMask = _ClearCoatThickness;

    #if defined(_MASKMAP)
        half4 maskSample = SAMPLE_TEXTURE2D(_CoatMask, sampler_CoatMask, input.uv.zw);
        outSurfaceData.clearCoatSmoothness *= maskSample.a;
        outSurfaceData.clearCoatMask *= maskSample.g;
    #endif
}