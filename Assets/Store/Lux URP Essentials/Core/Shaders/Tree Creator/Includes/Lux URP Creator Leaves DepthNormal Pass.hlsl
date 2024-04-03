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
    half3 normalWS                  : TEXCOORD1;
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        float4 screenPos            : TEXCOORD2;
    #endif
    #if defined(_NORMALINDEPTHNORMALPASS)
        half4 tangentWS             : TEXCOORD3;
    #endif
};

// Tree Creator Library relies on Attributes and Varyings
#include "Includes/Lux URP Tree Creator Library.hlsl"
            
Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

//  Wind in Object Space -------------------
    TreeVertLeaf(input);
//  End Wind -------------------------------

    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    
    #if defined(_NORMALINDEPTHNORMALPASS)
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    #else
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
    #endif
    float3 normalWS = normalInput.normalWS;

    output.positionCS = TransformWorldToHClip(positionWS);
    output.normalWS.xyz = NormalizeNormalPerVertex(normalWS).xyz;

    #if defined(_NORMALINDEPTHNORMALPASS)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif

//  Specifics
    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
//  Dither coords - not perfect for shadows but ok.
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        output.screenPos = ComputeScreenPos(output.positionCS);
    #endif

    return output;
}

half4 DepthNormalsFragment(Varyings input) : SV_TARGET
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

    #if defined(_NORMALINDEPTHNORMALPASS)
        half4 sampleNormal = SAMPLE_TEXTURE2D(_BumpSpecMap, sampler_BumpSpecMap, input.uv.xy);
        half3 normalTS;
        normalTS.xy = sampleNormal.ag * 2.0h - 1.0h;
        normalTS.z = max(1.0e-16, sqrt(1.0h - saturate(dot(normalTS.xy, normalTS.xy))));
        float sgn = input.tangentWS.w;
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        input.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    #endif
    
    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        return half4(packedNormalWS, 0.0);
    #else
        float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
        return half4(normalWS, 0.0);
    #endif
}