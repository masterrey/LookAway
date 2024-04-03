#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs

struct Attributes
{
    float4 positionOS                   : POSITION;
    float2 texcoord                     : TEXCOORD0;
    float3 normalOS                     : NORMAL;
    float4 tangentOS                    : TANGENT;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                           : TEXCOORD0;
    float3 positionWS                   : TEXCOORD1;

//  Do not get fooled here: _NORMALMAP here means "Lighting"
    #if defined(_NORMALMAP)
        half3 normalWS                  : TEXCOORD2;
        half4 tangentWS                 : TEXCOORD3;
    #endif
    #if defined(_ADDITIONAL_LIGHTS_VERTEX) && defined(_NORMALMAP)
        half4 fogFactorAndVertexLight   : TEXCOORD4;
    #else
        half  fogFactor                 : TEXCOORD4;
    #endif
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord              : TEXCOORD5;
    #endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 6);
    #ifdef DYNAMICLIGHTMAP_ON
        float2  dynamicLightmapUV       : TEXCOORD7;
    #endif

    float4 positionCS                   : SV_POSITION;

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
#include "Includes/Lux URP Billboard SurfaceData.hlsl"


//--------------------------------------
//  Vertex shader

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//  Instance world position
    float3 positionWS = float3(UNITY_MATRIX_M[0].w, UNITY_MATRIX_M[1].w, UNITY_MATRIX_M[2].w);

    #if !defined(_UPRIGHT)
        input.positionOS = float4(0,0,0,1);
        #if defined(_PIVOTTOBOTTOM)
            input.positionOS.xy = input.texcoord.xy - float2(0.5, 0.0);
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

        #if defined(_NORMALMAP)
        //  we have to make the normal point towards the cam
            half3 viewDirWS = normalize(GetCameraPositionWS() - positionWS); // half3
            half3 billboardTangentWS = normalize(half3(-viewDirWS.z, 0, viewDirWS.x));
            #if defined(_NORMALMAP)
                half3 billboardNormalWS = viewDirWS; //float3(billboardTangentWS.z, 0, -billboardTangentWS.x);
            #endif
        #endif
        
    #else
        float3 viewDirWS = normalize(GetCameraPositionWS() - positionWS); // float3
        float3 billboardTangentWS = normalize(float3(-viewDirWS.z, 0, viewDirWS.x));
        #if defined(_NORMALMAP)
            half3 billboardNormalWS = float3(billboardTangentWS.z, 0, -billboardTangentWS.x);
        #endif
        
    //  Expand Billboard
        float2 percent = input.texcoord.xy;
        float3 billboardPos = (percent.x - 0.5) * _Shrink * billboardTangentWS;
        #if defined(_PIVOTTOBOTTOM)
            billboardPos.y += percent.y;
        #else
            billboardPos.y += percent.y - 0.5;
        #endif
        output.positionWS = TransformObjectToWorld(billboardPos).xyz;
        output.positionCS = TransformWorldToHClip(output.positionWS);
    #endif

    output.uv = input.texcoord.xy;
    output.uv.x = (output.uv.x - 0.5) * _Shrink + 0.5;

    half fogFactor = ComputeFogFactor(output.positionCS.z);

//  Do not get fooled here: _NORMALMAP here means "Lighting"
    #if defined(_NORMALMAP)
        output.normalWS = billboardNormalWS;
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(billboardTangentWS, sign);
    
        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            VertexPositionInputs vertexInput = (VertexPositionInputs)0;
            vertexInput.positionCS = output.positionCS;
            vertexInput.positionWS = output.positionWS;
        //  We have to call the new function for screen space shadows:
            output.shadowCoord = GetShadowCoord(vertexInput);
        #endif

        OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
        OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
    #endif

    
//  #ifdef _ADDITIONAL_LIGHTS_VERTEX
    #if defined(_ADDITIONAL_LIGHTS_VERTEX) && defined (_NORMALMAP)
        half3 vertexLight = VertexLighting(output.positionWS, output.normalWS);
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    #else
        output.fogFactor = fogFactor;
    #endif

//  Placeholder
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

    return output;
}

//--------------------------------------
//  Fragment shader and functions

#ifdef _NORMALMAP
    void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
    {
        inputData = (InputData)0;
        
        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            inputData.positionWS = input.positionWS;
        #endif
        
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
        //#ifdef _NORMALMAP
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
        //#else
        //    inputData.normalWS = input.normalWS;
        //#endif

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
#endif


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
    InitializeSurfaceData(input, surfaceData);

//  Lit version
    #ifdef _NORMALMAP
    //  Prepare surface data
        InputData inputData;
        InitializeInputData(input, surfaceData.normalTS, inputData);
    //  We have to sample SH per pixel
        inputData.bakedGI = SampleSH(inputData.normalWS);
        outColor = UniversalFragmentPBR(inputData, surfaceData);

//  Unlit version
    #else 
        outColor = half4(surfaceData.albedo, surfaceData.alpha);
    #endif

//  Add fog

    #if defined(_ADDITIONAL_LIGHTS_VERTEX) && defined(_NORMALMAP)
        #define foginput input.fogFactorAndVertexLight.x
    #else 
        #define foginput input.fogFactor
    #endif

    #if defined(_APPLYFOGADDITIVELY)
        outColor.rgb = MixFogColor(outColor.rgb, half3(0, 0, 0), foginput);
    #endif
    #if defined(_APPLYFOG)
        outColor.rgb = MixFog(outColor.rgb, foginput);
    #endif

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}