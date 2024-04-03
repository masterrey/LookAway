#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float3 positionOS               : POSITION;
    float3 normalOS                 : NORMAL;
    float2 texcoord                 : TEXCOORD0;
    half4 color                     : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS               : SV_POSITION;
    #if defined(_ALPHATEST_ON)
        float2 uv                   : TEXCOORD0;
        half2 fadeOcclusion         : TEXCOORD1;
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

    #if defined(_ALPHATEST_ON)
        output.uv.xy = input.texcoord;
        output.fadeOcclusion = fadeOcclusion;
    #endif
    output.positionCS = TransformWorldToHClip(positionWS);
    return output;
}

half4 DepthOnlyFragment(Varyings input) : SV_TARGET
{
    //UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON)
        Alpha(SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a * input.fadeOcclusion.x, /*_BaseColor*/ half4(1,1,1,1), _Cutoff);
    #endif
    
    return input.positionCS.z;
}