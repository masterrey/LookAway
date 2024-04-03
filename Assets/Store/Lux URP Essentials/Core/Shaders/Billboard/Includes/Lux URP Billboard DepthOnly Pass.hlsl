#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float3 positionOS               : POSITION;
    float2 texcoord                 : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS               : SV_POSITION;
    float2 uv                       : TEXCOORD0;
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthOnlyVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

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
    #else
    //  Instance world position
        float3 positionWS = float3(UNITY_MATRIX_M[0].w, UNITY_MATRIX_M[1].w, UNITY_MATRIX_M[2].w);
        half3 viewDirWS = normalize(GetCameraPositionWS() - positionWS);
        half3 billboardTangentWS = normalize(float3(-viewDirWS.z, 0, viewDirWS.x));
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

    output.uv = input.texcoord;
    output.uv.x = (output.uv.x - 0.5f) * _Shrink + 0.5f;
    
    return output;
}

half4 DepthOnlyFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif
    
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a , _BaseColor, _Cutoff);
    
    return input.positionCS.z;
    // return 0;
}