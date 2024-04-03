//  Surface function

inline void InitializeSurfaceData(
    float2 uv,
    out SurfaceData outSurfaceData,
    out AdditionalSurfaceData outAdditionalSurfaceData)
{
//  Quiet the compiler
    outSurfaceData = (SurfaceData)0;

    #if defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO)
        half4 albedoAlpha = SampleAlbedoAlpha(uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
        albedoAlpha *= _BaseColor;
    #else
        half4 albedoAlpha = _BaseColor;
    #endif
    
    #if defined(_ALPHATEST_ON) && (defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO))
        outSurfaceData.alpha = Alpha(albedoAlpha.a, 1, _Cutoff);
    #else
        outSurfaceData.alpha = albedoAlpha.a;
    #endif

    #if defined(_TEXMODE_TWO)
        half3 albedoShaded = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_ShadedBaseMap, sampler_BaseMap)).rgb;
    #else
        #if defined(_TEXMODE_ONE)
            half3 albedoShaded = albedoAlpha.rgb;
        #else
            half3 albedoShaded = half3(1,1,1);
        #endif
    #endif

    #if defined(_MASKMAP)
        half4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, uv);
        outSurfaceData.occlusion = lerp(1.0h, maskSample.b, _OcclusionStrength);
        outSurfaceData.smoothness = maskSample.a * _Smoothness;
        outSurfaceData.specular = lerp(_SpecColor2nd, _SpecColor, maskSample.g);
        outSurfaceData.emission = maskSample.r * _EmissionColor;
    #else
        outSurfaceData.occlusion = _OcclusionStrength;
        outSurfaceData.smoothness = _Smoothness;
        outSurfaceData.specular = _SpecColor.rgb;
        outSurfaceData.emission = 0;
    #endif 

    outSurfaceData.albedo = albedoAlpha.rgb;
    outAdditionalSurfaceData.albedoShaded = albedoShaded * _ShadedBaseColor.rgb;
    outSurfaceData.metallic = 0;
    
//  Normal Map
    #if defined (_NORMALMAP)
        outSurfaceData.normalTS = SampleNormal(uv.xy, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    #else
        outSurfaceData.normalTS = half3(0,0,1);
    #endif
}