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
    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
//  Dither
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        half coverage = 1.0h;
        [branch]
        if (dither < 1.0h) {
            coverage = ComputeAlphaCoverage(screenPos, dither);
        }
        albedoAlpha.a *= coverage;
    #endif
//  Early out
    outSurfaceData.alpha = Alpha(albedoAlpha.a, half4(1,1,1,1), _Cutoff);
    outSurfaceData.albedo = albedoAlpha.rgb * UNITY_ACCESS_INSTANCED_PROP(Props, _TreeInstanceColor.rgb) * _Color.rgb;

    outSurfaceData.occlusion = input.ambient;
    outSurfaceData.emission = 0.0h;
    outSurfaceData.metallic = 0.0h;

//  Normal
    half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpSpecMap, sampler_BumpSpecMap, input.uv);
    half3 normalTS;
    normalTS.xy = sampleNormal.ag * 2.0h - 1.0h;
    normalTS.xy *= UNITY_ACCESS_INSTANCED_PROP(Props, _SquashAmount);
    normalTS.z = max(1.0e-16, sqrt(1.0h - saturate(dot(normalTS.xy, normalTS.xy))));
    outSurfaceData.normalTS = normalTS;
    outSurfaceData.specular = sampleNormal.rrr;

//  Transmission
    half4 maskSample = SAMPLE_TEXTURE2D(_TranslucencyMap, sampler_TranslucencyMap, input.uv);
    outAdditionalSurfaceData.gloss = maskSample.a * _Color.a;    
    outAdditionalSurfaceData.translucency = maskSample.b;

#else
    half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
//  Early out
    outSurfaceData.alpha = Alpha(albedoAlpha.a, half4(1,1,1,1), _Cutoff);
    outSurfaceData.albedo = albedoAlpha.rgb * _Color.rgb;

//  Normal
    outSurfaceData.normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), 1);
    outSurfaceData.specular = _Shininess;
    outSurfaceData.occlusion = 1;

//  Transmission
    half4 maskSample = SAMPLE_TEXTURE2D(_TranslucencyMap, sampler_TranslucencyMap, input.uv);
    outAdditionalSurfaceData.translucency = maskSample.b;
//  Gloss
    outAdditionalSurfaceData.gloss = SAMPLE_TEXTURE2D(_GlossMap, sampler_GlossMap, input.uv).a;

#endif

}