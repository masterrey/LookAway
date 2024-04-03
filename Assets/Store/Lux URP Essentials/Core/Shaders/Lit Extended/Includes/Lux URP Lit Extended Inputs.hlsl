#ifndef LIGHTWEIGHT_LIT_INPUT_INCLUDED
#define LIGHTWEIGHT_LIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"


#if defined(_DETAIL_MULX2) || defined(_DETAIL_SCALED)
#define _DETAIL
#endif

// Extended CBUFFER

CBUFFER_START(UnityPerMaterial)
    float4  _BaseMap_ST;
    float4  _DetailAlbedoMap_ST;
    half4   _BaseColor;
    half4   _SpecColor;
    half4   _EmissionColor;
    half    _Cutoff;
    half    _Smoothness;
    half    _Metallic;
    half    _BumpScale;
    half    _Parallax;
    half    _OcclusionStrength;

    half    _DetailAlbedoMapScale;
    half    _DetailNormalMapScale;

    half    _Blend;

    half4   _RimColor;
    half    _RimPower;
    half    _RimMinPower;
    half    _RimFrequency;
    half    _RimPerPositionFrequency;

    half    _ScreenSpaceVariance;
    half    _SAAThreshold;
    half    _GItoAO;
    half    _GItoAOBias;
    half    _HorizonOcclusion;
    float   _CameraFadeDist;
    float   _CameraShadowFadeDist;

    half    _Surface;
CBUFFER_END

TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);

TEXTURE2D(_BentNormalMap);      SAMPLER(sampler_BentNormalMap);


#if defined(_PARALLAX) || defined(_PARALLAXSHADOWS)
    TEXTURE2D(_HeightMap);       SAMPLER(sampler_HeightMap);
#endif

#if defined(_DETAIL)
    TEXTURE2D(_DetailMask);       SAMPLER(sampler_DetailMask);
    TEXTURE2D(_DetailAlbedoMap);  SAMPLER(sampler_DetailAlbedoMap);
    TEXTURE2D(_DetailNormalMap);  SAMPLER(sampler_DetailNormalMap);
#endif    

#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

#if defined(_BESTFITTINGNORMALS_ON)
    TEXTURE2D(_BestFittingNormal); SAMPLER(sampler_BestFittingNormal);
#endif

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
            UNITY_DOTS_INSTANCED_PROP(float , _Surface)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
        #define _Surface                UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Surface)
    #endif

//  Used by shadow caster and depth pass (parallax only)
    struct VertexInput
    {
        float3 positionOS                   : POSITION;
        float3 normalOS                     : NORMAL;
        float4 tangentOS                    : TANGENT;
        float2 texcoord                     : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct VertexOutput
    {
        float4 positionCS                   : SV_POSITION;
        float2 uv                           : TEXCOORD0;
        half3 normalWS                      : TEXCOORD1;
        #if defined(_ALPHATEST_ON)
        //  We have to use the same inputs...
            
            //half4 tangentWS               : TEXCOORD2;
            float screenPos                 : TEXCOORD3; // was float4

        #endif
    //  Here we use viewDirTS!
        half3 viewDirTS                     : TEXCOORD5;

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    struct VertexOutputShadow
    {
        float4 positionCS                   : SV_POSITION;
        float2 uv                           : TEXCOORD0;
        half3 normalWS                      : TEXCOORD1;
        #if defined(_ALPHATEST_ON)
            half4 tangentWS                 : TEXCOORD2;
            float screenPos                 : TEXCOORD3; // was float4
        #endif
    //  Here we use viewDirTS!
        half3 viewDirTS                     : TEXCOORD5;

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };


half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss;

    #ifdef _METALLICSPECGLOSSMAP
        specGloss = SAMPLE_METALLICSPECULAR(uv);
        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            specGloss.a = albedoAlpha * _Smoothness;
        #else
            specGloss.a *= _Smoothness;
        #endif
    #else // _METALLICSPECGLOSSMAP
        #if _SPECULAR_SETUP
            specGloss.rgb = _SpecColor.rgb;
        #else
            specGloss.rgb = _Metallic.rrr;
        #endif

        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            specGloss.a = albedoAlpha * _Smoothness;
        #else
            specGloss.a = _Smoothness;
        #endif
    #endif

    return specGloss;
}

half SampleOcclusion(float2 uv)
{
    #ifdef _OCCLUSIONMAP
    // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
    #if defined(SHADER_API_GLES)
        return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
    #else
        half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
        return LerpWhiteTo(occ, _OcclusionStrength);
    #endif
    #else
        return 1.0;
    #endif
}

half3 SampleNormalExtended(float2 uv, TEXTURE2D_PARAM(bumpMap, sampler_bumpMap), half scale = 1.0h)
{
#if defined (_NORMALMAP) || defined (_BENTNORMAL)
    half4 n = SAMPLE_TEXTURE2D(bumpMap, sampler_bumpMap, uv);
    #if BUMP_SCALE_NOT_SUPPORTED
        return UnpackNormal(n);
    #else
        return UnpackNormalScale(n, scale);
    #endif
#else
    return half3(0.0h, 0.0h, 1.0h);
#endif
}

float Dither17(float2 Pos, float frameIndexMod4) {
    uint3 k0 = uint3(2, 7, 23);
    float Ret = dot( float3(Pos.xy, frameIndexMod4 + 0.5f), k0 / 17.0f);
    return frac(Ret);
}

float Dither32(float2 Pos, float frameIndexMod4) {
    uint3 k0 = uint3(13, 5, 15);
    //float Ret = dot( float3(Pos.xy, frameIndexMod4 + 0.5f), k0 / 32.0f);
    float Ret = dot( float3(Pos.xy, 0.5f), k0 / 32.0f);
    return frac(Ret);
}

float Dither64(float2 Pos, float frameIndexMod4) {
    uint3 k0 = uint3(33, 52, 25);
    //float Ret = dot( float3(Pos.xy, frameIndexMod4 + 0.5f), k0 / 32.0f);
    float Ret = dot( float3(Pos.xy, 1.0f), k0 / 64.0f);
    return frac(Ret);
}

float Dither5(float2 Pos, float frameIndexMod4) {
    float Dither = frac((Pos.x + Pos.y * 2 - 1.5 + frameIndexMod4) / 5 );
    float Noise = frac( dot( float2(171.0f, 231.0f) / 71, Pos.xy) );
    Dither = (Dither * 5 + Noise) * (1.0 / 6.0) - 0.5;
    return Dither;
}

float3 rnmBlendUnpacked(float3 n1, float3 n2) {
    n1 += float3( 0,  0, 1);
    n2 *= float3(-1, -1, 1);
    return n1 * dot(n1, n2) / n1.z - n2;
}

// From URP 13.1.8.
half3 ScaleDetailAlbedo(half3 detailAlbedo, half scale)
{
    // detailAlbedo = detailAlbedo * 2.0h - 1.0h;
    // detailAlbedo *= _DetailAlbedoMapScale;
    // detailAlbedo = detailAlbedo * 0.5h + 0.5h;
    // return detailAlbedo * 2.0f;

    // A bit more optimized
    return half(2.0) * detailAlbedo * scale - scale + half(1.0);
}
half3 ApplyDetailAlbedo(float2 detailUv, half3 albedo, half detailMask)
{
#if defined(_DETAIL)
    half3 detailAlbedo = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUv).rgb;

    // In order to have same performance as builtin, we do scaling only if scale is not 1.0 (Scaled version has 6 additional instructions)
#if defined(_DETAIL_SCALED)
    detailAlbedo = ScaleDetailAlbedo(detailAlbedo, _DetailAlbedoMapScale);
#else
    detailAlbedo = half(2.0) * detailAlbedo;
#endif

    return albedo * LerpWhiteTo(detailAlbedo, detailMask);
#else
    return albedo;
#endif
}
half3 ApplyDetailNormal(float2 detailUv, half3 normalTS, half detailMask)
{
#if defined(_DETAIL)
#if BUMP_SCALE_NOT_SUPPORTED
    half3 detailNormalTS = UnpackNormal(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, detailUv));
#else
    half3 detailNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, detailUv), _DetailNormalMapScale);
#endif

    // With UNITY_NO_DXT5nm unpacked vector is not normalized for BlendNormalRNM
    // For visual consistancy we going to do in all cases
    detailNormalTS = normalize(detailNormalTS);

    return lerp(normalTS, BlendNormalRNM(normalTS, detailNormalTS), detailMask); // todo: detailMask should lerp the angle of the quaternion rotation, not the normals
#else
    return normalTS;
#endif
}
// END

inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

    half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

#if _SPECULAR_SETUP
    outSurfaceData.metallic = 1.0h;
    outSurfaceData.specular = specGloss.rgb;
#else
    outSurfaceData.metallic = specGloss.r;
    outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
#endif

    outSurfaceData.smoothness = specGloss.a;
    outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));

    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#if defined(_UBER)
    inline void InitializeStandardLitSurfaceDataUber(float2 uv, half3 viewDirTS, out SurfaceData outSurfaceData)
    {

        #if defined(_PARALLAX)
        //  Parallax
            float3 v = viewDirTS;
            v.z += 0.42;
            v.xy /= v.z;
            float halfParallax = _Parallax * 0.5f;
            float parallax = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).g * _Parallax - halfParallax;
            float2 offset1 = parallax * v.xy;
        //  Calculate 2nd height
            parallax = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv + offset1).g * _Parallax - halfParallax;
            float2 offset2 = parallax * v.xy;
        //  Final UVs
            uv += (offset1 + offset2) * 0.5f;
        #endif

    //  Default stuff
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

        half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
        outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

        #if _SPECULAR_SETUP
            outSurfaceData.metallic = 1.0h;
            outSurfaceData.specular = specGloss.rgb;
        #else
            outSurfaceData.metallic = specGloss.r;
            outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
        #endif

        outSurfaceData.smoothness = specGloss.a;
        #if defined(_SAMPLENORMAL)
            outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        #else
            outSurfaceData.normalTS = half3(0,0,1);
        #endif
        outSurfaceData.occlusion = SampleOcclusion(uv);
        #if defined (_EMISSION)
            outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
        #else
            outSurfaceData.emission = 0;
        #endif

//  Detail Texturing
        #if defined(_DETAIL)
            half detailMask = SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, uv).a;
            float2 detailUV = uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
            outSurfaceData.albedo = ApplyDetailAlbedo(detailUV, outSurfaceData.albedo, detailMask);
            outSurfaceData.normalTS = ApplyDetailNormal(detailUV, outSurfaceData.normalTS, detailMask);
        #endif

        outSurfaceData.clearCoatMask = 0;
        outSurfaceData.clearCoatSmoothness = 0;
    }
#endif

#endif