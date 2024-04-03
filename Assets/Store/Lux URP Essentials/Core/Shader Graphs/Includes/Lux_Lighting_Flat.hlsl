//#if !defined(SHADERGRAPH_PREVIEW)
#if !defined(SHADERGRAPH_PREVIEW) || defined(UNIVERSAL_LIGHTING_INCLUDED)

//  As we do not have access to the vertex lights we will make the shder always sample add lights per pixel
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        #undef _ADDITIONAL_LIGHTS_VERTEX
        #define _ADDITIONAL_LIGHTS
    #endif
#endif


void Lighting_half(

//  Base inputs
    float3 positionWS,
    float4 positionSP,
    half3 viewDirectionWS,

    half3 tangentWS,
    half3 bitangentWS,

//  Surface description
    half3 albedo,

    bool enableNormalTS,
    half3 normalTS,

    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,
 
    float2 lightMapUV,
    float2 dynamicLightMapUV,

//  Final lit color
    out half3 FinalLighting,
    out half3 MetaAlbedo,
    out half3 MetaSpecular,
    out half  MetaSmoothness,
    out half  MetaOcclusion,
    out half3 MetaNormal
)
{

//#if defined(SHADERGRAPH_PREVIEW)
#if defined(SHADERGRAPH_PREVIEW) || ( !defined(LIGHTWEIGHT_LIGHTING_INCLUDED) && !defined(UNIVERSAL_LIGHTING_INCLUDED) )
    FinalLighting = albedo;
    MetaAlbedo = half3(0,0,0);
    MetaSpecular = half3(0,0,0);
    MetaSmoothness = 0;
    MetaOcclusion = 0;
    MetaNormal = half3(0,0,1);
#else

//  Real Lighting ----------

    #if defined(_SPECULARHIGHLIGHTS_OFF)
        bool specularHighlightsOff = true;
    #else
        bool specularHighlightsOff = false;
    #endif

    half metallic = 0;

//  Create custom per vertex normal // SafeNormalize does not work here on Android?!
    half3 tnormal = normalize(cross(ddy(positionWS), ddx(positionWS)));
//  TODO: Vulkan on Android here shows inverted normals?
    // #if defined(SHADER_API_VULKAN)
    //     tnormal *= -1;
    // #endif

    if(enableNormalTS)
    {
    //  Adjust tangentWS as we have tweaked normalWS
        tangentWS = Orthonormalize(tangentWS, tnormal);
        half3x3 tangentToWorld = half3x3(tangentWS, bitangentWS, tnormal);
        tnormal = TransformTangentToWorld(normalTS, tangentToWorld);
        tnormal = normalize(tnormal);
    }

    half3 normalWS = tnormal;
    viewDirectionWS = SafeNormalize(viewDirectionWS);

//  GI Lighting
//  We are using the base normalWS here. So decal normals will not affect GI like in all other shaders.
    half3 bakedGI;
    #ifdef LIGHTMAP_ON
        #if defined(DYNAMICLIGHTMAP_ON)
            dynamicLightMapUV = dynamicLightMapUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            bakedGI = SAMPLE_GI(lightMapUV, dynamicLightMapUV, half3(0,0,0), normalWS);
        #else
            lightMapUV = lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
            bakedGI = SAMPLE_GI(lightMapUV, half3(0,0,0), normalWS);
        #endif
    #else
        bakedGI = SampleSH(normalWS); 
    #endif

//  Fill standard URP structs so we can use the built in functions
    InputData inputData = (InputData)0;
    {
        inputData.positionWS = positionWS;
        inputData.normalWS = normalWS;
        inputData.viewDirectionWS = viewDirectionWS;
        inputData.bakedGI = bakedGI;
        #if _MAIN_LIGHT_SHADOWS_SCREEN
        //  Here we need raw
            inputData.shadowCoord = positionSP;
        #else
            inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
        #endif
        //  Apply perspective division
        inputData.normalizedScreenSpaceUV = positionSP.xy * rcp(positionSP.w);
        inputData.shadowMask = SAMPLE_SHADOWMASK(lightMapUV);
    }
    SurfaceData surfaceData = (SurfaceData)0;
    {
        surfaceData.alpha = alpha;
        surfaceData.albedo = albedo;
        surfaceData.metallic = metallic;
        surfaceData.specular = specular;
        surfaceData.smoothness = smoothness;
        surfaceData.occlusion = occlusion;
        surfaceData.normalTS = normalTS;   
    }
//  END: structs

//  Decals
    #if defined(_CUSTOMDBUFFER)
        float2 positionCS = inputData.normalizedScreenSpaceUV * _ScreenSize.xy;
        ApplyDecalToSurfaceData(float4(positionCS, 0, 0), surfaceData, inputData);
    #endif

//  From here on we rely on surfaceData and inputData only! (except debug which outputs the original values)

    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

//  Debugging
    #if defined(DEBUG_DISPLAY)
        half4 debugColor;
        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
        {
            //return debugColor;
            FinalLighting = debugColor.rgb;
            MetaAlbedo = debugColor.rgb;
            MetaSpecular = specular;
            MetaSmoothness = smoothness;
            MetaOcclusion = occlusion;
            MetaNormal = normalWS;
        }
    #else

        half4 shadowMask = CalculateShadowMask(inputData);
        AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        uint meshRenderingLayers = GetMeshRenderingLayer();

        Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);
        LightingData lightingData = CreateLightingData(inputData, surfaceData);

    //  In order to use probe blending and proper AO we have to use the new GlobalIllumination function
        lightingData.giColor = GlobalIllumination(
            brdfData,
            brdfData,   // brdfDataClearCoat,
            0,          // surfaceData.clearCoatMask
            inputData.bakedGI,
            aoFactor.indirectAmbientOcclusion,
            inputData.positionWS,
            inputData.normalWS,
            inputData.viewDirectionWS,
            inputData.normalizedScreenSpaceUV
        );

    //  Main Light
        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
            {
        #endif
                lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfData,
                                                              mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff);
        #if defined(_LIGHT_LAYERS)
            }
        #endif

    //  Add Lights
        #ifdef _ADDITIONAL_LIGHTS
            uint pixelLightCount = GetAdditionalLightsCount();

                #if USE_FORWARD_PLUS
                    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
                    {
                        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
                        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
                        #ifdef _LIGHT_LAYERS
                            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                        #endif
                        {
                            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfData, light,
                                                                        inputData.normalWS, inputData.viewDirectionWS,
                                                                        surfaceData.clearCoatMask, specularHighlightsOff);
                        }
                    }
                #endif

            LIGHT_LOOP_BEGIN(pixelLightCount)    
                    Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
                #if defined(_LIGHT_LAYERS)
                    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                    {
                #endif
                        lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfData, light,
                                                                        inputData.normalWS, inputData.viewDirectionWS,
                                                                        surfaceData.clearCoatMask, specularHighlightsOff);
                #if defined(_LIGHT_LAYERS)
                    }
                #endif
            LIGHT_LOOP_END
        #endif

        FinalLighting = CalculateFinalColor(lightingData, surfaceData.alpha).xyz;

    //  Set Albedo for meta pass
        #if defined(UNIVERSAL_LIT_META_PASS_INCLUDED)
            FinalLighting = half3(0,0,0);
            MetaAlbedo = albedo;
            MetaSpecular = specular;
            MetaSmoothness = 0;
            MetaOcclusion = 0;
            MetaNormal = half3(0,0,1);
        #else
            MetaAlbedo = half3(0,0,0);
            MetaSpecular = half3(0,0,0);
            MetaSmoothness = 0;
            MetaOcclusion = 0;
        //  Needed by DepthNormalOnly pass
            MetaNormal = normalWS;
        #endif

    #endif  // end Debugging

#endif
}

// Unity 2019.1. needs a float version

void Lighting_float(

//  Base inputs
    float3 positionWS,
    float4 positionSP,
    half3 viewDirectionWS,

    half3 tangentWS,
    half3 bitangentWS,

//  Surface description
    half3 albedo,
    
    bool enableNormalTS,
    half3 normalTS,

    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,


    float2 lightMapUV,
    float2 dynamicLightMapUV,
 

//  Final lit color
    out half3 Lighting,
    out half3 MetaAlbedo,
    out half3 MetaSpecular,
    out half  MetaSmoothness,
    out half  MetaOcclusion,
    out half3 MetaNormal
)
{
    Lighting_half(
        positionWS, positionSP, viewDirectionWS, tangentWS, bitangentWS,
        albedo, enableNormalTS, normalTS, specular, smoothness, occlusion, alpha,
        lightMapUV, dynamicLightMapUV,
        Lighting, MetaAlbedo, MetaSpecular, MetaSmoothness, MetaOcclusion, MetaNormal
    );
}