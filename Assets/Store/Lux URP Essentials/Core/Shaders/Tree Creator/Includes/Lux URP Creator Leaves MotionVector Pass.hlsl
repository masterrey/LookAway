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
    float3 positionOS                   : POSITION; // float3
    float3 normalOS                     : NORMAL;
    float4 tangentOS                    : TANGENT;
    half4 color                         : COLOR;
    float2 texcoord1                    : TEXCOORD1;

#if _ALPHATEST_ON
    float2 uv                           : TEXCOORD0;
#endif
    float3 positionOld                  : TEXCOORD4;
#if _ADD_PRECOMPUTED_VELOCITY
    float3 alembicMotionVector          : TEXCOORD5;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS                   : SV_POSITION;
    float4 positionCSNoJitter           : POSITION_CS_NO_JITTER;
    float4 previousPositionCSNoJitter   : PREV_POSITION_CS_NO_JITTER;
#if _ALPHATEST_ON
    float2 uv                           : TEXCOORD0;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


#include "Includes/Lux URP Tree Creator Library.hlsl"


// -------------------------------------
// Vertex
Varyings vert(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float3 positionOS = input.positionOS.xyz;

#if defined(_MOTIONVECTORVA)
    // Animate current frame
    positionOS = TreeVertLeafMV(input, positionOS.xyz, false).xyz;
#endif

    const VertexPositionInputs vertexInput = GetVertexPositionInputs(positionOS.xyz);

#if _ALPHATEST_ON
    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
#endif

    // Jittered. Match the frame.
    output.positionCS = vertexInput.positionCS;
    output.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, float4(positionOS, 1)));
    float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(input.positionOld, 1) : float4(input.positionOS, 1);

#if defined(_MOTIONVECTORVA)
    // Animate previous frame
    prevPos.xyz = TreeVertLeafMV(input, prevPos.xyz, true).xyz;
#endif

// #if _ADD_PRECOMPUTED_VELOCITY
//     prevPos = prevPos - float4(input.alembicMotionVector, 0);
// #endif

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

#ifdef LOD_FADE_CROSSFADE
    LODFadeCrossFade(input.positionCS);
#endif

#if _ALPHATEST_ON
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex)).a, float4(1,1,1,1), _Cutoff);
#endif

    return float4(CalcNdcMotionVectorFromCsPositions(input.positionCSNoJitter, input.previousPositionCSNoJitter), 0, 0);
}


#endif // UNIVERSAL_OBJECT_MOTION_VECTORS_INCLUDED
