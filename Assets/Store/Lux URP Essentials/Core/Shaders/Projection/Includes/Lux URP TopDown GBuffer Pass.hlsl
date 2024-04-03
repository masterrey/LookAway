#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

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

struct Varyings
{
    float4 uv                           : TEXCOORD0; // float4!
    //#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        float3 positionWS               : TEXCOORD1;
    //#endif
    half3 normalWS                      : TEXCOORD2;
    //#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    #ifdef _NORMALMAP
        half4 tangentWS                 : TEXCOORD3;    
    #endif
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half3 vertexLighting            : TEXCOORD4;
    #endif
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord              : TEXCOORD5;
    #endif
    //#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    //    half3 viewDirTS                 : TEXCOORD6;
    //#endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
    #ifdef DYNAMICLIGHTMAP_ON
        float2  dynamicLightmapUV       : TEXCOORD8;
    #endif
    float4 positionCS                   : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


// Include the surface function
#include "Includes/Lux URP TopDown SurfaceData.hlsl"

Varyings LitGBufferPassVertex (Attributes input)
{
    Varyings output = (Varyings)0;
    
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    
    output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.uv.zw = vertexInput.positionWS.xz * _TopDownTiling + _TerrainPosition.xz;

    #if defined (_DYNSCALE)
        float scale = length( TransformObjectToWorld( float3(1,0,0) ) - UNITY_MATRIX_M._m03_m13_m23 );
        output.uv.xy *= scale;
    #endif

    //  Already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;

    //#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    #ifdef _NORMALMAP
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif

    //#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    //    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
    //    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    //    output.viewDirTS = viewDirTS;
    //#endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
        output.vertexLighting = vertexLight;
    #endif

    //#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        output.positionWS = vertexInput.positionWS;
    //#endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    #if defined(_USEVERTEXCOLORS)
        output.color = input.color;
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

FragmentOutput LitGBufferPassFragment(Varyings input)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    SurfaceData surfaceData;
    AdditionalSurfaceData additionalSurfaceData;
//  Get the surface description
    InitializeStandardLitSurfaceData(input, surfaceData, additionalSurfaceData);
//  NOTE: normalTS actually is already normalWS here!

//  Transfer all to world space 
    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.positionCS = input.positionCS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    #ifdef _NORMALMAP
        //float sgn = input.tangentWS.w;
        //float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        //inputData.normalWS = TransformTangentToWorld(surfaceData.normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
        inputData.normalWS = surfaceData.normalTS;
    #else
        inputData.normalWS = input.normalWS;
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

    inputData.fogCoord = 0.0; // we don't apply fog in the guffer pass
    
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        inputData.vertexLighting = input.vertexLighting.xyz;
    #else
        inputData.vertexLighting = half3(0, 0, 0);
    #endif
    
    #if defined(DYNAMICLIGHTMAP_ON)
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    #else
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        #if defined(_SIMPLEFUZZ)
            half3 albedo = surfaceData.albedo;
        #endif
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
        #if defined(_SIMPLEFUZZ)
        //  Somehow mask fuzz lighting on decals
            //surfaceData.fuzzMask *= 1.0h - saturate( abs(albedo.g - surfaceData.albedo.g) * 256.0h );
            additionalSurfaceData.fuzzMask *= 1.0h - saturate( abs( dot(albedo, albedo) - dot(surfaceData.albedo, surfaceData.albedo) ) * 256.0h );
        #endif
    #endif
#endif

//  Simple deferred fuzzy lighting
    #if defined(_SIMPLEFUZZ)
    //  We just tweak the diffuse
        half NdotV = saturate(dot(inputData.normalWS, inputData.viewDirectionWS ));
        half fuzz = Fuzz(NdotV, _FuzzPower, _FuzzBias);
        fuzz *= additionalSurfaceData.fuzzMask * _FuzzStrength * PI;
        //half3 diffuse = brdfData.diffuse;
        //brdfData.diffuse *= 1.0h + fuzz; // * _FuzzAmbient;
        surfaceData.albedo *= 1.0h + fuzz; // * _FuzzAmbient;
    #endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
    half3 color = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
    return BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);
}