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

//  ///////////////////////////////////////////////
//  Lux
//  We use a different keyword but want to keep as much of the original code, so:
#if defined(_PARALLAX)
    #define _PARALLAXMAP
#endif
//  ///////////////////////////////////////////////

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && defined(_ALPHATEST_ON) && !defined(SHADER_API_GLES)
    #define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif



// -------------------------------------
// Structs
struct Attributes
{
    float4 position             : POSITION;
#if _ALPHATEST_ON
    float2 uv                   : TEXCOORD0;
#endif
    float3 positionOld          : TEXCOORD4;
#if _ADD_PRECOMPUTED_VELOCITY
    float3 alembicMotionVector  : TEXCOORD5;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    float3 normalOS             : NORMAL;
    float4 tangentOS            : TANGENT;
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

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                   : TEXCOORD1;
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

    const VertexPositionInputs vertexInput = GetVertexPositionInputs(input.position.xyz);

    #if defined(_ALPHATEST_ON)
        output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    #endif

    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)

        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
        real sgn = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS, sgn);

        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
        half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, normalInput.normalWS, viewDirWS);
        output.viewDirTS = viewDirTS;
    #endif

    // Jittered. Match the frame.
    output.positionCS = vertexInput.positionCS;
    output.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, input.position));

    float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(input.positionOld, 1) : input.position;

#if _ADD_PRECOMPUTED_VELOCITY
    prevPos = prevPos - float4(input.alembicMotionVector, 0);
#endif

    output.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, prevPos));

    ApplyMotionVectorZBias(output.positionCS);

    return output;
}

// -------------------------------------
// Fragment
float4 frag(Varyings input, half facing : VFACE) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #if defined(LOD_FADE_CROSSFADE)
        LODFadeCrossFade(input.positionCS);
    #endif

    //  Camera Fading
    #if defined(_ALPHATEST_ON) && defined(_FADING_ON)
        clip ( input.positionCS.w - _CameraFadeDist - Dither32(input.positionCS.xy, 1));                   
    #endif

    

    #if defined(_ALPHATEST_ON)
        float2 uv = input.uv;
        #if defined(_PARALLAX)
            #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                half3 viewDirTS = input.viewDirTS;
                viewDirTS.z *= facing;
            //  Parallax
                float3 v = viewDirTS;
                v.z += 0.42;
                v.xy /= v.z;
                float halfParallax = _Parallax * 0.5f;
                float parallax = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).g * _Parallax - halfParallax;
                float2 offset1 = parallax * v.xy;
            //  Calculate 2nd height
                parallax = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv + offset1).g * _Parallax - halfParallax;
                float2 offset2 = parallax * v.xy;
            //  Final UVs
                uv += (offset1 + offset2) * 0.5f;
            #endif
        #endif
        Alpha(SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    #endif

    return float4(CalcNdcMotionVectorFromCsPositions(input.positionCSNoJitter, input.previousPositionCSNoJitter), 0, 0);
}


#endif // UNIVERSAL_OBJECT_MOTION_VECTORS_INCLUDED
