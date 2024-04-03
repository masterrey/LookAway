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
    float2 uv                           : TEXCOORD0;
    half3 normalWS                      : TEXCOORD1;
    #if defined (_NORMALMAP)
        half4 tangentWS                 : TEXCOORD2;
    #endif

    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthNormalVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//  Instance world position
    float3 positionWS = float3(UNITY_MATRIX_M[0].w, UNITY_MATRIX_M[1].w, UNITY_MATRIX_M[2].w);

    #if !defined(_UPRIGHT)
        input.positionOS.xyz = 0;
        #if defined(_PIVOTTOBOTTOM)
            input.positionOS.xy = input.texcoord.xy - float2(0.5f, 0.0f);
        #else
            input.positionOS.xy = input.texcoord.xy - 0.5;
        #endif
        input.positionOS.x *= _Shrink;

        float2 scale;
        scale.x = length(float3(UNITY_MATRIX_M[0].x, UNITY_MATRIX_M[1].x, UNITY_MATRIX_M[2].x));
        scale.y = length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y));

        //float4 positionVS = mul(UNITY_MATRIX_MV, float4(0, 0, 0, 1.0));
        float4 positionVS = mul(UNITY_MATRIX_V, float4(UNITY_MATRIX_M._m03_m13_m23, 1.0));
        positionVS.xyz += input.positionOS.xyz * float3(scale.xy, 1.0);
        output.positionCS = mul(UNITY_MATRIX_P, positionVS);

    //  we have to make the normal point towards the cam
        half3 viewDirWS = normalize(GetCameraPositionWS() - positionWS); // half3
        half3 billboardTangentWS = normalize(half3(-viewDirWS.z, 0, viewDirWS.x));
        half3 billboardNormalWS = viewDirWS;

    #else
        float3 viewDirWS = normalize(GetCameraPositionWS() - positionWS); // float3
        float3 billboardTangentWS = normalize(float3(-viewDirWS.z, 0, viewDirWS.x));
        half3 billboardNormalWS = float3(billboardTangentWS.z, 0, -billboardTangentWS.x);
    
    //  Expand Billboard
        float2 percent = input.texcoord.xy;
        float3 billboardPos = (percent.x - 0.5f) * _Shrink * billboardTangentWS;
        #if defined(_PIVOTTOBOTTOM)
            billboardPos.y += percent.y;
        #else
            billboardPos.y += percent.y - 0.5f;
        #endif
        output.positionCS = TransformObjectToHClip(billboardPos);
    #endif

    output.uv = input.texcoord.xy;
    output.uv.x = (output.uv.x - 0.5f) * _Shrink + 0.5f;

    #ifdef _NORMALMAP
        output.normalWS = billboardNormalWS;
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(billboardTangentWS, sign);
    #endif

    return output;
}


void DepthNormalFragment(
    Varyings input
    , out half4 outNormalWS : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a , _BaseColor, _Cutoff);

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        outNormalWS = (packedNormalWS, 0.0);
    #else
        #if defined (_NORMALMAP)
            half3 normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
            float sgn = input.tangentWS.w;
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            input.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
        #endif
        float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
        outNormalWS = half4(normalWS, 0.0);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}