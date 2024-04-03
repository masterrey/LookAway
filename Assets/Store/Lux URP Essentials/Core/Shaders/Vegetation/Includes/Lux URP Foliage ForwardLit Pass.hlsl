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

    #if defined(_ALPHATEST_ON)
        half fade                       : TEXCOORD7;
    #endif

    float4 positionCS                   : SV_POSITION;

    #if defined(_DEBUG)
        half4 color                     : COLOR;
    #endif
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
#include "Includes/Lux URP Foliage SurfaceData.hlsl"


//--------------------------------------
//  Vertex shader

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//  Set distance fade value
    float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
    float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
    float dist = dot(diff, diff);
    float fade = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );

//  Shrink mesh if alpha testing is disabled
    #if !defined(_ALPHATEST_ON)
        input.positionOS.xyz *= fade;
    #else 
        output.fade = fade;  
    #endif

//  Wind in ObjectSpace -------------------------------
    animateVertex(input.color, input.normalOS.xyz, input.positionOS.xyz);
//  End Wind -------------------------------

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

//  Flip normals in view space
    #if defined _NORMALVS
        half3 normalVS = TransformWorldToViewDir(normalInput.normalWS, false); 
        normalVS.z = abs(normalVS.z);
        normalInput.normalWS = NormalizeNormalPerVertex( mul( (real3x3)UNITY_MATRIX_I_V, normalVS) );

        #ifdef _NORMALMAP
        //  Adjust tangentWS as we have tweaked normalWS
            normalInput.tangentWS.xyz = Orthonormalize(normalInput.tangentWS.xyz, normalInput.normalWS.xyz);
        #endif
    #endif

    output.normalWS = normalInput.normalWS;
    #ifdef _NORMALMAP
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
        output.tangentWS = tangentWS;
    #endif
    
    output.uv.xy = input.texcoord;

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
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
        output.positionWS = vertexInput.positionWS;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    #if defined(_DEBUG)
        output.color = input.color;
    #endif

    return output;
}

//--------------------------------------
//  Fragment shader and functions

void InitializeInputData(Varyings input, half3 normalTS, half facing, out InputData inputData)
{
    inputData = (InputData)0;
    
    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        inputData.positionWS = input.positionWS;
    #endif
    
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    #ifdef _NORMALMAP
        normalTS.z *= facing;
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS *= facing;
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
    Varyings input, half facing : VFACE
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
    AdditionalSurfaceData additionalSurfaceData;
    InitializeSurfaceData(input, surfaceData, additionalSurfaceData);

//  Prepare surface data
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, facing, inputData);

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif
#endif

    half4 color = LuxURPTranslucentFragmentPBR(
        inputData,
        surfaceData,
        half4(_TranslucencyStrength * additionalSurfaceData.translucency, _TranslucencyPower, _ShadowStrength, _Distortion),
        1,
        _MaskByShadowStrength
    );

//  Add fog
    color.rgb = MixFog(color.rgb, inputData.fogCoord);

    #if defined(_DEBUG)
        if(_DebugVertexColor == 0) {
            color.rgb = half3(input.color.r, 0, 0);
        }
        else if(_DebugVertexColor == 1) {
            color.rgb = half3(0, input.color.g, 0);
        }
        else if(_DebugVertexColor == 2) {
            color.rgb = half3(0, 0, input.color.b);
        }
        else {
            color.rgb = input.color.aaa;
        }
        color.rgb *= _DebugBrightness;
    #endif

    outColor = color;

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}