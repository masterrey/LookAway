//  Surface function

inline void InitializeSurfaceData(
    Varyings input,
    out SurfaceData outSurfaceData,
    out AdditionalSurfaceData outAdditionalSurfaceData
)
{
    outSurfaceData = (SurfaceData)0;

    half4 albedoAlpha = SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
//  Early out
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = 0.0h;
    outSurfaceData.specular = _SpecColor.rgb;
    outSurfaceData.smoothness = _Smoothness;
    outSurfaceData.occlusion = 1;

//  Normal Map
    #if defined (_NORMALMAP)
        half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.xy);
        half3 normalTS;
        normalTS.xy = sampleNormal.ag * 2.0h - 1.0h;
        normalTS.z = max(1.0e-16, sqrt(1.0h - saturate(dot(normalTS.xy, normalTS.xy))));
        // must scale after reconstruction of normal.z which also
        // mirrors UnpackNormalRGB(). This does imply normal is not returned
        // as a unit length vector but doesn't need it since it will get normalized after TBN transformation.
        normalTS.xy *= _BumpScale;

        outSurfaceData.normalTS = normalTS;
    #else
        outSurfaceData.normalTS = half3(0.0h, 0.0h, 1.0h);
    #endif

    outAdditionalSurfaceData.translucency = _TranslucencyStrength;
    outAdditionalSurfaceData.mask = 1;

//  Transmission
    #if defined(_MASKMAP)
        half4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv.zw);
        outAdditionalSurfaceData.translucency *= maskSample.g;
        outSurfaceData.occlusion = lerp(1.0h, maskSample.b, _Occlusion);
        outAdditionalSurfaceData.mask = maskSample.r;
        outSurfaceData.smoothness *= maskSample.a;
    #endif
}