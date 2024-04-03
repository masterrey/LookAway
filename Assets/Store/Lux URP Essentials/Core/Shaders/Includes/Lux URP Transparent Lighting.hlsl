#ifndef LIGHTWEIGHT_TRANSPARENTLIGHTING_INCLUDED
#define LIGHTWEIGHT_TRANSPARENTLIGHTING_INCLUDED

half4 LuxURPTransparentFragmentPBR(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha
)
{
    BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);

    half4 shadowMask = CalculateShadowMask(inputData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
//  Dummy AO
    AmbientOcclusionFactor aoFactor;
    aoFactor.indirectAmbientOcclusion = 1;
    aoFactor.directAmbientOcclusion = 1;

    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIllumination(brdfData, brdfData, 0,
        inputData.bakedGI, occlusion, inputData.positionWS,
        inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);

#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
    //  GetMainLight will return screen space shadows.
        #if defined(_MAIN_LIGHT_SHADOWS)
            ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
            half shadowStrength = GetMainLightShadowStrength();
            //mainLight.shadowAttenuation = SampleShadowmap(inputData.shadowCoord, TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowSamplingData, shadowStrength, false);
        //  New sampler since URP 14.0.7
            mainLight.shadowAttenuation = SampleShadowmap(inputData.shadowCoord, TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_LinearClampCompare), shadowSamplingData, shadowStrength, false);
        #endif
        color += LightingPhysicallyBased(brdfData, brdfData, mainLight,
            inputData.normalWS, inputData.viewDirectionWS,
            0.0f, false);
    }

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
                    color += LightingPhysicallyBased(brdfData, brdfData, light,
                        inputData.normalWS, inputData.viewDirectionWS,
                        0.0f, false);
                }
            }
        #endif

        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
        #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
            {
                color += LightingPhysicallyBased(brdfData, brdfData, light,
                    inputData.normalWS, inputData.viewDirectionWS,
                    0.0f, false);

                //color = light.shadowAttenuation;
            }
        LIGHT_LOOP_END

    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        color += inputData.vertexLighting * brdfData.diffuse;
    #endif

    color += emission;

    return half4(color, alpha);
}
#endif