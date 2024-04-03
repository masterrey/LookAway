#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

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
};

//  Shadow caster specific input
float3 _LightDirection;
float3 _LightPosition;

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

//  Instance world position
    float3 positionWS = float3(UNITY_MATRIX_M[0].w, UNITY_MATRIX_M[1].w, UNITY_MATRIX_M[2].w);

//  Shadowcaster Pass specific!
//  Unfortunately we have to differentiate between light types here.
    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
        float3 lightDirectionWS = _LightDirection;
    //  Distinguish between Directional (true) and Spot loght (false)
        //float3 viewDirWS = UNITY_MATRIX_VP[3].w == 1.0f ? UNITY_MATRIX_I_V[2].xyz : normalize(_LightPosition - positionWS);
        //float3 viewDirWS = UNITY_MATRIX_I_V[2].xyz; // cam forward
    #endif
//  UNITY_MATRIX_I_V._14_24_34 mostly matches unity_BillboardCameraPosition - but i am not sure if unity_BillboardCameraPosition is always available.
//  In case we deal with a directional light we have to use the camera's forward vector tho.
    #define cameraForward UNITY_MATRIX_V[2].xyz 
    float3 viewDirWS = UNITY_MATRIX_VP[3].w == 1.0f ? cameraForward : normalize(UNITY_MATRIX_I_V._14_24_34 - positionWS);

//  #if !defined(_UPRIGHT)
//  It does not make sense to calculate screen space aligned shadows.
//  So we always use upright code here.
        
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
    positionWS = TransformObjectToWorld(billboardPos).xyz;
    positionWS -= viewDirWS * _ShadowOffset;

    half3 normalWS = billboardNormalWS;

    output.uv = input.texcoord;
    output.uv.x = (output.uv.x - 0.5f) * _Shrink + 0.5f;

    output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

    #if UNITY_REVERSED_Z
        output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif
    return output;
}

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif
    Alpha(SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return 0;
}