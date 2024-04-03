#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct VertexInputDepthOnly
{
    float3 positionOS               : POSITION;
    float2 texcoord                 : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutputDepthOnly
{
    float4 positionCS               : SV_POSITION;
    #if defined(_NORMALMAP) || defined (_ALPHATEST_ON)
        float2 uv                   : TEXCOORD0;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

VertexOutputDepthOnly DepthOnlyVertex(VertexInputDepthOnly input)
{
    VertexOutputDepthOnly output = (VertexOutputDepthOnly)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    #if defined(_ALPHATEST_ON)
        output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
    #endif

    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    return output;
}

half4 DepthOnlyFragment(VertexOutputDepthOnly input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON)
        half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy).a;
        clip (mask - _Cutoff);
    #endif

    return input.positionCS.z;
}