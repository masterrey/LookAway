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

//  Not supported in URP - and not needed :)
    // #if defined(SHADER_STAGE_FRAGMENT)
    //     FRONT_FACE_TYPE cullFace        : FRONT_FACE_SEMANTIC;
    // #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


// Include the surface function
#include "Includes/Lux URP Billboard SurfaceData.hlsl"

Varyings LitGBufferPassVertex (Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//  Instance world position
    float3 positionWS = float3(UNITY_MATRIX_M[0].w, UNITY_MATRIX_M[1].w, UNITY_MATRIX_M[2].w);

    #if !defined(_UPRIGHT)
        input.positionOS.xyz = 0;
        #if defined(_PIVOTTOBOTTOM)
            input.positionOS.xy = input.texcoord.xy - float2(0.5f, 0.0f);
        #else
            input.positionOS.xy = input.texcoord.xy - 0.5;
        #endif
        input.positionOS.x *= _Shrink;

        float2 scale;
    //  Using unity_ObjectToWorld may break. So we use the official function.
        scale.x = length(float3(UNITY_MATRIX_M[0].x, UNITY_MATRIX_M[1].x, UNITY_MATRIX_M[2].x));
        scale.y = length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y));

        //float4 positionVS = mul(UNITY_MATRIX_MV, float4(0, 0, 0, 1.0));
        float4 positionVS = mul(UNITY_MATRIX_V, float4(UNITY_MATRIX_M._m03_m13_m23, 1.0));
        positionVS.xyz += input.positionOS.xyz * float3(scale.xy, 1.0);
        output.positionCS = mul(UNITY_MATRIX_P, positionVS);
        output.positionWS = mul(UNITY_MATRIX_I_V, positionVS).xyz;

    //  we have to make the normal point towards the cam
        half3 viewDirWS = normalize(GetCameraPositionWS() - positionWS); // half3
        half3 billboardTangentWS = normalize(float3(-viewDirWS.z, 0, viewDirWS.x));
        half3 billboardNormalWS = viewDirWS; //float3(billboardTangentWS.z, 0, -billboardTangentWS.x);
        
    #else
        float3 viewDirWS = normalize(GetCameraPositionWS() - positionWS); // float3
        float3 billboardTangentWS = normalize(float3(-viewDirWS.z, 0, viewDirWS.x));
        half3 billboardNormalWS = float3(billboardTangentWS.z, 0, -billboardTangentWS.x);
        
    //  Expand Billboard
        float2 percent = input.texcoord.xy;
        float3 billboardPos = (percent.x - 0.5f) * _Shrink * billboardTangentWS;
        #if defined(_PIVOTTOBOTTOM)
            billboardPos.y += percent.y;
        #else
            billboardPos.y += percent.y - 0.5f;
        #endif
        output.positionWS = TransformObjectToWorld(billboardPos).xyz;
        output.positionCS = TransformWorldToHClip(output.positionWS);
    #endif

    output.uv = input.texcoord.xy;
    output.uv.x = (output.uv.x - 0.5f) * _Shrink + 0.5f;

    output.normalWS = billboardNormalWS;
    #ifdef _NORMALMAP
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(billboardTangentWS, sign);
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        VertexPositionInputs vertexInput = (VertexPositionInputs)0;
        vertexInput.positionCS = output.positionCS;
        vertexInput.positionWS = output.positionWS;
    //  We have to call the new function for screen space shadows:
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

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
//  Get the surface description
    InitializeSurfaceData(input, surfaceData);

//  Transfer all to world space 
    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.positionCS = input.positionCS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    #if defined(_NORMALMAP)
        float sgn = input.tangentWS.w;
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(surfaceData.normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
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

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
    half3 color = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
    return BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);
}