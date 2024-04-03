#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs

struct Attributes
{
    float3 positionOS                   : POSITION;
    float3 normalOS                     : NORMAL;
    float4 tangentOS                    : TANGENT;
    float2 texcoord                     : TEXCOORD0;
    #ifdef LIGHTMAP_ON
        float2 staticLightmapUV         : TEXCOORD1;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV        : TEXCOORD2;
    #endif
    half4 color                         : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                           : TEXCOORD0;
    float3 positionWS                   : TEXCOORD1;
    half3 normalWS                      : TEXCOORD2;
    #if defined(_NORMALMAP)
        half4 tangentWS                 : TEXCOORD3;
    #endif
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half4 fogFactorAndVertexLight   : TEXCOORD4;
    #else
        half  fogFactor                 : TEXCOORD4;
    #endif
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord              : TEXCOORD5;
    #endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
    #ifdef DYNAMICLIGHTMAP_ON
        float2  dynamicLightmapUV       : TEXCOORD9;
    #endif

    half2 fadeOcclusion                 : TEXCOORD7;

    float4 positionCS                   : SV_POSITION;
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
//#include "Includes/Lux URP FlatShaded SurfaceData.hlsl"


//--------------------------------------
//  Vertex shader

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    #define vocclusion input.color.r

    float3 positionWS;
    half3 normalWS;
    half2 fadeOcclusion;
    BendGrass(
        input.positionOS,
        input.normalOS,
        input.color,
        positionWS,
        normalWS,
        fadeOcclusion
    );

//  VertexPositionInputs
    VertexPositionInputs vertexInput;
    vertexInput.positionWS = positionWS;
    vertexInput.positionVS = TransformWorldToView(positionWS);
    vertexInput.positionCS = TransformWorldToHClip(positionWS);
    float4 ndc = vertexInput.positionCS * 0.5f;
    vertexInput.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
    vertexInput.positionNDC.zw = vertexInput.positionCS.zw;

//  VertexNormalInputs
    VertexNormalInputs normalInput;
    normalInput.normalWS = NormalizeNormalPerVertex(normalWS);
    normalInput.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);

    output.normalWS = normalInput.normalWS;
    #ifdef _NORMALMAP
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
        output.tangentWS = tangentWS;
    #endif
    
//  Do other stuff here
    output.uv.xy = input.texcoord; //TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.fadeOcclusion = fadeOcclusion;
    output.fadeOcclusion.y = lerp(1.0h, vocclusion, _Occlusion);

    half3 vertexLight = VertexLighting(positionWS, normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS, output.vertexSH);
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    #else
        output.fogFactor = fogFactor;
    #endif

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        output.positionWS = positionWS;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

//--------------------------------------
//  Fragment shader and functions

// Include the surface function
#include "Includes/Lux URP Grass SurfaceData.hlsl"

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    
    #ifdef _NORMALMAP
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS;
    #endif

//  Flip normals in view space
    #if defined _NORMALVS
        half3 normalVS = TransformWorldToViewDir(inputData.normalWS, false); 
        normalVS.z = abs(normalVS.z);
        inputData.normalWS = normalize( mul( (real3x3)UNITY_MATRIX_I_V, normalVS) );
    #endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;
    
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
        inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    #else
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
    #endif
    #if defined(DYNAMICLIGHTMAP_ON)
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    #else
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    #endif

    #if defined(LIGHTMAP_ON)
        inputData.bakedGI *= _LightMapBoost;
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #endif
}

void LitPassFragment(
    Varyings input
    , out half4 outColor : SV_Target0
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

//  Get the surface description
    SurfaceData surfaceData;
    InitializeSurfaceData(input, input.fadeOcclusion, surfaceData);

//  Prepare surface data
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif
#endif

//  Apply lighting
    #if defined(_BLINNPHONG)
        surfaceData.smoothness = max(0.01, surfaceData.smoothness);
        half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData);
    #else
        half4 color = UniversalFragmentPBR(inputData, surfaceData);
    #endif
//  Add fog
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    outColor = color;

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}