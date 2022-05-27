#ifndef URP_BLENDLIGHTING_INCLUDED
#define URP_BLENDLIGHTING_INCLUDED

half4 LuxFragmentBlendPBR(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha, float3 shadowShift)
{
    BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);
    
    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIllumination(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
    color += LightingPhysicallyBased(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS);

    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            
    //      shadowShift is > 0 only for pixels around or below the intersection. So using inputData.positionWS + shadowShift should be ok.
            Light light = GetAdditionalLight(lightIndex, inputData.positionWS + shadowShift);
            
    //        int perObjectLightIndex = GetPerObjectLightIndex(lightIndex);
            //#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
            //    float3 lightPositionWS = _AdditionalLightsBuffer[perObjectLightIndex].position.xyz;
            //#else
            //    float3 lightPositionWS = _AdditionalLightsPosition[perObjectLightIndex].xyz;
            //#endif
            //float3 lightDir = normalize(lightPositionWS - inputData.positionWS);
            // light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, inputData.positionWS + lightDir * shadowShift);
    //        light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, inputData.positionWS + shadowShift);
            color += LightingPhysicallyBased(brdfData, light, inputData.normalWS, inputData.viewDirectionWS);
        }
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        color += inputData.vertexLighting * brdfData.diffuse;
    #endif
    
    color += emission;
    return half4(color, alpha);
}
#endif