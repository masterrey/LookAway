

real GI_Luminance(real3 linearRgb)
{
    return dot(linearRgb, real3(0.2126729, 0.7151522, 0.0721750));
}

// Horizon Occlusion for Normal Mapped Reflections: http://marmosetco.tumblr.com/post/81245981087
half LuxGetHorizonOcclusion(half3 R, half3 normalWS, half3 vertexNormal, half horizonFade)
{
    //half3 R = reflect(-V, normalWS);
    half specularOcclusion = saturate(1.0 + horizonFade * dot(R, vertexNormal));
    // smooth it
    return specularOcclusion * specularOcclusion;
}
  



half3 LuxExtended_GlobalIllumination(
    BRDFData brdfData, half3 bakedGI, half occlusion, float3 positionWS, half3 normalWS, half3 viewDirectionWS, float2 normalizedScreenSpaceUV,
    half GItoAO, half GItoAOBias, half3 bentNormal, half3 geoNormalWS, half horizonOcllusion)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);

    half3 indirectDiffuse = bakedGI * occlusion;

    half reflOcclusion = 1;
    #if defined(_BENTNORMAL)
        reflOcclusion = saturate(dot(normalWS, bentNormal));
        /*
        occlusion = sqrt(1.0 - saturate(occlusion/reflOcclusion));
        occlusion = TWO_PI *  (1.0 - occlusion);
        occlusion = saturate(occlusion * INV_FOUR_PI);
        reflOcclusion = 1;
        */
    #endif

//  Horizon Occlusion
    #if defined (_SAMPLENORMAL) && defined(_UBER)
        reflOcclusion *= LuxGetHorizonOcclusion( reflectVector, normalWS, geoNormalWS, horizonOcllusion);
    #endif

//  AO from lightmap
    #if defined(LIGHTMAP_ON) && defined(_ENABLE_AO_FROM_GI)
        half specOcclusion = saturate( GI_Luminance(bakedGI) * GItoAO + GItoAOBias);
        half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, half(1.0), normalizedScreenSpaceUV) * reflOcclusion * occlusion * specOcclusion;
    #else
        half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, half(1.0), normalizedScreenSpaceUV) * reflOcclusion * occlusion;
    #endif

    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

//  Debug
    if (IsOnlyAOLightingFeatureEnabled())
    {
        color = occlusion.xxx; // "Base white" for AO debug lighting mode // Lux: We return occlusion here
    }

    return color;
}



half4 LuxExtended_UniversalFragmentPBR(InputData inputData, SurfaceData surfaceData,
    half GItoAO, half GItoAOBias, half3 bentNormal, half3 geoNormalWS, half horizonOcllusion
    )
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;
    
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    BRDFData brdfDataClearCoat = (BRDFData)0;
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    //uint meshRenderingLayers = GetMeshRenderingLightLayer();
// urp 14
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    // lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
    //                                            inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
    //                                            inputData.normalWS, inputData.viewDirectionWS);

    lightingData.giColor = LuxExtended_GlobalIllumination(
        brdfData,
        inputData.bakedGI,
        aoFactor.indirectAmbientOcclusion,
        inputData.positionWS,
        inputData.normalWS,
        inputData.viewDirectionWS,
        inputData.normalizedScreenSpaceUV,

        GItoAO, GItoAOBias, bentNormal, geoNormalWS, horizonOcllusion
    );


    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfDataClearCoat,
                                                              mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff);
    }

    #if defined(_ADDITIONAL_LIGHTS)
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
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}