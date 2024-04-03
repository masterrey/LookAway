#ifndef LUX_LIT_GBUFFER_PASS_INCLUDED
#define LUX_LIT_GBUFFER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

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
    float2 texcoord1                    : TEXCOORD1;
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
        half3 vertexLighting            : TEXCOORD4;
    #endif
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord              : TEXCOORD5;
    #endif
    //#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    //    half3 viewDirTS                : TEXCOORD6;
    //#endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 6);

    float4 positionCS                   : SV_POSITION;

    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        float4 screenPos                : TEXCOORD7;
    #endif
    
    //half4 color                       : COLOR;
    half ambient                        : TEXCOORD8;
        
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

#include "Includes/Lux URP Tree Creator Library.hlsl"

// Include the surface function
#include "Includes/Lux URP Creator Leaves SurfaceData.hlsl"


//--------------------------------------
//  Vertex shader

Varyings LitGBufferPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//  Wind in ObjectSpace -------------------------------
    TreeVertLeaf(input);
//  End Wind -------------------------------

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.normalWS = normalInput.normalWS;
    #ifdef _NORMALMAP
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
        output.tangentWS = tangentWS;
    #endif
    
    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

    //OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    //#ifdef DYNAMICLIGHTMAP_ON
    //    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    //#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
        output.vertexLighting = vertexLight;
    #endif

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        output.positionWS = vertexInput.positionWS;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    //output.color = input.color;
    output.ambient = input.color.a;
    #if defined(BILLBOARD_FACE_CAMERA_POS) && defined(_ENABLEDITHERING)
        output.screenPos = ComputeScreenPos(output.positionCS);
    #endif


    return output;
}


//--------------------------------------
//  Fragment shader and functions

void InitializeInputData(Varyings input, half3 normalTS, half facing, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.positionCS = input.positionCS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

//  We are using the passed vertexnormal normalWS here!    
    #if defined(_NORMALMAP)
        #if !defined(_GBUFFERLIGHTING_SIMPLE) && !defined(_GBUFFERLIGHTING_VSNORMALS)
            normalTS.z *= facing;
        #endif
        float sgn = input.tangentWS.w;
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS;
        #if !defined(_GBUFFERLIGHTING_SIMPLE) && !defined(_GBUFFERLIGHTING_VSNORMALS)
            inputData.normalWS *= facing;
        #endif
    #endif

    #if defined (_GBUFFERLIGHTING_VSNORMALS)
        // From world to view space
        half3 normalVS = TransformWorldToViewDir(inputData.normalWS, true);
        // Now "flip" the normal
        normalVS.z = abs(normalVS.z);
        // From view to world space again
        inputData.normalWS = normalize( mul((float3x3)UNITY_MATRIX_I_V, normalVS) );
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
}



// Used in Standard (Physically Based) shader
FragmentOutput LitGBufferPassFragment(Varyings input, half facing : VFACE)
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

//  Tree Creator: Remap to GBuffer inputs
    surfaceData.smoothness = additionalSurfaceData.gloss;

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, facing, inputData);

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif
#endif

    #if defined(_GBUFFERLIGHTING_TRANSMISSION)
        uint meshRenderingLayers = GetMeshRenderingLayer();
        half4 shadowMask = CalculateShadowMask(inputData);
        AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        Light mainLight1 = GetMainLight(inputData, shadowMask, aoFactor);

        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(mainLight1.layerMask, meshRenderingLayers))
        #endif
            {
        
                #if defined(_SAMPLE_LIGHT_COOKIES)
                    real3 cookieColor = SampleMainLightCookie(inputData.positionWS);
                    mainLight1.color *= float4(cookieColor, 1);
                #endif

                half backContrib = saturate(dot(inputData.viewDirectionWS, -mainLight1.direction));
                half NoL = dot(inputData.normalWS, mainLight1.direction);
                backContrib = lerp(saturate(-NoL), backContrib, _TranslucencyViewDependency);
                half3 translucencyColor = _TranslucencyColor.rgb * backContrib * additionalSurfaceData.translucency;
                translucencyColor = translucencyColor * mainLight1.color * lerp(1, mainLight1.shadowAttenuation, _ShadowStrength);
            //  Let's somehow approximate this crazy forward lighting
                NoL = max(0, NoL * 0.6h + 0.4h);
                surfaceData.emission += surfaceData.albedo * translucencyColor * (2 - NoL);

                // Light unityLight;
                // unityLight = GetMainLight();
                // unityLight.distanceAttenuation = 1.0; //?

                // #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && Donedefined(_SURFACE_TYPE_TRANSPARENT)
                //     float4 shadowCoord = float4(screen_uv, 0.0, 1.0);
                // #else
                //     float4 shadowCoord = TransformWorldToShadowCoord(posWS.xyz);
                // #endif
                // unityLight.shadowAttenuation = MainLightShadow(shadowCoord, posWS.xyz, shadowMask, _MainLightOcclusionProbes);
            }
    #endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
    half3 color = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.normalWS, inputData.viewDirectionWS);

    return BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);
}

#endif