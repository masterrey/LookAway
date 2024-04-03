#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs
struct Attributes
{
    float4 positionOS                   : POSITION;
    float3 normalOS                     : NORMAL;
    float4 tangentOS                    : TANGENT;
    float2 texcoord                     : TEXCOORD0;
    #ifdef LIGHTMAP_ON
        float2 staticLightmapUV         : TEXCOORD1;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV        : TEXCOORD2;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float2 uv                           : TEXCOORD0;
    //#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        float3 positionWS               : TEXCOORD1;
    //#endif
    half3 normalWS                      : TEXCOORD2;
    //#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    #ifdef _NORMALMAP
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
    //#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    //    half3 viewDirTS               : TEXCOORD6;
    //#endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
    #ifdef DYNAMICLIGHTMAP_ON
        float2  dynamicLightmapUV       : TEXCOORD8;
    #endif

    float4 positionCS                   : SV_POSITION;

    // #if defined(SHADER_STAGE_FRAGMENT)
    //     FRONT_FACE_TYPE cullFace        : FRONT_FACE_SEMANTIC;
    // #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
#include "Includes/Lux URP Simple Fuzz SurfaceData.hlsl"

//--------------------------------------
//  Vertex shader

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput;
    vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    output.normalWS = normalInput.normalWS;

    #ifdef _NORMALMAP
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
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

    //half3 viewDirWS = SafeNormalize(input.viewDirWS);
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    #if defined(_NORMALMAP)
        normalTS.z *= facing;
        // #if defined(SHADER_STAGE_FRAGMENT)
        //     normalTS.z *= input.cullFace ? 1 : -1;
        // #endif
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS * facing;
        // #if defined(SHADER_STAGE_FRAGMENT)
        //     inputData.normalWS *= input.cullFace ? 1 : -1;
        // #endif
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

//half4 LitPassFragment(Varyings input, FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_Target
//half4 LitPassFragment(Varyings input, half facing : VFACE) : SV_Target
//{
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
    InitializeSurfaceData(input.uv, surfaceData, additionalSurfaceData);

    // half facing = 1;
    // #if defined(SHADER_STAGE_FRAGMENT)
    //     input.cullFace = IS_FRONT_VFACE(frontFace, true, false);
    // #endif

//  Prepare surface data (like bring normal into world space and get missing inputs like gi)
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, facing, inputData);

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        #if defined(_SIMPLEFUZZ)
            half3 albedo = surfaceData.albedo;
        #endif
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
        #if defined(_SIMPLEFUZZ)
        //  Somehow mask fuzz lighting and transmission on decals
            //surfaceData.fuzzMask *= 1.0h - saturate( abs(albedo.g - surfaceData.albedo.g) * 256.0h );
            half suppression = 1.0h - saturate( abs( dot(albedo, albedo) - dot(surfaceData.albedo, surfaceData.albedo) ) * 256.0h );
            additionalSurfaceData.fuzzMask *= suppression;
            additionalSurfaceData.translucency *= lerp(suppression, 1, _DecalTransmission);
        #endif
    #endif
#endif

    #if defined(_RIMLIGHTING)
        half rim = saturate(1.0h - saturate( dot(inputData.normalWS, inputData.viewDirectionWS) ) );
        half power = _RimPower;
        if(_RimFrequency > 0 ) {
            half perPosition = lerp(0.0h, 1.0h, dot(1.0h, frac(UNITY_MATRIX_M._m03_m13_m23) * 2.0h - 1.0h ) * _RimPerPositionFrequency ) * 3.1416h;
            power = lerp(power, _RimMinPower, (1.0h + sin(_Time.y * _RimFrequency + perPosition) ) * 0.5h );
        }
        surfaceData.emission += pow(rim, power) * _RimColor.rgb * _RimColor.a;
    #endif

//  Apply lighting
    half4 color = LuxURPSimpleFuzzFragmentPBR(
        inputData, 
        surfaceData,
        additionalSurfaceData, // Fuzzmask and translucency
        _FuzzPower,
        _FuzzBias,
        _FuzzWrap,
        _FuzzStrength * PI,
        _FuzzAmbient,
        #if defined(_SCATTERING)
            half4(additionalSurfaceData.translucency * _TranslucencyStrength, _TranslucencyPower, _ShadowStrength, _Distortion)
        #else
            half4(0,0,0,0)
        #endif
    );    
//  Add fog
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    outColor = color;

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}