//  Surface function

inline void InitializeSurfaceData(
    Varyings input,
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        float4 screenPos,
        half dither,
    #endif
    out SurfaceData outSurfaceData,
    out AdditionalSurfaceData outAdditionalSurfaceData
)
{
    outSurfaceData = (SurfaceData)0;

#if !defined(DUMMYSHADER)
//  Dither
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        half coverage = 1.0h;
        [branch]
        if (dither < 1.0h) {
            coverage = ComputeAlphaCoverage(screenPos, dither);
        }
        clip(coverage - 0.01h);
    #endif

    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
    outSurfaceData.alpha = 1;
    outSurfaceData.albedo = albedoAlpha.rgb * UNITY_ACCESS_INSTANCED_PROP(Props, _TreeInstanceColor.rgb) * _Color.rgb;

    outSurfaceData.occlusion = 1.0h;
    outSurfaceData.emission = 0.0h;
    outSurfaceData.metallic = 0.0h;

//  Normal
    half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpSpecMap, sampler_BumpSpecMap, input.uv);
    half3 normalTS;
    normalTS.xy = sampleNormal.ag * 2.0h - 1.0h;
    normalTS.z = max(1.0e-16, sqrt(1.0h - saturate(dot(normalTS.xy, normalTS.xy))));
    outSurfaceData.normalTS = normalTS;
    outSurfaceData.specular = _SpecColor.rgb;

//  Mask
    half4 maskSample = SAMPLE_TEXTURE2D(_TranslucencyMap, sampler_TranslucencyMap, input.uv);
    outAdditionalSurfaceData.gloss = maskSample.a * _Color.a;    
    outAdditionalSurfaceData.translucency = maskSample.b;


#else
    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
    outSurfaceData.alpha = 1;
    outSurfaceData.albedo = albedoAlpha.rgb * _Color.rgb;
//  Normal
    outSurfaceData.normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), 1);
    outSurfaceData.specular = _Shininess;
    outSurfaceData.occlusion = 1;
    outSurfaceData.translucency = 0;
//  Transmission
    half4 maskSample = SAMPLE_TEXTURE2D(_TranslucencyMap, sampler_TranslucencyMap, input.uv);
    //outSurfaceData.translucency *= maskSample.b;
    outAdditionalSurfaceData.gloss = maskSample.a;   
#endif

}