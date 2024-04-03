#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float3 positionOS               : POSITION;
    float3 normalOS                 : NORMAL;
    #if defined(_ALPHATEST_ON)
        float2 texcoord             : TEXCOORD0;
    #endif
    half4 color                     : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS               : SV_POSITION;
    #if defined(_ALPHATEST_ON)
        float2 uv                   : TEXCOORD0;
        half fade                   : TEXCOORD1;
    #endif
};

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
//  Shadow caster specific input
float3 _LightDirection;
float3 _LightPosition;

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

//  Set distance fade value
    float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
    float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
    float dist = dot(diff, diff);
    float fade = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );
    
//  Shrink mesh if alpha testing is disabled
    #if !defined(_ALPHATEST_ON)
        input.positionOS.xyz *= fade;
    #endif

    #if defined(_ALPHATEST_ON)
        output.uv = input.texcoord;
        output.fade = fade;
    #endif

//  Wind in Object Space -------------------------------
    animateVertex(input.color, input.normalOS.xyz, input.positionOS.xyz);
//  End Wind -------------------------------

    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldDir(input.normalOS);

    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
        float3 lightDirectionWS = _LightDirection;
    #endif

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

    #if defined(_ALPHATEST_ON)
        Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a * input.fade, half4(1,1,1,1), _Cutoff);
    #endif
    return 0;
}