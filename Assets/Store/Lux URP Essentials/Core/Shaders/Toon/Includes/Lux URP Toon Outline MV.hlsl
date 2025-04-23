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
#if _ALPHATEST_ON
    float2 uv                   : TEXCOORD0;
#else
    float3 normalOS             : NORMAL;
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


//  /////////////////////////////////////////////
    #if !defined(_ALPHATEST_ON)

        float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(input.positionOld, 1) : input.position;

    //  Extrude
        #if !defined(_OUTLINEINSCREENSPACE)
            #if defined(_COMPENSATESCALE)
                float3 scale;
                scale.x = length(float3(UNITY_MATRIX_M[0].x, UNITY_MATRIX_M[1].x, UNITY_MATRIX_M[2].x));
                scale.y = length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y));
                scale.z = length(float3(UNITY_MATRIX_M[0].z, UNITY_MATRIX_M[1].z, UNITY_MATRIX_M[2].z));
            #endif
            
            input.position.xyz += input.normalOS * 0.001 * _Border
            #if defined(_COMPENSATESCALE) 
                / scale
            #endif
            ;

            prevPos.xyz += input.normalOS * 0.001 * _Border
            #if defined(_COMPENSATESCALE) 
                / scale
            #endif
            ;

        #endif
        output.positionCS = TransformObjectToHClip(input.position.xyz);
        
        output.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, input.position));
        output.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, prevPos));

    //  Extrude
        #if defined(_OUTLINEINSCREENSPACE)
            if (_Border > 0.0h) {
                float3 normal = mul(UNITY_MATRIX_MVP, float4(input.normalOS, 0)).xyz; // to clip space
                float2 offset = normalize(normal.xy);
                float2 ndc = _ScreenParams.xy * 0.5;
                float2 finalOffset = ((offset * _Border) / ndc * output.positionCS.w);
                output.positionCS.xy += finalOffset;
                output.positionCSNoJitter += finalOffset;
                output.previousPositionCSNoJitter += finalOffset;
            }
        #endif
    #else
        output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
        output.positionCS = TransformObjectToHClip(input.position.xyz);
        output.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, input.position));

        float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(input.positionOld, 1) : input.position;
        output.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, prevPos));
    #endif
//  /////////////////////////////////////////////

    // const VertexPositionInputs vertexInput = GetVertexPositionInputs(input.position.xyz);
    // #if defined(_ALPHATEST_ON)
    //     output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    // #endif

    // Jittered. Match the frame.
    // output.positionCS = vertexInput.positionCS;
    // output.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, input.position));

    // float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(input.positionOld, 1) : input.position;


// #if _ADD_PRECOMPUTED_VELOCITY
//     prevPos = prevPos - float4(input.alembicMotionVector, 0);
// #endif

//     output.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, prevPos));

    ApplyMotionVectorZBias(output.positionCS);

    return output;
}

//  Helper
inline float2 shufflefast (float2 offset, float2 shift) {
    return offset * shift;
}

// -------------------------------------
// Fragment
float4 frag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #if defined(_ALPHATEST_ON)
        float2 uv = input.uv;

        float2 offset = float2(1,1);
        #if defined(_OUTLINEINSCREENSPACE)
            float2 shift = fwidth(uv) * (_Border * 0.5f);
        #else
            float2 shift = _Border.xx * float2(0.5, 0.5) * _BaseMap_TexelSize.xy;
        #endif

        float2 sampleCoord = uv + shufflefast(offset, shift); 
        half shuffleAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

        offset = float2(-1,1);
        sampleCoord = uv + shufflefast(offset, shift);
        shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

        offset = float2(1,-1);
        sampleCoord = uv + shufflefast(offset, shift);
        shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

        offset = float2(-1,-1);
        sampleCoord = uv + shufflefast(offset, shift);
        shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

    //  Apply clip
        clip(shuffleAlpha - _Cutoff);

    #endif

    #if defined(LOD_FADE_CROSSFADE)
        LODFadeCrossFade(input.positionCS);
    #endif

    return float4(CalcNdcMotionVectorFromCsPositions(input.positionCSNoJitter, input.previousPositionCSNoJitter), 0, 0);
}


#endif // UNIVERSAL_OBJECT_MOTION_VECTORS_INCLUDED
