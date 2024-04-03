

#ifndef UNIVERSAL_SKINLIGHTING_INCLUDED
#define UNIVERSAL_SKINLIGHTING_INCLUDED


TEXTURE2D(_SkinLUT); SAMPLER(sampler_SkinLUT); float4 _SkinLUT_TexelSize;

half3 GlobalIllumination_Lux(BRDFData brdfData, half3 bakedGI, half occlusion, float3 positionWS, half3 normalWS, half3 viewDirectionWS, float2 normalizedScreenSpaceUV,
    half specOcclusion)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(
        reflectVector, positionWS, brdfData.perceptualRoughness, occlusion, normalizedScreenSpaceUV) * specOcclusion;

    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

//  Debug
    if (IsOnlyAOLightingFeatureEnabled())
    {
        color = occlusion.xxx; // "Base white" for AO debug lighting mode // Lux: We return occlusion here
    }

    return color;
}


half3 LightingPhysicallyBasedSkin(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL, half NdotLUnclamped, half curvature, half skinMask)
{
    //half3 radiance = lightColor * NdotL;
    half3 diffuseLighting = brdfData.diffuse * SAMPLE_TEXTURE2D_LOD(_SkinLUT, sampler_SkinLUT, float2( (NdotLUnclamped * 0.5 + 0.5), curvature), 0).rgb;
    diffuseLighting = lerp(brdfData.diffuse * NdotL, diffuseLighting, skinMask);
    // return ( DirectBDRF_Lux(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * NdotL + diffuseLighting ) * lightColor * lightAttenuation;
    #ifndef _SPECULARHIGHLIGHTS_OFF
        half specularTerm = DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS);
        return ( specularTerm * brdfData.specular * NdotL + diffuseLighting ) * lightColor * lightAttenuation;
    #else
        return diffuseLighting * lightColor * lightAttenuation;
    #endif
}

half3 LightingPhysicallyBasedSkin(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS, half NdotL, half NdotLUnclamped, half curvature, half skinMask)
{
    return LightingPhysicallyBasedSkin(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);
}


half4 LuxURPSkinFragmentPBR(InputData inputData, SurfaceData surfaceData,
    half4 translucency, half AmbientReflection, half3 diffuseNormalWS, half3 subsurfaceColor, half curvature, half skinMask, half maskbyshadowstrength, half backScatter)
{
    
    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
        half4 debugColor;
        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor)) {
            return debugColor;
        }
    #endif

    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    // MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);
    MixRealtimeAndBakedGI(mainLight, diffuseNormalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination_Lux(
        brdfData, inputData.bakedGI, aoFactor.indirectAmbientOcclusion,
        inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV, AmbientReflection
    );
//  Backscattering
    #if defined(_BACKSCATTER) && !defined(DEBUG_DISPLAY)
        lightingData.giColor += backScatter * SampleSH(-diffuseNormalWS) * surfaceData.albedo * aoFactor.indirectAmbientOcclusion * translucency.x * subsurfaceColor * skinMask;
    #endif
    
    #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif    
        {
            half3 mainLightColor = mainLight.color;
            half NdotLUnclamped = dot(diffuseNormalWS, mainLight.direction);
            half NdotL = saturate( dot(inputData.normalWS, mainLight.direction) );
            lightingData.mainLightColor = LightingPhysicallyBasedSkin(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);
        
        //  Subsurface Scattering
            half transPower = translucency.y;
            half3 transLightDir = mainLight.direction + inputData.normalWS * translucency.w;
            half transDot = dot( transLightDir, -inputData.viewDirectionWS );
            transDot = exp2(saturate(transDot) * transPower - transPower);
            lightingData.mainLightColor += skinMask * subsurfaceColor * transDot * (1.0 - saturate(NdotLUnclamped)) * mainLightColor * lerp(1.0, mainLight.shadowAttenuation, translucency.z) * translucency.x;
    
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
                    half3 lightColor = light.color;
                    half NdotLUnclamped = dot(diffuseNormalWS, light.direction);
                    half NdotL = saturate( dot(inputData.normalWS, light.direction) );
                    lightingData.additionalLightsColor += LightingPhysicallyBasedSkin(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);
                
                //  Subsurface Scattering
                    int index = lightIndex;
                    half4 shadowParams = GetAdditionalLightShadowParams(index);
                    #if !defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
                        lightColor *= lerp(1, 0, maskbyshadowstrength);
                    #else
                    //  half isPointLight = shadowParams.z;
                        lightColor *= lerp(1, shadowParams.x, maskbyshadowstrength);
                    #endif

                    half transPower = translucency.y;
                    half3 transLightDirA = light.direction + inputData.normalWS * translucency.w;
                    half transDotA = dot( transLightDirA, -inputData.viewDirectionWS );
                    transDotA = exp2(saturate(transDotA) * transPower - transPower);
                    lightingData.additionalLightsColor += skinMask * subsurfaceColor * transDotA * (1.0 - saturate(NdotLUnclamped)) * lightColor * lerp(1.0, light.shadowAttenuation, translucency.z) * light.distanceAttenuation * translucency.x;
                }
            }
        #endif


        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            
        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
            {
                half3 lightColor = light.color;
                half NdotLUnclamped = dot(diffuseNormalWS, light.direction);
                half NdotL = saturate( dot(inputData.normalWS, light.direction) );
                lightingData.additionalLightsColor += LightingPhysicallyBasedSkin(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);
            
            //  Subsurface Scattering
                int index = lightIndex;
                //int index = GetPerObjectLightIndex(lightIndex);
                half4 shadowParams = GetAdditionalLightShadowParams(index);
                #if !defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
                    lightColor *= lerp(1, 0, maskbyshadowstrength);
                #else
                //	half isPointLight = shadowParams.z;
                    lightColor *= lerp(1, shadowParams.x, maskbyshadowstrength);
                #endif

                half transPower = translucency.y;
                half3 transLightDirA = light.direction + inputData.normalWS * translucency.w;
                half transDotA = dot( transLightDirA, -inputData.viewDirectionWS );
                transDotA = exp2(saturate(transDotA) * transPower - transPower);
                lightingData.additionalLightsColor += skinMask * subsurfaceColor * transDotA * (1.0 - saturate(NdotLUnclamped)) * lightColor * lerp(1.0, light.shadowAttenuation, translucency.z) * light.distanceAttenuation * translucency.x;
            }
        LIGHT_LOOP_END
    #endif
    
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

#endif