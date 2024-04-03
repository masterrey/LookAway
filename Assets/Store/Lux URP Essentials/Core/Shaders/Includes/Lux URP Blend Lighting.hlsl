#ifndef URP_BLENDLIGHTING_INCLUDED
#define URP_BLENDLIGHTING_INCLUDED

half4 LuxFragmentBlendPBR(InputData inputData, SurfaceData surfaceData, float3 shadowShift, float normalBlend)
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
    
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
//  Reduce SSAO according to normalBlend
    aoFactor.indirectAmbientOcclusion = lerp(surfaceData.occlusion, aoFactor.indirectAmbientOcclusion, normalBlend);
    aoFactor.directAmbientOcclusion = lerp(1, aoFactor.directAmbientOcclusion, normalBlend);    

    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfData, 0.0h,
        inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
        inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
    
#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
        lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfData, mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              0.0h, specularHighlightsOff);
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
                    lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfData, light,
                                                                                  inputData.normalWS, inputData.viewDirectionWS,
                                                                                  0.0h, specularHighlightsOff);
                }
            }
        #endif

    //  Add shadow shift for additional lights
        inputData.positionWS += shadowShift;

        LIGHT_LOOP_BEGIN(pixelLightCount)
        //  shadowShift is > 0 only for pixels around or below the intersection. So using inputData.positionWS + shadowShift should be ok.
            //Light light = GetAdditionalLight(lightIndex, inputData.positionWS + shadowShift);
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            
        #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
            {
                #if defined(_SCREEN_SPACE_OCCLUSION)
                    light.color *= aoFactor.directAmbientOcclusion;
                #endif
                lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfData, light,
                                                                            inputData.normalWS, inputData.viewDirectionWS,
                                                                            0.0h, specularHighlightsOff);
            }
        LIGHT_LOOP_END
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif
    
    return CalculateFinalColor(lightingData, surfaceData.alpha);
}
#endif