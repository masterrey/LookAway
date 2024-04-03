// NOTE: Based on URP Lighting.hlsl which replaced some half3 with floats to avoid lighting artifacts on mobile

#ifndef LIGHTWEIGHT_FUZZLIGHTING_INCLUDED
#define LIGHTWEIGHT_FUZZHLIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

real Fuzz(real NdotV, real fuzzPower, real fuzzBias)
{
    return exp2( (1.0h - NdotV) * fuzzPower - fuzzPower) + fuzzBias;
}

real WrappedDiffuse(real NdotL, real3 normalWS, real3 lightDirectionWS, real wrap)
{
    return saturate( (dot(normalWS, lightDirectionWS) + wrap) * rcp( (1.0h + wrap) * (1.0h + wrap) ) );
}

// ---------

struct AdditionalData {
    half    fuzzWrap;
    half    fuzz;
};

half3 DirectBDRF_LuxFuzz(BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, half NdotL)
{
//  Regular Code
    #ifndef _SPECULARHIGHLIGHTS_OFF
        float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
        float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

        float NoH = saturate(dot(float3(normalWS), halfDir));
        half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

    //  Standard specular lighting
        float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;
        //half d2 = half(d * d);
        half LoH2 = LoH * LoH;
        //half specularTerm = brdfData.roughness2 / (d2 * max(half(0.1), LoH2) * brdfData.normalizationTerm);
        half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);
        #if REAL_IS_HALF
            specularTerm = specularTerm - HALF_MIN;
            specularTerm = clamp(specularTerm, 0.0, 1000.0); // Prevent FP16 overflow on mobiles
        #endif

        return specularTerm * brdfData.specular + brdfData.diffuse;
    #else
        return brdfData.diffuse;
    #endif
}

half3 LightingPhysicallyBased_LuxFuzz(BRDFData brdfData,
    #if defined(_SIMPLEFUZZ)
        AdditionalData addData,
    #endif
    half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL)
{
    half3 radiance = lightColor * (lightAttenuation * NdotL);
    #if defined(_SIMPLEFUZZ)
        half wrappedNdotL = WrappedDiffuse(NdotL, normalWS, lightDirectionWS, addData.fuzzWrap);
    #endif

    return DirectBDRF_LuxFuzz(brdfData, normalWS, lightDirectionWS, viewDirectionWS, NdotL) * radiance 
    #if defined(_SIMPLEFUZZ)
          + (addData.fuzz * brdfData.diffuse) * lightColor * (lightAttenuation * wrappedNdotL )
    #endif
    ;
}

half3 LightingPhysicallyBased_LuxFuzz(BRDFData brdfData,
    #if defined(_SIMPLEFUZZ)
        AdditionalData addData,
    #endif
    Light light, half3 normalWS, half3 viewDirectionWS, half NdotL)
{
    return LightingPhysicallyBased_LuxFuzz(brdfData,
        #if defined(_SIMPLEFUZZ) 
            addData,
        #endif
        light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, NdotL);
}



half4 LuxURPSimpleFuzzFragmentPBR(
    InputData inputData, 
    SurfaceData surfaceData,
    AdditionalSurfaceData additionalSurfaceData,
    half fuzzPower, half fuzzBias, half fuzzWrap, half fuzzStrength, half fuzzAmbient,
    half4 translucency)
{
    
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

//  URP 12:
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    half3 mainLightColor = mainLight.color;

//  SSAO
    #if defined(_SCREEN_SPACE_OCCLUSION)
        //AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(inputData.normalizedScreenSpaceUV);
        mainLightColor *= aoFactor.directAmbientOcclusion;
        //occlusion = min(occlusion, aoFactor.indirectAmbientOcclusion);
    #endif

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    half NdotL = saturate(dot(inputData.normalWS, mainLight.direction ));

    #if defined(_SIMPLEFUZZ)
        AdditionalData addData;
        addData.fuzzWrap = fuzzWrap;
    //  We tweak the diffuse to get some ambient fuzz lighting as well.
        half NdotV = saturate(dot(inputData.normalWS, inputData.viewDirectionWS ));
        addData.fuzz = Fuzz(NdotV, fuzzPower, fuzzBias);
        addData.fuzz *= additionalSurfaceData.fuzzMask * fuzzStrength;
        half3 diffuse = brdfData.diffuse;
        brdfData.diffuse *= 1.0h + addData.fuzz * fuzzAmbient;
    #endif

    //half3 color = GlobalIllumination(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
    //BRDFData brdfDataClearCoat = (BRDFData)0;
//  In order to use probe blending and proper AO we have to use the new GlobalIllumination function
    lightingData.giColor = GlobalIllumination(
        brdfData,
        brdfData, //brdfDataClearCoat,
        0, // surfaceData.clearCoatMask
        inputData.bakedGI,
        aoFactor.indirectAmbientOcclusion,
        inputData.positionWS,
        inputData.normalWS,
        inputData.viewDirectionWS,
        inputData.normalizedScreenSpaceUV
    );
    
    #if defined(_SIMPLEFUZZ)
    //  Reset diffuse as we want to use WrappedNdotL lighting.
        brdfData.diffuse = diffuse;
    #endif

#if defined(_LIGHT_LAYERS)
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
    lightingData.mainLightColor = LightingPhysicallyBased_LuxFuzz(brdfData,
        #if defined(_SIMPLEFUZZ) 
            addData,
        #endif
        mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL);
//  translucency
    #if defined(_SCATTERING)
        half transPower = translucency.y;
        half3 transLightDir = mainLight.direction + inputData.normalWS * translucency.w;
        half transDot = dot( transLightDir, -inputData.viewDirectionWS );
        transDot = exp2(saturate(transDot) * transPower - transPower);
        lightingData.mainLightColor += brdfData.diffuse * transDot * (1.0h - NdotL) * mainLightColor * lerp(1.0h, mainLight.shadowAttenuation, translucency.z) * translucency.x * 4;
    #endif
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
                    NdotL = saturate(dot(inputData.normalWS, light.direction ));
                    lightingData.additionalLightsColor += 10 * LightingPhysicallyBased_LuxFuzz(brdfData,
                        #if defined(_SIMPLEFUZZ) 
                            addData,
                        #endif
                        light, inputData.normalWS, inputData.viewDirectionWS, NdotL);
                //  translucency
                    #if defined(_SCATTERING)
                        half transPower = translucency.y;
                        half3 transLightDir = light.direction + inputData.normalWS * translucency.w;
                        half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                        transDot = exp2(saturate(transDot) * transPower - transPower);
                        lightingData.additionalLightsColor += brdfData.diffuse * transDot * (1.0h - NdotL) * light.color * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation  * translucency.x * 4;
                    #endif
                }
            }
        #endif

        LIGHT_LOOP_BEGIN(pixelLightCount)    
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            #if defined(_LIGHT_LAYERS)
                if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
                {
                NdotL = saturate(dot(inputData.normalWS, light.direction ));
                lightingData.additionalLightsColor += LightingPhysicallyBased_LuxFuzz(brdfData,
                    #if defined(_SIMPLEFUZZ) 
                        addData,
                    #endif
                    light, inputData.normalWS, inputData.viewDirectionWS, NdotL);
            //  translucency
                #if defined(_SCATTERING)
                    half transPower = translucency.y;
                    half3 transLightDir = light.direction + inputData.normalWS * translucency.w;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);
                    lightingData.additionalLightsColor += brdfData.diffuse * transDot * (1.0h - NdotL) * light.color * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation  * translucency.x * 4;
                #endif
                }
        LIGHT_LOOP_END
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif
    return CalculateFinalColor(lightingData, surfaceData.alpha);
}
#endif