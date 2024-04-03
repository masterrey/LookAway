#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float3 positionOS               : POSITION;
    float3 normalOS                 : NORMAL;
    float4 tangentOS                : TANGENT;
    float2 uv                       : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS               : SV_POSITION;
    #if defined(_ALPHATEST_ON) && defined(_MASKMAP) || defined(_NORMALINDEPTHNORMALPASS)
        float2 uv                   : TEXCOORD0;
    #endif
    float3 normalWS                 : TEXCOORD4;
    #if defined(_NORMALINDEPTHNORMALPASS)
        half4 tangentWS             : TEXCOORD5;
    #endif

	// #if defined(SHADER_STAGE_FRAGMENT)
	// 	FRONT_FACE_TYPE cullFace 	: FRONT_FACE_SEMANTIC;
	// #endif

    //UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
#include "Includes/Lux URP Simple Fuzz SurfaceDataNormal.hlsl"

Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    #if defined(_ALPHATEST_ON) && defined(_MASKMAP) || defined(_NORMALINDEPTHNORMALPASS)
        output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    #endif
    
    output.normalWS = normalInput.normalWS;
    #if defined(_NORMALINDEPTHNORMALPASS)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif
    
    output.positionCS = vertexInput.positionCS;

    return output;
}

//half4 DepthNormalsFragment(Varyings input, FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_TARGET
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
    
    #if defined(_ALPHATEST_ON) && defined(_MASKMAP)
        half mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).a;
        clip (mask - _Cutoff);
    #endif

 //    #if defined(SHADER_STAGE_FRAGMENT)
	// 	input.cullFace = facing; //IS_FRONT_VFACE(frontFace, true, false);
	// #endif

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        outNormalWS = half4(packedNormalWS, 0.0);
    #else
        #if defined(_NORMALINDEPTHNORMALPASS)
            half3 normal;
        //  normal always contains normalWS!
            InitializeNormalData(input, facing, normal);
            input.normalWS = normal;
        #endif
        float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
        outNormalWS = half4(normalWS, 0.0);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}