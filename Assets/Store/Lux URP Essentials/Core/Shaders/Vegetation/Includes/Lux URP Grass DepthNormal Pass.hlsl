#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs
struct Attributes
{
    float3 positionOS                   : POSITION;
    float3 normalOS                     : NORMAL;
    #if defined(_ALPHATEST_ON) || defined(_NORMALMAP)
        float2 texcoord                 : TEXCOORD0;
    #endif
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        float4 tangentOS                : TANGENT;
    #endif
    half4 color                         : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS                   : SV_POSITION;
    float3 normalWS                     : TEXCOORD0;
    #if defined(_ALPHATEST_ON) || defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        float2 uv                       : TEXCOORD1;
    #endif
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        half4 tangentWS                 : TEXCOORD2;
    #endif
    //#if defined(_NORMALINDEPTHNORMALPASS)
        float3 positionWS               : TEXCOORD3;
    //#endif
    #if defined(_ALPHATEST_ON)
        half2 fadeOcclusion             : TEXCOORD4;
    #endif
    //UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float3 positionWS;
    half3 normalWS;
    half2 fadeOcclusion;
    BendGrass(
        input.positionOS,
        input.normalOS,
        input.color,
        positionWS,
        normalWS,
        fadeOcclusion
    );

    #if defined(_ALPHATEST_ON) || defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        output.uv = input.texcoord;
    #endif 
    #if defined(_ALPHATEST_ON)
        output.fadeOcclusion = fadeOcclusion;
    #endif
    output.normalWS = normalWS;
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        half3 tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
    //  Adjust tangentWS as we have tweaked normalWS
        tangentWS.xyz = Orthonormalize(tangentWS.xyz, normalWS.xyz);
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(tangentWS.xyz, sign);
    #endif

    output.positionCS = TransformWorldToHClip(positionWS);

    output.positionWS = positionWS;

    return output;
}

//half4 DepthNormalsFragment(Varyings input) : SV_TARGET
//{
void DepthNormalsFragment(
    Varyings input
    , out half4 outNormalWS : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    //UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON)
        Alpha(SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a * input.fadeOcclusion.x, /*_BaseColor*/ half4(1,1,1,1), _Cutoff);
    #endif

//  input.normalWS = cross(ddy(input.positionWS), ddx(input.positionWS));
//  float3 normal = input.normalWS;
//     normal = TransformWorldToViewDir(normal, true);
// //  Make the normal face the camera!
//     normal.z = abs(normal.z);
//     return float4(PackNormalOctRectEncode(normal), 0.0, 0.0);

    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
        half3 normalTS = UnpackNormalScale(sampleNormal, _BumpScale);
        float sgn = input.tangentWS.w;
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        input.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    #endif

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        outNormalWS =  half4(packedNormalWS, 0.0);
    #else
        float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
        outNormalWS =  half4(normalWS, 0.0);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}