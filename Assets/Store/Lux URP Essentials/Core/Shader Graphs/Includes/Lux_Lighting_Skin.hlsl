#ifndef URP_SKINLIGHTING_INCLUDED
#define URP_SKINLIGHTING_INCLUDED


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


//TEXTURE2D(_SkinLUT); SAMPLER(sampler_SkinLUT); float4 _SkinLUT_TexelSize;

#if !defined(SHADERGRAPH_PREVIEW) || defined(UNIVERSAL_LIGHTING_INCLUDED)

half3 GlobalIllumination_Lux(BRDFData brdfData, half3 bakedGI, half occlusion, float3 positionWS, half3 normalWS, half3 viewDirectionWS, float2 normalizedScreenSpaceUV,
    half specOccluison)
{
    half fresnelTerm = 0;
    half3 indirectSpecular = 0;
    if(specOccluison > 0) {
        half3 reflectVector = reflect(-viewDirectionWS, normalWS);
        fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));
        indirectSpecular = GlossyEnvironmentReflection(
            reflectVector, positionWS, brdfData.perceptualRoughness, occlusion, normalizedScreenSpaceUV)        * specOccluison;
    }
    half3 indirectDiffuse = bakedGI * occlusion;
    return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}


half3 LightingPhysicallyBasedSkin(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL, half NdotLUnclamped, half curvature, half skinMask)
{
    half3 diffuseLighting = brdfData.diffuse * SAMPLE_TEXTURE2D_LOD(_SkinLUT, sampler_SkinLUT, float2( (NdotLUnclamped * 0.5 + 0.5), curvature), 0).rgb;
    diffuseLighting = lerp(brdfData.diffuse * NdotL, diffuseLighting, skinMask);
    //return ( DirectBDRF_Lux(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * NdotL + diffuseLighting ) * lightColor * lightAttenuation;
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
    bool enableDetailNormalMapping,
    bool enableDiffuseNormalMapping,
    bool enableBackScattering,
    bool useVertexNormal,

//  Surface description
    half3 albedo,
    half metallic,
    half3 specular,
    half smoothness,
    half occlusion,
    half3 emission, 
    half alpha,

    half4 translucency,
    half AmbientReflection,

    half3 subsurfaceColor,
    half curvature,
    half skinMask,
    half maskbyshadowstrength,

    half backScattering,


    bool normalSamplesProvided,
        float3 diffuseNormalTS,
        float3 specularNormalTS,

//  or
        UnityTexture2D normalMap,
        float2 UV,
        float bumpScale,

        UnityTexture2D detailNormalMap,
        float2 detailNormalTiling,
        float detailNormalScale,

        float diffuseBias,

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

#if defined(SHADERGRAPH_PREVIEW) || ( !defined(LIGHTWEIGHT_LIGHTING_INCLUDED) && !defined(UNIVERSAL_LIGHTING_INCLUDED) )
    FinalLighting = albedo;
    MetaAlbedo = half3(0,0,0);
    MetaSpecular = half3(0,0,0);
    MetaSmoothness = 0;
    MetaOcclusion = 0;
    MetaNormal = half3(0,0,1);
#else

    half3 depthNormalTS = half3(0,0,1);
    half3 diffuseNormalWS;
    half3x3 ToW;

    if (normalSamplesProvided) {
        ToW = half3x3(tangentWS.xyz, bitangentWS.xyz, normalWS.xyz);
        diffuseNormalWS = normalize(TransformTangentToWorld(diffuseNormalTS, ToW));
        normalWS = normalize(TransformTangentToWorld(specularNormalTS, ToW));
    }
    else {
        if (enableNormalMapping) {
            ToW = half3x3(tangentWS.xyz, bitangentWS.xyz, normalWS.xyz);

            half4 sampleNormal = SAMPLE_TEXTURE2D(normalMap, normalMap.samplerstate, UV);
            half3 normalTS = UnpackNormalScale(sampleNormal, bumpScale);

            if (enableDetailNormalMapping) {
            //  Get detail normal
                half4 sampleDetailNormal = SAMPLE_TEXTURE2D(detailNormalMap, detailNormalMap.samplerstate, UV * detailNormalTiling);
                half3 detailNormalTS = UnpackNormalScale(sampleDetailNormal, detailNormalScale);

            //  With UNITY_NO_DXT5nm unpacked vector is not normalized for BlendNormalRNM
                // For visual consistancy we going to do in all cases
                detailNormalTS = normalize(detailNormalTS);
                normalTS = BlendNormalRNM(normalTS, detailNormalTS);
            }
                
            depthNormalTS = normalTS;

        //  Get specular normal
            half3 snormalWS = TransformTangentToWorld(normalTS, ToW);
            snormalWS = NormalizeNormalPerPixel(snormalWS);


        //  Get diffuse normal
            if(enableDiffuseNormalMapping) {
                half4 sampleNormalDiffuse = SAMPLE_TEXTURE2D_BIAS(normalMap, normalMap.samplerstate, UV, diffuseBias);
                half3 diffuseNormalTS = UnpackNormalScale(sampleNormalDiffuse, 1.0);
            
            //  No detail Normal added to the diffuse normal!
            //  HLSL version debugs specular normal!
                // depthNormalTS = diffuseNormalTS;

            //  Get diffuseNormalWS
                diffuseNormalWS = TransformTangentToWorld(diffuseNormalTS, ToW);
                diffuseNormalWS = NormalizeNormalPerPixel(diffuseNormalWS);
            }
            else {
                diffuseNormalWS = (useVertexNormal) ? normalWS : snormalWS;
            }

        //  Set specular normal
            normalWS = snormalWS;
            
        }
        else {
           normalWS = NormalizeNormalPerPixel(normalWS);
           diffuseNormalWS = normalWS;
        }
    }

    viewDirectionWS = SafeNormalize(viewDirectionWS);

//  GI Lighting
    half3 bakedGI;
    #ifdef LIGHTMAP_ON
        lightMapUV = lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
        #if defined(DYNAMICLIGHTMAP_ON)
            dynamicLightMapUV = dynamicLightMapUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            bakedGI = SAMPLE_GI(lightMapUV, dynamicLightMapUV, half3(0,0,0), diffuseNormalWS); //normalWS);
        #else
            bakedGI = SAMPLE_GI(lightMapUV, half3(0,0,0), diffuseNormalWS); //normalWS);
        #endif
    #else
        bakedGI = SampleSH(diffuseNormalWS); 
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
//  Note: Diffuse normal and skin lighting mask are not affected!
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
            MetaNormal = depthNormalTS;
        }
    #else

//  Lighting

        half4 shadowMask = CalculateShadowMask(inputData);
        AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        uint meshRenderingLayers = GetMeshRenderingLayer();

        Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
        half3 mainLightColor = mainLight.color;

        //MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);
        MixRealtimeAndBakedGI(mainLight, diffuseNormalWS, inputData.bakedGI);
        
        LightingData lightingData = CreateLightingData(inputData, surfaceData);

        lightingData.giColor = GlobalIllumination_Lux(
            brdfData, bakedGI, aoFactor.indirectAmbientOcclusion,
            inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV,
            AmbientReflection
        );

    //  Backscattering
        if (enableBackScattering) {
            lightingData.giColor += backScattering * SampleSH(-diffuseNormalWS) * surfaceData.albedo * aoFactor.indirectAmbientOcclusion * translucency.x * subsurfaceColor * skinMask;
        }

    #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
        {
    
            half NdotLUnclamped = dot(diffuseNormalWS, mainLight.direction);
            half NdotL = saturate( dot(inputData.normalWS, mainLight.direction) );
            lightingData.mainLightColor = LightingPhysicallyBasedSkin(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);

        //  Translucency
            half transPower = translucency.y;
            half3 transLightDir = mainLight.direction + inputData.normalWS * translucency.w;
            half transDot = dot( transLightDir, -inputData.viewDirectionWS );
            transDot = exp2(saturate(transDot) * transPower - transPower);
            lightingData.mainLightColor += skinMask * subsurfaceColor * transDot * (1.0 - saturate(NdotLUnclamped)) * mainLightColor * lerp(1.0h, mainLight.shadowAttenuation, translucency.z) * translucency.x;
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
                    half NdotLUnclamped = dot(diffuseNormalWS, light.direction);
                    half NdotL = saturate( dot(inputData.normalWS, light.direction) );
                    lightingData.additionalLightsColor += LightingPhysicallyBasedSkin(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);

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

                    half transPower = translucency.y;
                    half3 transLightDir = light.direction + inputData.normalWS * translucency.w;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);
                    lightingData.additionalLightsColor += skinMask * subsurfaceColor * transDot * (1.0 - saturate(NdotLUnclamped)) * lightColor * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation * translucency.x;
                }
            }
        #endif

        LIGHT_LOOP_BEGIN(pixelLightCount)    
                Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            #if defined(_LIGHT_LAYERS)
                if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
                {
                    half NdotLUnclamped = dot(diffuseNormalWS, light.direction);
                    half NdotL = saturate( dot(inputData.normalWS, light.direction) );
                    lightingData.additionalLightsColor += LightingPhysicallyBasedSkin(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL, NdotLUnclamped, curvature, skinMask);

                //  Translucency
                    half3 lightColor = light.color;
                //  Mask by incoming shadow strength
                    int index = lightIndex;
                    //int index = GetPerObjectLightIndex(lightIndex);
                    half4 shadowParams = GetAdditionalLightShadowParams(index);
                    #if !defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
                        lightColor *= lerp(1, 0, maskbyshadowstrength);
                    #else
                    //  half isPointLight = shadowParams.z;
                        lightColor *= lerp(1, shadowParams.x, maskbyshadowstrength);
                    #endif

                    half transPower = translucency.y;
                    half3 transLightDir = light.direction + inputData.normalWS * translucency.w;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);
                    lightingData.additionalLightsColor += skinMask * subsurfaceColor * transDot * (1.0 - saturate(NdotLUnclamped)) * lightColor * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation * translucency.x;
                }
        LIGHT_LOOP_END
    #endif

// -----------------------

        FinalLighting = CalculateFinalColor(lightingData, surfaceData.alpha).xyz;

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
    //        FinalLighting += inputData.vertexLighting * brdfData.diffuse;
        #endif
        FinalLighting += emission;

    //  Set Albedo for meta pass
        #if defined(LIGHTWEIGHT_META_PASS_INCLUDED) || defined(UNIVERSAL_META_PASS_INCLUDED)
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
            MetaNormal = depthNormalTS;
        #endif

    #endif // end Debugging

#endif
}

// Unity 2019.1. needs a float version

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
    bool enableDetailNormalMapping,
    bool enableDiffuseNormalMapping,
    bool enableBackScattering,
    bool useVertexNormal,

//  Surface description
    half3 albedo,
    half metallic,
    half3 specular,
    half smoothness,
    half occlusion,
    half3 emission, 
    half alpha,

    half4 translucency,
    half AmbientReflection,

    half3 subsurfaceColor,
    half curvature,
    half skinMask,
    half maskbyshadowstrength,

    half backScattering,

    bool normalSamplesProvided,
        float3 diffuseNormalTS,
        float3 specularNormalTS,
//  or

        UnityTexture2D normalMap,
        float2 UV,
        float bumpScale,

        UnityTexture2D detailNormalMap,
        float2 detailNormalTiling,
        float detailNormalScale,

        float diffuseBias,

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
        positionWS, positionSP, viewDirectionWS, normalWS, tangentWS, bitangentWS, enableNormalMapping, enableDetailNormalMapping, enableDiffuseNormalMapping, enableBackScattering, useVertexNormal,
        albedo, metallic, specular, smoothness, occlusion, emission, alpha,
        translucency, AmbientReflection, subsurfaceColor, curvature, skinMask, maskbyshadowstrength,
        backScattering,
        normalSamplesProvided, diffuseNormalTS, specularNormalTS,
        normalMap, UV, bumpScale,
        detailNormalMap, detailNormalTiling, detailNormalScale,
        diffuseBias,
        lightMapUV, dynamicLightMapUV, MetaAlbedo, FinalLighting, MetaSpecular, MetaSmoothness, MetaOcclusion, MetaNormal
    );
}


#endif