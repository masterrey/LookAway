#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    #include "../Includes/Lux URP Blend Lighting.hlsl"
 
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)

        float3  _TerrainPos;
        float3  _TerrainSize;
        float4  _TerrainHeightNormal_TexelSize;

        float   _Shift;

        half    _AlphaShift;
        half    _AlphaWidth;
        float   _ShadowShiftThreshold;
        float   _ShadowShift;
        float   _ShadowShiftView;
        half    _NormalShift;
        half    _NormalWidth;
        half    _NormalThreshold;
        half    _BumpScale;

        half4   _BaseColor;
        half    _Cutoff;
        float4  _BaseMap_ST;
        half    _Smoothness;
        half4   _SpecColor;

        half    _RenderInDeferred;
        float   _BlendThresholdVertex;
        float   _BlendThresholdPixel;
        

        half    _ApplyMask;
        half    _OcclusionStrength;

        half    _ApplyDetailTexture;
        float4  _DetailMap_ST;
        half    _DetailAlbedoStrength;
        half    _DetailNormalStrength;
        half    _DetailSmoothnessStrength;
        
    CBUFFER_END

//  Additional textures
    //TEXTURE2D(_TopDownBaseMap); SAMPLER(sampler_TopDownBaseMap);
    //TEXTURE2D(_TopDownNormalMap); SAMPLER(sampler_TopDownNormalMap);

    TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
    TEXTURE2D(_DetailMap); SAMPLER(sampler_DetailMap);
    
    TEXTURE2D_FLOAT(_TerrainHeightNormal); SAMPLER(sampler_TerrainHeightNormal);
    SAMPLER(lux_linear_clamp_sampler);


//  Global Inputs

//  Structs
#if !defined(METAPASS) // meta pass declares these structs already
    struct Attributes
    {
        float3 positionOS                   : POSITION;
        float3 normalOS                     : NORMAL;
        float4 tangentOS                    : TANGENT;
        float2 texcoord                     : TEXCOORD0;
        float2 staticLightmapUV             : TEXCOORD1;
        float2 dynamicLightmapUV            : TEXCOORD2;
        half4 color                         : COLOR;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS                   : SV_POSITION;
        float2 uv                           : TEXCOORD0;

        #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(DEPTHONLYPASS)
            //#ifdef _ADDITIONAL_LIGHTS
                float3 positionWS           : TEXCOORD1;
            //#endif
            float3 normalWS                 : TEXCOORD2;
            #if defined(_NORMALMAP)
                half4 tangentWS             : TEXCOORD3;
            #endif
            half4 fogFactorAndVertexLight   : TEXCOORD5;
            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord          : TEXCOORD6;
            #endif

            DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);

            #ifdef DYNAMICLIGHTMAP_ON
                float2  dynamicLightmapUV : TEXCOORD9; // Dynamic lightmap UVs
            #endif

        #endif

        #ifdef USE_APV_PROBE_OCCLUSION
            float4 probeOcclusion           : TEXCOORD10;
        #endif

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };
#endif

    struct SurfaceDescription
    {
        half3 albedo;
        half alpha;
        half3 normalTS;
        half3 emission;
        half metallic;
        half3 specular;
        half smoothness;
        half occlusion;
    };

//  ///////////////////////////////////////////
//  Shared fragment functions

#ifdef UNITY_COLORSPACE_GAMMA
    #define Lux_ColorSpaceDouble half4(2.0, 2.0, 2.0, 2.0)
#else
    #define Lux_ColorSpaceDouble half4(4.59479380, 4.59479380, 4.59479380, 2.0)
#endif

half3 LuxLerpWhiteTo(half3 val, half mask)
{
    return lerp( half3(1,1,1), val, mask.xxx);
}
half LuxLerpWhiteTo(half val, half mask)
{
    return lerp( half(1), val, mask.xxx);
}

half3 ReorientNormalTS_DT(half3 n1, half3 n2) {
    n1 += half3( 0,  0, 1);
    n2 *= half3(-1, -1, 1);
    return n1 * dot(n1, n2) / max(0.001, n1.z) - n2;
}


inline void InitializeSurfaceData(
float2 uv,
out SurfaceData outSurfaceData)
{
    half4 albedoSmoothness = SampleAlbedoAlpha(uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.albedo = albedoSmoothness.rgb * _BaseColor.rgb;

    outSurfaceData.metallic = 0;
    outSurfaceData.specular = _SpecColor.rgb;
    
    outSurfaceData.smoothness = albedoSmoothness.a;
    outSurfaceData.occlusion = 1;

//  Normal Map
    #if defined (_NORMALMAP)
        outSurfaceData.normalTS = SampleNormal(uv.xy, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    #else
        outSurfaceData.normalTS = half3(0,0,1);
    #endif

    half detailMask = 1.0;

    if (_ApplyMask)
    {
        half4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, uv.xy);
        outSurfaceData.smoothness = maskSample.a;
        outSurfaceData.occlusion = lerp(1.0, maskSample.g, _OcclusionStrength);
        detailMask = maskSample.b; 
    }
    outSurfaceData.smoothness *= _Smoothness;

    if (_ApplyDetailTexture)
    {
        float2 detailUV = uv.xy * _DetailMap_ST.xy + _DetailMap_ST.zw; 
        half4 detailSample = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, detailUV);
        half detailAlbedo = detailSample.r;
        half detailSmoothness = detailSample.b;
    //  Albedo
        outSurfaceData.albedo = outSurfaceData.albedo * LuxLerpWhiteTo(detailAlbedo * Lux_ColorSpaceDouble.rgb, (detailMask * _DetailAlbedoStrength).xxx );                           
    //  Normal
        half3 detailNormal = UnpackNormalAG(detailSample, 1.0);
        outSurfaceData.normalTS = lerp(outSurfaceData.normalTS, ReorientNormalTS_DT(outSurfaceData.normalTS, detailNormal), (detailMask * _DetailNormalStrength).xxx);
    //  Smoothness
        outSurfaceData.smoothness = outSurfaceData.smoothness * LuxLerpWhiteTo(detailSmoothness * 2.0, detailMask * _DetailSmoothnessStrength);
    }

    outSurfaceData.emission = 0;
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
    outSurfaceData.alpha = 1;
}



#endif