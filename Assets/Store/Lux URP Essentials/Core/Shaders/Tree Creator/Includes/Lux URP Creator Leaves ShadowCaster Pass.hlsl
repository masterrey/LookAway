#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float3 positionOS               : POSITION;
    float3 normalOS                 : NORMAL;
    float4 tangentOS                : TANGENT;
    float2 texcoord                 : TEXCOORD0;
    float2 texcoord1                : TEXCOORD1;
    half4 color                     : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS               : SV_POSITION;
    float2 uv                       : TEXCOORD0;
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        float4 screenPos            : TEXCOORD2;
    #endif
};

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// Tree Creator Library relies on Attributes and Varyings
#include "Includes/Lux URP Tree Creator Library.hlsl"
            
//  Shadow caster specific input
float3 _LightDirection;
float3 _LightPosition;

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

//  Wind in Object Space -------------------
    TreeVertLeaf(input);
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

//  Specifics
    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
//  Dither coords - not perfect for shadows but ok.
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        output.screenPos = ComputeScreenPos(output.positionCS);
    #endif

    return output;
}

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON)
        half mask = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).a;
    //  Dither
        #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
            half coverage = 1.0h;
            half dither = UNITY_ACCESS_INSTANCED_PROP(Props, _TreeInstanceColor).a; 
            [branch]
            if ( dither < 1.0h) {
                coverage = ComputeAlphaCoverage(input.screenPos, dither );
            }
            mask *= coverage;
        #endif
        clip (mask - _Cutoff);
    #endif
    return 0;
}