//  Structs
struct Attributes
{
    float3 positionOS                   : POSITION;
    float3 normalOS                     : NORMAL;
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        float4 tangentOS                : TANGENT;
        float2 texcoord                 : TEXCOORD0;
    #endif
    #if defined(_USEVERTEXCOLORS)
        half4 color                     : COLOR;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS                   : SV_POSITION;
    float3 normalWS                     : TEXCOORD0;
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        float2 uv                       : TEXCOORD1;
        half4 tangentWS                 : TEXCOORD2;
    #endif
    #if defined(_TOPDOWNPROJECTION) && defined(_NORMALINDEPTHNORMALPASS)
        float3 positionWS               : TEXCOORD3;
    #endif
    #if defined(_USEVERTEXCOLORS)
        half4 color                     : COLOR;
    #endif

    //UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
#include "Includes/Lux URP MeshTerrain SurfaceDataNormal.hlsl"

Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    #if defined(_TOPDOWNPROJECTION) && defined(_NORMALINDEPTHNORMALPASS)
        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
        output.positionWS = vertexInput.positionWS;
    #endif
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    #else
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
    #endif
    output.normalWS = normalInput.normalWS;
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        output.uv = input.texcoord;
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif
    
    #if defined(_USEVERTEXCOLORS)
        output.color = input.color;
    #endif
    
    return output;
}

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

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        outNormalWS = half4(normalWS, 0.0);
    #else
        #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
            half3 normal;
        //  normal contain either normalTS of normalWS!
            InitializeNormalData(input, normal);
            #if !defined(_TOPDOWNPROJECTION)
                float sgn = input.tangentWS.w;
                float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                input.normalWS = TransformTangentToWorld(normal, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
            #else
                input.normalWS = normal;
            #endif
        #endif
        float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
        outNormalWS = half4(normalWS, 0.0);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}