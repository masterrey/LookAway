#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs
struct Attributes
{
    float3 positionOS                   : POSITION;
    #if defined(_ALPHATEST_ON) && (defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO))
        float2 texcoord                 : TEXCOORD0;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS                   : SV_POSITION;
    #if defined(_ALPHATEST_ON) && (defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO))
        float2 uv                       : TEXCOORD0;
    #endif
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthOnlyVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    #if defined(_ALPHATEST_ON) && (defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO))
        output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
    #endif
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    return output;
}

half4 DepthOnlyFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON) && (defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO))
        half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;
        clip (mask * _BaseColor.a - _Cutoff);
    #endif
    
    return input.positionCS.z;
}