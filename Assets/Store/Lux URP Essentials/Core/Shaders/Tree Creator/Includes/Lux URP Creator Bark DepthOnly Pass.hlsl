#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float3 positionOS               : POSITION;
    float3 normalOS                 : NORMAL;
    float4 tangentOS                : TANGENT;
    float2 texcoord1                : TEXCOORD1;
    half4 color                     : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS               : SV_POSITION;
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        float4 screenPos            : TEXCOORD2;
    #endif
};

// Tree Creator Library relies on Attributes and Varyings
#include "Includes/Lux URP Tree Creator Library.hlsl"
            
Varyings DepthOnlyVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

//  Wind in Object Space -------------------
    TreeVertLeaf(input);
//  End Wind -------------------------------

    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);

    output.positionCS = TransformWorldToHClip(positionWS);

//  Specifics
//  Dither coords - not perfect for shadows but ok.
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        output.screenPos = ComputeScreenPos(output.positionCS);
    #endif

    return output;
}

half4 DepthOnlyFragment(Varyings input) : SV_TARGET
{

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

//  Dither
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        half coverage = 1.0h;
        half dither = UNITY_ACCESS_INSTANCED_PROP(Props, _TreeInstanceColor).a; 
        [branch]
        if ( dither < 1.0h) {
            coverage = ComputeAlphaCoverage(input.screenPos, dither );
        }
        clip (coverage);
    #endif

    return input.positionCS.z;
}