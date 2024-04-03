// We have to mute URP's default decal implementation as it would tweak our albedo - which needs to be pure black
// as otherwise default lighting would no be stripped by the shader compiler.
// This mean that decals will use our custom lighting as well.

#ifdef _DBUFFER
    #undef _DBUFFER
    #define _CUSTOMDBUFFER
#endif

#if !defined(SHADERGRAPH_PREVIEW) || defined(UNIVERSAL_LIGHTING_INCLUDED)

//  As we do not have access to the vertex lights we will make the shader always sample add lights per pixel
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        #undef _ADDITIONAL_LIGHTS_VERTEX
        #define _ADDITIONAL_LIGHTS
    #endif
#endif

#if !defined(SHADERGRAPH_PREVIEW)
    half3 LightingPhysicallyBasedWrapped(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL)
    {
    //  NdotL is wrapped... not correct for specular
        half3 radiance = lightColor * (lightAttenuation * NdotL);
        return DirectBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
    }

    half3 LightingPhysicallyBasedWrapped(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS, half NdotL)
    {
        return LightingPhysicallyBasedWrapped(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, NdotL);
    }
#endif


void Lighting_half(

//  Base inputs
    float3 positionWS,
    float4 positionSP,
    half3 viewDirectionWS,

//  Normal inputs    
    half3 normalWS,
    half3 tangentWS,
    half3 bitangentWS,
    bool enableNormalMapping,
    half3 normalTS,

//  Surface description
    half3 albedo,
    half metallic,
    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,

//  Lighting specific inputs
    bool overrideTransmissionColor,
    half3 customTransMissionColor,
    half transmissionStrength,
    half transmissionPower,
    half transmissionDistortion,
    half transmissionShadowstrength,
    half transmissionMaskByShadowstrength,

//  Lightmapping
    float2 lightMapUV,
    float2 dynamicLightMapUV,

//  Final lit color
    out half3 MetaAlbedo,
    out half3 FinalLighting,
    out half3 MetaSpecular, 
    out half  MetaSmoothness,
    out half  MetaOcclusion,
    out half3 MetaNormal
)
{

#if defined(SHADERGRAPH_PREVIEW)
    FinalLighting = albedo;
    MetaAlbedo = half3(0,0,0);
    MetaSpecular = half3(0,0,0);
    MetaSmoothness = 0;
    MetaOcclusion = 0;
    MetaNormal = half3(0,0,1);
#else

//  Real Lighting

    if (enableNormalMapping) {
        normalWS = TransformTangentToWorld(normalTS, half3x3(tangentWS.xyz, bitangentWS.xyz, normalWS.xyz));
    }
    normalWS = NormalizeNormalPerPixel(normalWS);
    viewDirectionWS = SafeNormalize(viewDirectionWS);

//  GI Lighting
    half3 bakedGI;
    #ifdef LIGHTMAP_ON
        lightMapUV = lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
        #if defined(DYNAMICLIGHTMAP_ON)
            dynamicLightMapUV = dynamicLightMapUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            bakedGI = SAMPLE_GI(lightMapUV, dynamicLightMapUV, half3(0,0,0), normalWS);
        #else
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
            MetaNormal = normalTS;
        }
    #else
//  Debugging

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

    half3 transMissionColor = (overrideTransmissionColor) ? customTransMissionColor : brdfData.diffuse;

#if defined(_LIGHT_LAYERS)
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {

    //  Wrapped Diffuse   
        NdotL = saturate((dot(inputData.normalWS, mainLight.direction) + w) * WrappedNormalization );
        lightingData.mainLightColor = LightingPhysicallyBasedWrapped(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL);
    
    //  Translucency
        half transPower = transmissionPower;
        half3 transLightDir = mainLight.direction + inputData.normalWS * transmissionDistortion;
        half transDot = dot( transLightDir, -inputData.viewDirectionWS );
        transDot = exp2(saturate(transDot) * transPower - transPower);
        lightingData.mainLightColor += 
            #if defined(_STANDARDLIGHTING)
                mask *
            #endif
            transDot * (1.0 - NdotL) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, transmissionShadowstrength) * transMissionColor * transmissionStrength;
    }

    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();

        #if USE_FORWARD_PLUS
            for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
            {
                FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
                Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            #if defined(_LIGHT_LAYERS)
                if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
                {
                //  Wrapped Diffuse
                    NdotL = saturate((dot(inputData.normalWS, light.direction) + w) * WrappedNormalization );
                    lightingData.additionalLightsColor += LightingPhysicallyBasedWrapped(
                        brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL);
                //  Translucency
                    half3 lightColor = light.color;
                //  Mask by incoming shadow strength
                    int index = lightIndex;
                    
                    half4 shadowParams = GetAdditionalLightShadowParams(index);
                    #if !defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
                        lightColor *= lerp(1, 0, transmissionMaskByShadowstrength);
                    #else
                    //  half isPointLight = shadowParams.z;
                        lightColor *= lerp(1, shadowParams.x, transmissionMaskByShadowstrength);
                    #endif
                //  Apply Translucency
                    half transPower = transmissionPower;
                    half3 transLightDir = light.direction + inputData.normalWS * transmissionDistortion;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);
                    lightingData.additionalLightsColor += 
                        #if defined(_STANDARDLIGHTING)
                            mask *
                        #endif
                        transMissionColor * transDot * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, transmissionShadowstrength) * light.distanceAttenuation * transmissionStrength;
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
                        brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL);
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
                        lightColor *= lerp(1, 0, transmissionMaskByShadowstrength);
                    #else
                    //  half isPointLight = shadowParams.z;
                        lightColor *= lerp(1, shadowParams.x, transmissionMaskByShadowstrength);
                    #endif
                //  Apply Translucency
                    half transPower = transmissionPower;
                    half3 transLightDir = light.direction + inputData.normalWS * transmissionDistortion;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);
                    lightingData.additionalLightsColor += 
                        #if defined(_STANDARDLIGHTING)
                            mask *
                        #endif
                        transMissionColor * transDot * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, transmissionShadowstrength) * light.distanceAttenuation * transmissionStrength;
                }
        LIGHT_LOOP_END
    #endif

    FinalLighting = CalculateFinalColor(lightingData, surfaceData.alpha).xyz;

//  Set Albedo for meta pass
    #if defined(UNIVERSAL_META_PASS_INCLUDED)
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
        MetaNormal = normalTS;
    #endif

//  End Real Lighting ----------

    #endif // end debug

#endif
}

void Lighting_float(

//  Base inputs
    float3 positionWS,
    float4 positionSP,
    half3 viewDirectionWS,

//  Normal inputs    
    half3 normalWS,
    half3 tangentWS,
    half3 bitangentWS,
    bool enableNormalMapping,
    half3 normalTS,

//  Surface description
    half3 albedo,
    half metallic,
    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,

//  Lighting specific inputs
    bool overrideTransmissionColor,
    half3 customTransMissionColor,
    half transmissionStrength,
    half transmissionPower,
    half transmissionDistortion,
    half transmissionShadowstrength,
    half transmissionMaskByShadowstrength,

//  Lightmapping
    float2 lightMapUV,
    float2 dynamicLightMapUV,

//  Final lit color
    out half3 MetaAlbedo,
    out half3 FinalLighting,
    out half3 MetaSpecular,
    out half  MetaSmoothness,
    out half  MetaOcclusion,
    out half3 MetaNormal
)
{
    Lighting_half(
        positionWS, positionSP, viewDirectionWS, normalWS, tangentWS, bitangentWS, enableNormalMapping, normalTS, 
        albedo, metallic, specular, smoothness, occlusion, alpha,
        overrideTransmissionColor, customTransMissionColor,
        transmissionStrength, transmissionPower, transmissionDistortion, transmissionShadowstrength, transmissionMaskByShadowstrength,
        lightMapUV, dynamicLightMapUV, MetaAlbedo, FinalLighting, MetaSpecular, MetaSmoothness, MetaOcclusion, MetaNormal);
}