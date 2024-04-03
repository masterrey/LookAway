//  Surface function

inline void InitializeSurfaceData(
    Varyings input,
    out SurfaceData outSurfaceData,
    out AdditionalSurfaceData outAdditionalSurfaceData
)
{
    outSurfaceData = (SurfaceData)0;

    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
//  Add fade
    #if defined(_ALPHATEST_ON)
        albedoAlpha.a *= input.fade;
    #endif
//  Early out
    outSurfaceData.alpha = Alpha(albedoAlpha.a, 1.0h, _Cutoff);

    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = 0.0h;
    outSurfaceData.specular = _SpecColor.rgb;

//  Normal Map
    #if defined (_NORMALMAP)
        half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpSpecMap, sampler_BumpSpecMap, input.uv);
        half3 normalTS;
        normalTS.xy = sampleNormal.ag * 2.0h - 1.0h;
        normalTS.z = max(1.0e-16, sqrt(1.0h - saturate(dot(normalTS.xy, normalTS.xy))));
        // must scale after reconstruction of normal.z which also
        // mirrors UnpackNormalRGB(). This does imply normal is not returned
        // as a unit length vector but doesn't need it since it will get normalized after TBN transformation.
        normalTS.xy *= _BumpScale;

        outSurfaceData.normalTS = normalTS;
        outSurfaceData.smoothness = sampleNormal.b * _GlossMapScale;
        outAdditionalSurfaceData.translucency = sampleNormal.r;
    #else
        outSurfaceData.normalTS = half3(0.0h, 0.0h, 1.0h);
        outSurfaceData.smoothness = _Smoothness;
        outAdditionalSurfaceData.translucency = 1.0h;
    #endif
    outSurfaceData.occlusion = 1.0h;
    outSurfaceData.emission = 0.0h;
}