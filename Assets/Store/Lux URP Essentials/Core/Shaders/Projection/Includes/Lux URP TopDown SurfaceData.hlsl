#define oneMinusDielectricSpecConst half(1.0 - 0.04)
// derived from #define kDieletricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)

//  Surface function
inline void InitializeStandardLitSurfaceData(
    Varyings input,
    out SurfaceData outSurfaceData,
    out AdditionalSurfaceData outAdditionalSurfaceData
)
{
    outSurfaceData = (SurfaceData)0;

    half4 albedoAlpha = SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)) * _BaseColor;
    albedoAlpha.a *= _GlossMapScale;

    outSurfaceData.alpha = 1;
    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.occlusion = 1;

    outAdditionalSurfaceData.fuzzMask = 0;

    #if defined(_SPECULAR_SETUP)
        outSurfaceData.specular = _SpecColor.rgb;
    #else
        outSurfaceData.specular = 0;
    #endif

    #if defined(_COMBINEDTEXTURE)
        half4 combinedTextureSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv.xy);
        outSurfaceData.specular = lerp(_SpecColor.rgb, albedoAlpha.rgb, combinedTextureSample.rrr);
    //  Remap albedo
        albedoAlpha.rgb *= oneMinusDielectricSpecConst - combinedTextureSample.rrr * oneMinusDielectricSpecConst;
        outSurfaceData.emission = _EmissionColor.rgb * combinedTextureSample.a;
        outSurfaceData.occlusion = lerp(1.0h, combinedTextureSample.g, _Occlusion);
    #endif
    
    outSurfaceData.smoothness = albedoAlpha.a * _GlossMapScale;
    outSurfaceData.normalTS = SampleNormal(input.uv.xy, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);

    #ifdef _NORMALMAP
        #if defined (_MASKFROMNORMAL)
            half4 packedNormal = SAMPLE_TEXTURE2D(_TopDownNormalMap, sampler_TopDownNormalMap, input.uv.zw);
            #if BUMP_SCALE_NOT_SUPPORTED
                half3 topDownNormal = UnpackNormalmapRGorAG(packedNormal, 1.0);
            #else
                half3 topDownNormal = UnpackNormalmapRGorAG(packedNormal, _BumpScaleDyn);
            #endif
        #else
            half3 topDownNormal = SampleNormal(input.uv.zw, TEXTURE2D_ARGS(_TopDownNormalMap, sampler_TopDownNormalMap), _BumpScaleDyn);
        #endif
    #endif

//  Please note: outSurfaceData.normalTS will actually contain a normal in world space!
    #if defined(_TOPDOWNPROJECTION)
        half blendFactor = 0.0h;
        #ifdef _NORMALMAP
        //  Get per pixel worldspace normal (needed by blending)
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            half3 normalWS = TransformTangentToWorld(outSurfaceData.normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
            blendFactor = lerp(input.normalWS.y, normalWS.y, _LowerNormalInfluence);
        #else
            blendFactor = input.normalWS.y;
        #endif
    //  Prevent projected texture from gettings stretched by masking out steep faces
        //blendFactor = saturate( blendFactor - (1 - saturate ( (blendFactor - _NormalLimit) * 4 ) ) );
        blendFactor = lerp(-_NormalLimit, 1.0h, saturate(blendFactor));
    //  Widen blendfactor
        blendFactor = blendFactor * _NormalFactor;
        #if defined(_COMBINEDTEXTURE) || defined (_NORMALMAP) && defined (_MASKFROMNORMAL)
            #if defined (_NORMALMAP) && defined (_MASKFROMNORMAL)
                half mask = saturate(packedNormal.b * _HeightBlendSharpness);
            #else
            //  Mask is height and we want less on high levels. So it is some kind of inverted.
                half mask = saturate(combinedTextureSample.b * _HeightBlendSharpness);   
            #endif
            blendFactor = smoothstep(mask, 1.0h, blendFactor); 
        #else
        //  Somehow compensate missing height sample, smoothstep is not compensated? Nope. Just saturate.
            blendFactor = saturate(blendFactor); // * (1 + _HeightBlendSharpness));
        #endif
        float normalBlendFactor = blendFactor;
        blendFactor *= blendFactor * blendFactor * blendFactor;

        outAdditionalSurfaceData.fuzzMask = blendFactor;

    //  Get top down projected Texture(s)
        //float2 topDownUV = input.positionWS.xz * _TopDownTiling + _TerrainPosition.xz;
        half4 topDownSample = SAMPLE_TEXTURE2D(_TopDownBaseMap, sampler_TopDownBaseMap, input.uv.zw);
        topDownSample.a *= _GlossMapScaleDyn;
        albedoAlpha = lerp(albedoAlpha, topDownSample, blendFactor.xxxx);

        outSurfaceData.emission = lerp(outSurfaceData.emission, half3(0.0h, 0.0h, 0.0h), blendFactor.xxx);
        outSurfaceData.occlusion = lerp(outSurfaceData.occlusion, 1, blendFactor);

        #ifdef _NORMALMAP
        //  1. Normal is not sampled in tangent space   
            outSurfaceData.normalTS = normalWS;
        //  2. So we use Reoriented Normal Mapping to bring the top down normal into world space
        //  See e.g.: https://medium.com/@bgolus/normal-mapping-for-a-triplanar-shader-10bf39dca05a
        //  We must apply some crazy swizzling here: Swizzle world space to tangent space
            half3 n1 = input.normalWS.xzy;
            half3 n2 = topDownNormal.xyz;
            n1.z += 1.0h;
            n2.xy *= -1.0h;
            topDownNormal = n1 * dot(n1, n2) / n1.z - n2;
        //  Swizzle tangent space to world space
            topDownNormal = topDownNormal.xzy;
        //  3. Finally we blend both normals in world space 
            outSurfaceData.normalTS = lerp(outSurfaceData.normalTS, topDownNormal, saturate(normalBlendFactor - _LowerNormalMinStrength).xxx );
        #endif
    #else
        #ifdef _NORMALMAP
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            outSurfaceData.normalTS = TransformTangentToWorld(outSurfaceData.normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
        #else
            outSurfaceData.normalTS = input.normalWS.xyz;
        #endif
    #endif

    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.smoothness = albedoAlpha.a;
}