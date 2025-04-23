#ifndef URP_TRANSLUCENTLIGHTING_INCLUDED
#define URP_TRANSLUCENTLIGHTING_INCLUDED


half3 GlobalIllumination_Lux(BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS, 
    half specOccluison)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion)        * specOccluison;

    return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}


half3 LightingPhysicallyBasedWrapped(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL, bool specularHighlightsOff)
{
//  NdotL is wrapped... not correct for specular
    half3 radiance = lightColor * (lightAttenuation * NdotL);
    
    #if UNITY_VERSION >= 202310
        half3 brdf = brdfData.diffuse;
        #ifndef _SPECULARHIGHLIGHTS_OFF
            [branch] if (!specularHighlightsOff)
            {
                brdf += brdfData.specular * DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS);
            }
        #endif
        return brdf * radiance;
    #else 
        return DirectBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
    #endif
}

half3 LightingPhysicallyBasedWrapped(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS, half NdotL, bool specularHighlightsOff)
{
    return LightingPhysicallyBasedWrapped(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, NdotL, specularHighlightsOff);
}

half4 LuxURPTranslucentFragmentPBR(InputData inputData, SurfaceData surfaceData,
    half4 translucency, half AmbientReflection
    #if defined(_CUSTOMWRAP)
        , half wrap
    #endif
    #if defined(_STANDARDLIGHTING)
        , half mask
    #endif
    , half maskbyshadowstrength
)
{
    
    #if defined(_SPECULARHIGHLIGHTS_OFF)
        bool specularHighlightsOff = true;
    #else
        bool specularHighlightsOff = false;
    #endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

//  Debugging
    #if defined(DEBUG_DISPLAY)
        half4 debugColor;
        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
        {
            return debugColor;
        }
    #endif

    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();

    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    half3 mainLightColor = mainLight.color;
    
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

    #if defined(_CUSTOMWRAP)
        half w = wrap;
        #if defined(_STANDARDLIGHTING)
             w *= mask;
        #endif
    #else
        half w = 0.4;
    #endif
    half WrappedNormalization = rcp((1.0h + w) * (1.0h + w));
    half NdotL;

    half3 translucencyColor = (_OverrideTransmission) ? _TransmissionColor.xyz : brdfData.diffuse;

    #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
        {
    
        //  Wrapped Diffuse   
            NdotL = saturate((dot(inputData.normalWS, mainLight.direction) + w) * WrappedNormalization );
            lightingData.mainLightColor = LightingPhysicallyBasedWrapped(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL, specularHighlightsOff);
        
        //  Translucency
            half transPower = translucency.y;
            half3 transLightDir = mainLight.direction + inputData.normalWS * translucency.w;
            half transDot = dot( transLightDir, -inputData.viewDirectionWS );
            transDot = exp2(saturate(transDot) * transPower - transPower);
            lightingData.mainLightColor +=
                #if defined(_STANDARDLIGHTING)
                    mask *
                #endif
                transDot * (1.0 - NdotL) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, translucency.z) * translucencyColor * translucency.x;
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
                //  Wrapped Diffuse
                    NdotL = saturate((dot(inputData.normalWS, light.direction) + w) * WrappedNormalization );
                    lightingData.additionalLightsColor += LightingPhysicallyBasedWrapped(
                        brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL, specularHighlightsOff);
                //  Translucency
                    half3 lightColor = light.color;
                //  Mask by incoming shadow strength
                    int index = lightIndex;
                    
                    half4 shadowParams = GetAdditionalLightShadowParams(index);
                    #if !defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
                        lightColor *= lerp(1, 0, maskbyshadowstrength);
                    #else
                    //  half isPointLight = shadowParams.z;
                        lightColor *= lerp(1, shadowParams.x, maskbyshadowstrength);
                    #endif
                //  Apply Translucency
                    half transPower = translucency.y;
                    half3 transLightDir = light.direction + inputData.normalWS * translucency.w;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);
                    lightingData.additionalLightsColor += 
                        #if defined(_STANDARDLIGHTING)
                            mask *
                        #endif
                        translucencyColor * transDot * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation  * translucency.x;
                }
            }
        #endif

        LIGHT_LOOP_BEGIN(pixelLightCount)    
                Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            #if defined(_LIGHT_LAYERS)
                if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
                {
                //  Wrapped Diffuse
                    NdotL = saturate((dot(inputData.normalWS, light.direction) + w) * WrappedNormalization );
                    lightingData.additionalLightsColor += LightingPhysicallyBasedWrapped(
                        brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL, specularHighlightsOff);
                
                //  Translucency
                    half3 lightColor = light.color;
                
                //  Mask by incoming shadow strength
                    #if USE_FORWARD_PLUS
                        int index = lightIndex;
                    #else
                        int index = GetPerObjectLightIndex(lightIndex);
                    #endif

                    half4 shadowParams = GetAdditionalLightShadowParams(index);
                    #if !defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
                        lightColor *= lerp(1, 0, maskbyshadowstrength);
                    #else
                    //  half isPointLight = shadowParams.z;
                        lightColor *= lerp(1, shadowParams.x, maskbyshadowstrength);
                    #endif
                
                //  Apply Translucency
                    half transPower = translucency.y;
                    half3 transLightDir = light.direction + inputData.normalWS * translucency.w;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);
                    lightingData.additionalLightsColor += 
                        #if defined(_STANDARDLIGHTING)
                            mask *
                        #endif
                        translucencyColor * transDot * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation  * translucency.x;
                }
        LIGHT_LOOP_END
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif
    return CalculateFinalColor(lightingData, surfaceData.alpha);
}
#endif