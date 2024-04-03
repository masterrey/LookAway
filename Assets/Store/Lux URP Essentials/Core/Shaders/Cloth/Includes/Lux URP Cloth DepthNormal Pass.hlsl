#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs
struct Attributes
{
    float3 positionOS                   : POSITION;
    float3 normalOS                     : NORMAL;
    float4 tangentOS                    : TANGENT;
    float2 texcoord                     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS                   : SV_POSITION;
    #if defined(_MASKMAP)
        float4 uv                       : TEXCOORD0;
    #else
        float2 uv                       : TEXCOORD0;
    #endif
    half3 normalWS                      : TEXCOORD1;
    #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        half4 tangentWS                 : TEXCOORD2;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthNormalVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    #if defined(_ALPHATEST_ON) && defined(_MASKMAP) || defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        output.uv = 0;
    #endif
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
    #endif
    #if defined(_ALPHATEST_ON) && defined(_MASKMAP)
        output.uv.zw = TRANSFORM_TEX(input.texcoord, _MaskMap);
    #endif
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    #else
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
    #endif 
    output.normalWS = normalInput.normalWS;
    #if defined (_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif

    return output;
}

//half4 DepthNormalFragment(Varyings input, half facing : VFACE) : SV_TARGET
//{
void DepthNormalFragment(
    Varyings input, half facing : VFACE
    , out half4 outNormalWS : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON) && defined(_MASKMAP)
        half mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv.zw).a;
        clip (mask - _Cutoff);
    #endif

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        outNormalWS = half4(packedNormalWS, 0.0);
    #else
        #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
            half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.xy);
            half3 normalTS = UnpackNormalScale(sampleNormal, _BumpScale);
            normalTS.z *= facing;
            float sgn = input.tangentWS.w;
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            input.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
        #else
            input.normalWS *= facing;
        #endif
        float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
        outNormalWS = half4(normalWS, 0.0);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}