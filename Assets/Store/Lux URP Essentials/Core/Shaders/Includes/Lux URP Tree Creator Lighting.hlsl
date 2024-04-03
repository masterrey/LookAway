#ifndef LIGHTWEIGHT_TREE_INCLUDED
#define LIGHTWEIGHT_TREE_INCLUDED


// Bark lighting

inline half3 LightingTreeBark (Light light, half3 albedo, half3 specular, half gloss, half squashAmount, half3 normal, half3 viewDir)
{
    
    half NoL = saturate( dot (normal, light.direction) );
    #ifndef _SPECULARHIGHLIGHTS_OFF
        float3 halfDir = SafeNormalize(light.direction + viewDir);
        float NoH = saturate( dot (normal, halfDir) );
        float spec = pow (NoH, specular.r * 128.0f) * gloss;
    #endif
    
    half3 c;
    half3 lighting = light.color * light.distanceAttenuation * light.shadowAttenuation * squashAmount;
    #ifndef _SPECULARHIGHLIGHTS_OFF
        c = (albedo + specular * spec) * NoL * lighting;
    #else 
        c = albedo * NoL * lighting;
    #endif
    return c;
}

half4 LuxURPTreeBarkFragment
(
    InputData inputData, SurfaceData surfaceData,
    half squashAmount
)
{

//  Needed for GI    
    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
        half4 debugColor;
        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
        {
            return debugColor;
        }
    #endif

//  Init
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();

    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);
    lightingData.giColor = GlobalIllumination(brdfData, brdfData, 0.0h,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);

//  Main Light
    #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        {
    #endif
            lightingData.mainLightColor += LightingTreeBark(mainLight, surfaceData.albedo, surfaceData.specular, surfaceData.smoothness, 1, inputData.normalWS, inputData.viewDirectionWS);
    #if defined(_LIGHT_LAYERS)
        }
    #endif

//  Additional Lights
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
                #if defined(_SCREEN_SPACE_OCCLUSION)
                    light.color *= aoFactor.directAmbientOcclusion;
                #endif
                    lightingData.additionalLightsColor += LightingTreeBark(light, surfaceData.albedo, surfaceData.specular, surfaceData.smoothness, squashAmount, inputData.normalWS, inputData.viewDirectionWS);
                }
            }
        #endif
        
        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
            {
            #if defined(_SCREEN_SPACE_OCCLUSION)
                light.color *= aoFactor.directAmbientOcclusion;
            #endif
                lightingData.additionalLightsColor += LightingTreeBark(light, surfaceData.albedo, surfaceData.specular, surfaceData.smoothness, squashAmount, inputData.normalWS, inputData.viewDirectionWS);
            }
        LIGHT_LOOP_END
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        lightingData.vertexLightingColor += inputData.vertexLighting * surfaceData.albedo;
    #endif
    
    return CalculateFinalColor(lightingData, surfaceData.alpha);
}



// Leaf lighting

inline half3 LightingTreeLeaf(Light light, half3 albedo, half3 specular, half gloss, half2 translucency, half3 translucencyColor, half squashAmount, half3 normal, half3 viewDir)
{
    half NoL = dot(normal, light.direction);
    #ifndef _SPECULARHIGHLIGHTS_OFF
        float3 halfDir = SafeNormalize(light.direction + viewDir);
        float NoH = saturate( dot (normal, halfDir) );
        float spec = pow(NoH, specular.r * 128.0f) * gloss;
    #endif
    
    // view dependent back contribution for translucency
    half backContrib = saturate(dot(viewDir, -light.direction));
    // normally translucency is more like -nl, but looks better when it's view dependent
    backContrib = lerp(saturate(-NoL), backContrib, translucency.y);
    translucencyColor *= backContrib * translucency.x;
    // wrap-around diffuse
    NoL = saturate (NoL * 0.6h + 0.4h);
    
    half3 c;
    /////@TODO: what is is this multiply 2x here???
    c = albedo * (translucencyColor * 2 + NoL);

//  NOTE: squashAmount is 1 for directional lights as only additional gets faded in.
    half3 lighting = light.color * light.distanceAttenuation * light.shadowAttenuation * squashAmount;
    
    #ifndef _SPECULARHIGHLIGHTS_OFF
        c = (c + spec) * lighting;
    #else 
        c = c * lighting;
    #endif
    
    return c;
}


half4 LuxURPTreeLeafFragmentPBR (
    InputData inputData, SurfaceData surfaceData,
    half2 translucency, half3 translucencyColor, half squashAmount, half shadowStrength
)
{

//  Needed for GI    
    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
        half4 debugColor;
        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
        {
            return debugColor;
        }
    #endif

//  Init
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();

    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
//  Tree creator leaves specifics
    mainLight.shadowAttenuation = lerp(1.0h, mainLight.shadowAttenuation, shadowStrength * squashAmount /* fade out */);
    mainLight.color *= aoFactor.directAmbientOcclusion;

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfData, 0,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
//  Main Light
    #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
        {
            lightingData.mainLightColor += LightingTreeLeaf(mainLight, surfaceData.albedo, surfaceData.specular, surfaceData.smoothness, translucency, translucencyColor, 1, inputData.normalWS, inputData.viewDirectionWS);
        }

//  Additional Lights
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
                #if defined(_SCREEN_SPACE_OCCLUSION)
                    light.color *= aoFactor.directAmbientOcclusion;
                #endif
                    lightingData.additionalLightsColor += LightingTreeLeaf(light, surfaceData.albedo, surfaceData.specular, surfaceData.smoothness, translucency, translucencyColor, squashAmount, inputData.normalWS, inputData.viewDirectionWS);
                }
            }
            #endif
        
        LIGHT_LOOP_BEGIN(pixelLightCount) 
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
            {
            #if defined(_SCREEN_SPACE_OCCLUSION)
                light.color *= aoFactor.directAmbientOcclusion;
            #endif
                lightingData.additionalLightsColor += LightingTreeLeaf(light, surfaceData.albedo, surfaceData.specular, surfaceData.smoothness, translucency, translucencyColor, squashAmount, inputData.normalWS, inputData.viewDirectionWS);
            }
        LIGHT_LOOP_END
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        lightingData.vertexLightingColor += inputData.vertexLighting * surfaceData.albedo;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}
#endif