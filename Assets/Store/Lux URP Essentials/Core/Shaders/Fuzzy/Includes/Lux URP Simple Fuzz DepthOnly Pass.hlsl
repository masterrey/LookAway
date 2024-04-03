#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float3 positionOS               : POSITION;
    #if defined(_ALPHATEST_ON) && defined(_MASKMAP)
        float2 texcoord             : TEXCOORD0;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS               : SV_POSITION;
    #if defined(_ALPHATEST_ON) && defined(_MASKMAP)
        float2 uv                   : TEXCOORD0;
    #endif
    //UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthOnlyVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

    #if defined(_ALPHATEST_ON) && defined(_MASKMAP)
        output.uv = TRANSFORM_TEX(input.texcoord, _MaskMap);
    #endif
    
    return output;
}

half4 DepthOnlyFragment(Varyings input) : SV_TARGET
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

    return 0;
}