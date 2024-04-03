#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float3 positionOS               : POSITION;
    float3 normalOS                 : NORMAL;
    float4 tangentOS                : TANGENT;
    float2 texcoord                 : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS               : SV_POSITION;
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) || defined (_ALPHATEST_ON)
        float2 uv                   : TEXCOORD0;
    #endif
    #if defined(_SSAO_FLATSHADED)
        float3 positionWS           : TEXCOORD2;
    #else
        float3 normalWS             : TEXCOORD4;
    #endif
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        half4 tangentWS             : TEXCOORD5;
    #endif

    // #if defined(SHADER_STAGE_FRAGMENT)
    //     FRONT_FACE_TYPE cullFace    : FRONT_FACE_SEMANTIC;
    // #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS) || defined (_ALPHATEST_ON)
        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    #endif

    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

//  Just in case :)
    #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif
    
    #if defined(_SSAO_FLATSHADED)
        output.positionWS = TransformObjectToWorld(input.positionOS);
    #else
        output.normalWS = normalInput.normalWS;
    #endif

    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    
    return output;
}

//half4 DepthNormalsFragment(Varyings input, FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_TARGET
//half4 DepthNormalsFragment(Varyings input, half facing : VFACE) : SV_TARGET
//{
void DepthNormalsFragment(
    Varyings input, half facing : VFACE
    , out half4 outNormalWS : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif
    
    #if defined(_ALPHATEST_ON)
        half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;
        clip (mask - _Cutoff);
    #endif

    // #if defined(SHADER_STAGE_FRAGMENT)
    //     input.cullFace = IS_FRONT_VFACE(frontFace, true, false);
    // #endif

//  Obsolete?
    #if defined(_GBUFFER_NORMALS_OCT)
        #if defined(_SSAO_FLATSHADED)
            half3 normalWS = half3( normalize( cross(ddy(input.positionWS), ddx(input.positionWS)) ) );
        #else
            float3 normalWS = normalize(input.normalWS);
        #endif
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
        outNormalWS = half4(packedNormalWS, 0.0);
    #else
        #if defined(_SSAO_FLATSHADED)
            //  Create custom per vertex normal // SafeNormalize does not work here on Android?!
            half3 normalWS = half3( normalize( cross(ddy(input.positionWS), ddx(input.positionWS)) ) );
            //  TODO: Vulkan on Android here shows inverted normals?
            #if defined(SHADER_API_VULKAN)
                normalWS *= -1;
            #endif
        #else
            half3 normalWS = NormalizeNormalPerPixel(input.normalWS);
            #if defined(SHADER_STAGE_FRAGMENT) && !defined(_NORMALINDEPTHNORMALPASS)
                normalWS *= facing; //input.cullFace ? 1 : -1;
            #endif
        #endif

        #if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
            half3 normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
            #if defined(SHADER_STAGE_FRAGMENT) && !defined(_SSAO_FLATSHADED)
                normalTS.z *= facing; //input.cullFace ? 1 : -1;
            #endif
        //  Adjust tangentWS as we have tweaked normalWS
            input.tangentWS.xyz = Orthonormalize(input.tangentWS.xyz, normalWS.xyz);
            float sgn = input.tangentWS.w;
            float3 bitangent = sgn * cross(normalWS.xyz, input.tangentWS.xyz);
            normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, normalWS));
        #endif

        normalWS = NormalizeNormalPerPixel(normalWS);
        outNormalWS = half4(normalWS, 0.0);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}