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
    #if defined(_NORMALINDEPTHNORMALPASS)
        float4 uv                   : TEXCOORD0;        // float4!
    #endif
    #if defined(LOD_FADE_CROSSFADE)
        float3 positionWS           : TEXCOORD2;
    #endif
    float3 normalWS                 : TEXCOORD4;
    #if defined(_NORMALINDEPTHNORMALPASS)
        half4 tangentWS             : TEXCOORD5;
    #endif
    //UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
#include "Includes/Lux URP TopDown SurfaceDataNormal.hlsl"

Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    #if defined(_NORMALINDEPTHNORMALPASS)
        output.uv.xy = TRANSFORM_TEX(input.uv, _BaseMap);
        output.uv.zw = vertexInput.positionWS.xz * _TopDownTiling + _TerrainPosition.xz;
        #if defined (_DYNSCALE)
            float scale = length( TransformObjectToWorld( float3(1,0,0) ) - UNITY_MATRIX_M._m03_m13_m23 );
            output.uv.xy *= scale;
        #endif
    #endif
    
    output.normalWS = normalInput.normalWS;

    #if defined(_NORMALINDEPTHNORMALPASS)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif
    output.positionCS = vertexInput.positionCS;
    // #if defined(LOD_FADE_CROSSFADE)
    //     output.positionWS = vertexInput.positionWS;
    // #endif
    
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
    
    // #if defined(LOD_FADE_CROSSFADE) && !defined(SHADER_API_GLES)
    //     LODDitheringTransition(input.positionCS.xyz, unity_LODFade.x);
    // #endif
    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        outNormalWS = half4(packedNormalWS, 0.0);
    #else
        #if defined(_NORMALINDEPTHNORMALPASS) // && defined(_NORMALINDEPTHNORMALPASS)
            half3 normal;
        //  normal always contains normalWS!
            InitializeNormalData(input, normal);
            input.normalWS = normal;
        #endif
        float3 normalWS = input.normalWS;
        outNormalWS = half4(NormalizeNormalPerPixel(normalWS), 0.0);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}