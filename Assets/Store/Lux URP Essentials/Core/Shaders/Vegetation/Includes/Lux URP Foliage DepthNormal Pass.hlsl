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
        half fade                       : TEXCOORD4;
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

//  Set distance fade value
    float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
    float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
    float dist = dot(diff, diff);
    float fade = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );

//  Shrink mesh if alpha testing is disabled
    #if !defined(_ALPHATEST_ON)
        input.positionOS.xyz *= fade;
    #endif

    #if defined(_ALPHATEST_ON) || defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        output.uv = input.texcoord;
    #endif 
    #if defined(_ALPHATEST_ON)
        output.fade = fade;
    #endif

//  Wind in Object Space -------------------------------
    animateVertex(input.color, input.normalOS.xyz, input.positionOS.xyz);
//  End Wind -------------------------------

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    #else 
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
    #endif

    output.normalWS = normalInput.normalWS;
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
        output.tangentWS = tangentWS;
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

//half4 DepthNormalsFragment(Varyings input, half facing : VFACE) : SV_TARGET
//{
void DepthNormalsFragment(
    Varyings input, half facing : VFACE
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
        Alpha(SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a * input.fade, half4(1,1,1,1), _Cutoff);
    #endif

    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpSpecMap, sampler_BumpSpecMap, input.uv);
        half3 normalTS = UnpackNormalAG(sampleNormal, _BumpScale);
        normalTS.z *= facing;

        float sgn = input.tangentWS.w;
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        input.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    #else
        input.normalWS *= facing;
    #endif

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        outNormalWS = half4(packedNormalWS, 0.0);
    #else
        float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
        outNormalWS = half4(normalWS, 0.0);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}