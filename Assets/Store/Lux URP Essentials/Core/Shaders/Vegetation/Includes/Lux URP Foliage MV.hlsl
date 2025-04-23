#ifndef UNIVERSAL_OBJECT_MOTION_VECTORS_INCLUDED
#define UNIVERSAL_OBJECT_MOTION_VECTORS_INCLUDED

#pragma target 3.5

#pragma vertex vert
#pragma fragment frag

//--------------------------------------
// GPU Instancing
#pragma multi_compile_instancing
#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

//-------------------------------------
// Other pragmas
#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"

// -------------------------------------
// Includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MotionVectorsCommon.hlsl"

// -------------------------------------
// Structs
struct Attributes
{
    float4 position             : POSITION;
    
    float3 normalOS             : NORMAL;
    half4 color                 : COLOR;

#if _ALPHATEST_ON
    float2 uv                   : TEXCOORD0;
#endif
    float3 positionOld          : TEXCOORD4;
#if _ADD_PRECOMPUTED_VELOCITY
    float3 alembicMotionVector  : TEXCOORD5;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS                 : SV_POSITION;
    float4 positionCSNoJitter         : POSITION_CS_NO_JITTER;
    float4 previousPositionCSNoJitter : PREV_POSITION_CS_NO_JITTER;
#if _ALPHATEST_ON
    float2 uv                         : TEXCOORD0;
    half fade                         : TEXCOORD1;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// -------------------------------------
// Vertex
Varyings vert(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//  ///////////////////////////////////////
//  Set distance fade value
//  NOTE: This does not fit the previous frame - which should be a minor issue only tho
    float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
    float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
    float dist = dot(diff, diff);
    float fade = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );

//  Shrink mesh if alpha testing is disabled
    #if !defined(_ALPHATEST_ON)
        input.position.xyz *= fade;
    #else 
        output.fade = fade;  
    #endif

//  Cache vertex position!
    float4 positionOS = input.position;

//  Wind in ObjectSpace -------------------------------
    animateVertexReal(input.color, input.normalOS.xyz, input.position.xyz, _TimeParameters, _LuxURPWindRT, sampler_LuxURPWindRT);
//  End Wind -------------------------------

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.position.xyz);

    #if defined(_ALPHATEST_ON)
        output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    #endif

#if defined(APLICATION_SPACE_WARP_MOTION)
    // We do not need jittered position in ASW
    output.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, input.position));
    output.positionCS = output.positionCSNoJitter;
#else
    // Jittered. Match the frame.
    output.positionCS = vertexInput.positionCS;
    output.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, input.position));
#endif

//  NOTE: As we tweaked input.position we have to use the cached vertex position !!!!!!!!!!!!
    float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(input.positionOld, 1) : positionOS;

#if _ADD_PRECOMPUTED_VELOCITY
    prevPos = prevPos - float4(input.alembicMotionVector, 0);
#endif

    //  Wind in ObjectSpace -------------------------------
    if (_MotionVectorsVA)
    {
        animateVertexReal(input.color, input.normalOS.xyz, prevPos.xyz, _LastTimeParameters, _LuxURPWindRTPrevious, sampler_LuxURPWindRTPrevious);     
    }
    else
    {
        prevPos.xyz = input.position.xyz;
    }
    //  End Wind -------------------------------

    output.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, prevPos));

    ApplyMotionVectorZBias(output.positionCS);

    return output;
}

// -------------------------------------
// Fragment
float4 frag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #if defined(_ALPHATEST_ON)
        Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    #endif

    #if defined(LOD_FADE_CROSSFADE)
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(APLICATION_SPACE_WARP_MOTION)
        return float4(CalcAswNdcMotionVectorFromCsPositions(input.positionCSNoJitter, input.previousPositionCSNoJitter), 1);
    #else
        return float4(CalcNdcMotionVectorFromCsPositions(input.positionCSNoJitter, input.previousPositionCSNoJitter), 0, 0);
    #endif
}


#endif // UNIVERSAL_OBJECT_MOTION_VECTORS_INCLUDED
