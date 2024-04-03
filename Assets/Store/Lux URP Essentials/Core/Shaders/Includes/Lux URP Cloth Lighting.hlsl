// NOTE: Based on URP Lighting.hlsl which replaced some half3 with floats to avoid lighting artifacts on mobile
// Hair lighting functions renamed to solves problems with LWRP 6.x


// https://google.github.io/filament/Filament.md.html#materialsystem/clothmodel
// SheenColor

#ifndef LIGHTWEIGHT_CLOTHLIGHTING_INCLUDED
#define LIGHTWEIGHT_CLOTHLIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// Ref: https://knarkowicz.wordpress.com/2018/01/04/cloth-shading/
real D_CharlieNoPI_Lux(real NdotH, real roughness)
{
    float invR = rcp(roughness);
    float cos2h = NdotH * NdotH;
    float sin2h = 1.0 - cos2h;
    // Note: We have sin^2 so multiply by 0.5 to cancel it
    return (2.0 + invR) * PositivePow(sin2h, invR * 0.5) / 2.0;
}

real D_Charlie_Lux(real NdotH, real roughness)
{
    return INV_PI * D_CharlieNoPI_Lux(NdotH, roughness);
}

// We use V_Ashikhmin instead of V_Charlie in practice for game due to the cost of V_Charlie
real V_Ashikhmin_Lux(real NdotL, real NdotV)
{
    // Use soft visibility term introduce in: Crafting a Next-Gen Material Pipeline for The Order : 1886
    return 1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV));
}

// A diffuse term use with fabric done by tech artist - empirical
real FabricLambertNoPI_Lux(real roughness)
{
    return lerp(1.0, 0.5, roughness);
}

real FabricLambert_Lux(real roughness)
{
    return INV_PI * FabricLambertNoPI_Lux(roughness);
}

// ---------

struct AdditionalData {
    half3   tangentWS;
    half3   bitangentWS;
    float   partLambdaV;
    half    roughnessT;
    half    roughnessB;
    half3   anisoReflectionNormal;
    half3   sheenColor;
};

half3 DirectBDRF_LuxCloth(BRDFData brdfData, AdditionalData addData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, half NdotL)
{
#ifndef _SPECULARHIGHLIGHTS_OFF
    float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
    float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

    float NoH = saturate(dot(float3(normalWS), halfDir));
    half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

    half NdotV = saturate(dot(normalWS, viewDirectionWS ));

    #if defined(_COTTONWOOL)

    //  NOTE: We use the noPI version here!!!!!!
        float D = D_CharlieNoPI_Lux(NoH, brdfData.roughness);
    //  Unity: V_Charlie is expensive, use approx with V_Ashikhmin instead
    //  Unity: float Vis = V_Charlie(NdotL, NdotV, bsdfData.roughness);
        float Vis = V_Ashikhmin_Lux(NdotL, NdotV);

    //  Unity: Fabrics are dieletric but we simulate forward scattering effect with colored specular (fuzz tint term)
    //  Unity: We don't use Fresnel term for CharlieD
    //  SheenColor seemed way too dark (compared to HDRP) – so i multiply it with PI which looked ok and somehow matched HDRP
    //  Therefore we use the noPI charlie version. As PI is a constant factor the artists can tweak the look by adjusting the sheen color.
        float3 F = addData.sheenColor; // * PI;
        half3 specularLighting = F * Vis * D;

    //  Unity: Note: diffuseLighting originally is multiply by color in PostEvaluateBSDF
    //  So we do it here :)
    //  Using saturate to get rid of artifacts around the borders.
        return saturate(specularLighting) + brdfData.diffuse * FabricLambert_Lux(brdfData.roughness);
    
    #else
        float3 tangentWS = float3(addData.tangentWS);
        float3 bitangentWS = float3(addData.bitangentWS);

        float TdotH = dot(tangentWS, halfDir);
        float TdotL = dot(tangentWS, lightDirectionWSFloat3);
        float BdotH = dot(bitangentWS, halfDir);
        float BdotL = dot(bitangentWS, lightDirectionWSFloat3);

        half3 F = F_Schlick(brdfData.specular, LoH); // 1.91: was float3

        //float TdotV = dot(tangentWS, viewDirectionWS);
        //float BdotV = dot(bitangentWS, viewDirectionWS);

        float DV = DV_SmithJointGGXAniso(
            TdotH, BdotH, NoH, NdotV, TdotL, BdotL, NdotL,
            addData.roughnessT, addData.roughnessB, addData.partLambdaV
        );
        half3 specularLighting = F * DV;

        return specularLighting + brdfData.diffuse;
    
    #endif

#else
    return brdfData.diffuse;
#endif
}

half3 LightingPhysicallyBased_LuxCloth(BRDFData brdfData, AdditionalData addData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL)
{
    half3 radiance = lightColor * (lightAttenuation * NdotL);
    return DirectBDRF_LuxCloth(brdfData, addData, normalWS, lightDirectionWS, viewDirectionWS, NdotL) * radiance;
}

half3 LightingPhysicallyBased_LuxCloth(BRDFData brdfData, AdditionalData addData, Light light, half3 normalWS, half3 viewDirectionWS, half NdotL)
{
    return LightingPhysicallyBased_LuxCloth(brdfData, addData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, NdotL);
}

//  As we need both normals here - otherwise kept in sync with latest URP function
half3 GlobalIllumination_LuxAniso(BRDFData brdfData, BRDFData brdfDataClearCoat, float clearCoatMask,
    half3 bakedGI, half occlusion, float3 positionWS,
    half3 anisoReflectionNormal,
    half3 normalWS, half3 viewDirectionWS, float2 normalizedScreenSpaceUV)
{
    half3 reflectVector = reflect(-viewDirectionWS, anisoReflectionNormal);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);

    half3 indirectDiffuse = bakedGI;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, 1.0h, normalizedScreenSpaceUV);

    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

    if (IsOnlyAOLightingFeatureEnabled())
    {
        color = half3(1,1,1); // "Base white" for AO debug lighting mode
    }

#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
    half3 coatIndirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfDataClearCoat.perceptualRoughness, 1.0h, normalizedScreenSpaceUV);
    // TODO: "grazing term" causes problems on full roughness
    half3 coatColor = EnvironmentBRDFClearCoat(brdfDataClearCoat, clearCoatMask, coatIndirectSpecular, fresnelTerm);

    // Blend with base layer using khronos glTF recommended way using NoV
    // Smooth surface & "ambiguous" lighting
    // NOTE: fresnelTerm (above) is pow4 instead of pow5, but should be ok as blend weight.
    half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * fresnelTerm;
    return (color * (1.0 - coatFresnel * clearCoatMask) + coatColor) * occlusion;
#else
    return color * occlusion;
#endif
}



half4 LuxURPClothFragmentPBR(InputData inputData, SurfaceData surfaceData, half3 tangentWS, half anisotropy, half3 sheenColor, half4 translucency)
{
    
    #if defined(_COTTONWOOL)
        surfaceData.smoothness = lerp(0.0h, 0.6h, surfaceData.smoothness);
    #endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

//  Do not apply energy conservtion
    brdfData.diffuse = surfaceData.albedo;
    brdfData.specular = surfaceData.specular;

//  Debugging
    #if defined(DEBUG_DISPLAY)
        half4 debugColor;
        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
        {
            return debugColor;
        }
    #endif

    AdditionalData addData;
//  Adjust tangentWS in case normal mapping is active
    #if defined(_NORMALMAP)   
        tangentWS = Orthonormalize(tangentWS, inputData.normalWS);
    #endif            
    addData.tangentWS = tangentWS;
    addData.bitangentWS = cross(inputData.normalWS, tangentWS);

//  We do not apply ClampRoughnessForAnalyticalLights here
    addData.roughnessT = brdfData.roughness * (1 + anisotropy);
    addData.roughnessB = brdfData.roughness * (1 - anisotropy);

    #if !defined(_COTTONWOOL)
        float TdotV = dot(addData.tangentWS, inputData.viewDirectionWS);
        float BdotV = dot(addData.bitangentWS, inputData.viewDirectionWS);
        float NdotV = dot(inputData.normalWS, inputData.viewDirectionWS);
        addData.partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, NdotV, addData.roughnessT, addData.roughnessB);

    //  Set reflection normal and roughness – derived from GetGGXAnisotropicModifiedNormalAndRoughness
        half3 grainDirWS = (anisotropy >= 0.0) ? addData.bitangentWS : addData.tangentWS;
        half stretch = abs(anisotropy) * saturate(1.5h * sqrt(brdfData.perceptualRoughness));
        addData.anisoReflectionNormal = GetAnisotropicModifiedNormal(grainDirWS, inputData.normalWS, inputData.viewDirectionWS, stretch);
        half iblPerceptualRoughness = brdfData.perceptualRoughness * saturate(1.2 - abs(anisotropy));

    //  Override perceptual roughness for ambient specular reflections
        brdfData.perceptualRoughness = iblPerceptualRoughness;
    #else
    //  partLambdaV should be 0.0f in case of cotton wool
        addData.partLambdaV = 0.0h;
        addData.anisoReflectionNormal = inputData.normalWS;

        float NdotV = dot(inputData.normalWS, inputData.viewDirectionWS);

    //  Only used for reflections - so we skip it
        /*float3 preFGD = SAMPLE_TEXTURE2D_LOD(_PreIntegratedLUT, sampler_PreIntegratedLUT, float2(NdotV, brdfData.perceptualRoughness), 0).xyz;
        // Denormalize the value
        preFGD.y = preFGD.y / (1 - preFGD.y);
        half3 specularFGD = preFGD.yyy * fresnel0;
        // z = FabricLambert
        half3 diffuseFGD = preFGD.z;
        half reflectivity = preFGD.y;*/
    #endif
    addData.sheenColor = sheenColor;

    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();

    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    half3 mainLightColor = mainLight.color;

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

//  NOTE: We use addData.anisoReflectionNormal here!
    lightingData.giColor = GlobalIllumination_LuxAniso(
        brdfData,
        brdfData, // brdfDataClearCoat
        0, // surfaceData.clearCoatMask,
        inputData.bakedGI,
        aoFactor.indirectAmbientOcclusion,
        inputData.positionWS,
        addData.anisoReflectionNormal,
        inputData.normalWS,
        inputData.viewDirectionWS,
        inputData.normalizedScreenSpaceUV
    );

    half NdotL;
    
#if defined(_LIGHT_LAYERS)
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
    NdotL = saturate(dot(inputData.normalWS, mainLight.direction ));
    lightingData.mainLightColor = LightingPhysicallyBased_LuxCloth(brdfData, addData, mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL);

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
                half3 lightColor = light.color;
                NdotL = saturate(dot(inputData.normalWS, light.direction ));
                lightingData.additionalLightsColor += LightingPhysicallyBased_LuxCloth(brdfData, addData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL);
            //  translucency
                #if defined(_SCATTERING)
                    half transPowerA = translucency.y;
                    half3 transLightDirA = light.direction + inputData.normalWS * translucency.w;
                    half transDotA = dot( transLightDirA, -inputData.viewDirectionWS );
                    transDotA = exp2(saturate(transDotA) * transPowerA - transPowerA);
                    lightingData.additionalLightsColor += brdfData.diffuse * transDotA * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation * translucency.x * 4;
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
                half3 lightColor = light.color;
                NdotL = saturate(dot(inputData.normalWS, light.direction ));
                lightingData.additionalLightsColor += LightingPhysicallyBased_LuxCloth(brdfData, addData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL);
            //  translucency
                #if defined(_SCATTERING)
                    half transPowerA = translucency.y;
                    half3 transLightDirA = light.direction + inputData.normalWS * translucency.w;
                    half transDotA = dot( transLightDirA, -inputData.viewDirectionWS );
                    transDotA = exp2(saturate(transDotA) * transPowerA - transPowerA);
                    lightingData.additionalLightsColor += brdfData.diffuse * transDotA * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation * translucency.x * 4;
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