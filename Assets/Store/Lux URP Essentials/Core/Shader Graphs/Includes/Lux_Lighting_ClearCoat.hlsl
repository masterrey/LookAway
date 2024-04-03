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

    #if defined(UNIVERSAL_LIGHTING_INCLUDED)

        struct AdditionalData {
            half coatThickness;
            half3 coatSpecular;
            half3 normalWS;
            half perceptualRoughness;
            half roughness;
            half roughness2;
            half normalizationTerm;
            half roughness2MinusOne;    // roughness² - 1.0
            half reflectivity;
            half grazingTerm;
            half specOcclusion;

            bool enableSecondaryLobe;
        };

        half3 DirectBDRF_LuxClearCoat(BRDFData brdfData, AdditionalData addData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, half NdotL)
        {
        #ifndef _SPECULARHIGHLIGHTS_OFF
            float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
            float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));
            
            half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

        //  Base Lobe
            float NoH = saturate(dot(float3(normalWS), halfDir));
            float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;
        //  URP 15 removes that change
            //half d2 = half(d * d);
            half LoH2 = max(0.1h, LoH * LoH);
            half specularTerm = brdfData.roughness2 / ((d * d) * LoH2 * brdfData.normalizationTerm);
        
            #if REAL_IS_HALF
                specularTerm = specularTerm - HALF_MIN;
                specularTerm = clamp(specularTerm, 0.0, 1000.0); // Prevent FP16 overflow on mobiles
            #endif

            half3 spec = specularTerm * brdfData.specular * NdotL;

        //  Coat Lobe
            [branch]
            if (addData.coatThickness > 0.0h) {
            //  From HDRP: Scale base specular
                half coatF = F_Schlick(addData.reflectivity /*addData.coatSpecular*/ /*CLEAR_COAT_F0*/, LoH) * addData.coatThickness;
                spec *= Sq(1.0h - coatF);
                //spec *= (1.0h - coatF); // as used by filament, na, not really
                NoH = saturate(dot(float3(addData.normalWS), halfDir));
                d = NoH * NoH * addData.roughness2MinusOne + 1.00001f;
                specularTerm = addData.roughness2 / ((d * d) * LoH2 * addData.normalizationTerm);
                
                #if REAL_IS_HALF
                    specularTerm = specularTerm - HALF_MIN;
                    specularTerm = clamp(specularTerm, 0.0, 1000.0); // Prevent FP16 overflow on mobiles
                #endif
                
                spec += specularTerm * addData.coatSpecular * saturate(dot(addData.normalWS, lightDirectionWS));
            }
                
            half3 color = spec + brdfData.diffuse * NdotL; // from HDRP (but does not do much?) * lerp(1.0h, 1.0h - coatF, addData.coatThickness);
            return color;
        #else
            return brdfData.diffuse * NdotL;
        #endif
        }

        half3 LightingPhysicallyBased_LuxClearCoat(BRDFData brdfData, AdditionalData addData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS)
        {
            half NdotL = saturate(dot(normalWS, lightDirectionWS));
            half3 radiance = lightColor * (lightAttenuation); // * NdotL);
            return DirectBDRF_LuxClearCoat(brdfData, addData, normalWS, lightDirectionWS, viewDirectionWS, NdotL) * radiance;
        }

        half3 LightingPhysicallyBased_LuxClearCoat(BRDFData brdfData, AdditionalData addData, Light light, half3 normalWS, half3 viewDirectionWS)
        {
            return LightingPhysicallyBased_LuxClearCoat(brdfData, addData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS);
        }

        half3 EnvironmentBRDF_LuxClearCoat(BRDFData brdfData, AdditionalData addData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
        {
            half3 c = indirectDiffuse * brdfData.diffuse;
            float surfaceReduction = 1.0 / (addData.roughness2 + 1.0);
            c += surfaceReduction * indirectSpecular * lerp(addData.coatSpecular, addData.grazingTerm, fresnelTerm);
            return c;
        }


        half3 GlobalIllumination_LuxClearCoat(BRDFData brdfData, AdditionalData addData, half3 bakedGI, half occlusion, float3 positionWS, float2 normalizedScreenSpaceUV,
            half3 normalWS, half3 baseNormalWS, half3 viewDirectionWS, half NdotV
        )
        {
            half3 reflectVector = reflect(-viewDirectionWS, normalWS);
            half fresnelTerm = Pow4(1.0 - NdotV);

            half3 indirectDiffuse = bakedGI * occlusion; 
            half3 indirectSpecular = (addData.coatThickness == 0.0h) ? 0.0h : GlossyEnvironmentReflection(
                reflectVector, positionWS, addData.perceptualRoughness, addData.specOcclusion, normalizedScreenSpaceUV
            );

            half3 res = EnvironmentBRDF_LuxClearCoat(brdfData, addData, indirectDiffuse, indirectSpecular, fresnelTerm);

        //  Should be stripped by the compiler as it is a constant boolean
            if (addData.enableSecondaryLobe)
            {
                reflectVector = reflect(-viewDirectionWS, baseNormalWS);
                indirectSpecular = GlossyEnvironmentReflection(
                    reflectVector, positionWS, brdfData.perceptualRoughness, occlusion, normalizedScreenSpaceUV
                );
                float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
            //  Recalculate NdotV and fresnel using the basenormal
                NdotV = saturate( dot(baseNormalWS, viewDirectionWS) );
                fresnelTerm = Pow4(1.0 - NdotV);
            //  We use NdotV to reduce reflections from secondary lobe
            //  Secondary lobe also takes occlusion into account!
                res += occlusion * NdotV * surfaceReduction * indirectSpecular * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
            }
            return res;
        }

        half3 f0ClearCoatToSurface_Lux(half3 f0) 
        {
            // Approximation of iorTof0(f0ToIor(f0), 1.5)
            // This assumes that the clear coat layer has an IOR of 1.5
        #if REAL_IS_HALF
            return saturate(f0 * (f0 * 0.526868h + 0.529324h) - 0.0482256h);
        #else
            return saturate(f0 * (f0 * (0.941892h - 0.263008h * f0) + 0.346479h) - 0.0285998h);
        #endif
        }

    #endif
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
    half3 albedo,           // albedo is baseColor
    half metallic,
    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,

//  Lighting specific inputs
    half clearcoatSmoothness,
    half clearcoatThickness,
    half3 clearcoatSpecular,
    
    half3 baseColor,
    half3 secondaryColor,

    bool enableSecondaryColor,
    bool enableSecondaryLobe,

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

//#ifdef SHADERGRAPH_PREVIEW
#if defined(SHADERGRAPH_PREVIEW) || ( !defined(LIGHTWEIGHT_LIGHTING_INCLUDED) && !defined(UNIVERSAL_LIGHTING_INCLUDED) )
    FinalLighting = albedo;
    MetaAlbedo = half3(0,0,0);
    MetaSpecular = half3(0,0,0);
    MetaSmoothness = 0;
    MetaOcclusion = 0;
    MetaNormal = half3(0,0,1);
#else


//  Real Lighting ----------

//  Cache the geometry normal used by the coat
    half3 vertexNormalWS = NormalizeNormalPerPixel(normalWS);

    if (enableNormalMapping) {
        normalWS = TransformTangentToWorld(normalTS, half3x3(tangentWS.xyz, bitangentWS.xyz, normalWS.xyz));
    }
    normalWS = NormalizeNormalPerPixel(normalWS);
    viewDirectionWS = SafeNormalize(viewDirectionWS);

//  GI Lighting
    half3 bakedGI;
    #ifdef LIGHTMAP_ON
        #if defined(DYNAMICLIGHTMAP_ON)
            dynamicLightMapUV = dynamicLightMapUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            bakedGI = SAMPLE_GI(lightMapUV, dynamicLightMapUV, half3(0,0,0), normalWS);
        #else
            lightMapUV = lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
            bakedGI = SAMPLE_GI(lightMapUV, half3(0,0,0), normalWS);
        #endif
    #else
        bakedGI = SampleSH(normalWS); 
    #endif

//  ClearCoat
    half NdotV = saturate( dot(vertexNormalWS, viewDirectionWS) );
    #if !defined(LIGHTWEIGHT_META_PASS_INCLUDED) && !defined(UNIVERSAL_META_PASS_INCLUDED)
        if(enableSecondaryColor) {
            albedo *= lerp(secondaryColor, baseColor, NdotV);
        }
        else 
        {
            albedo *= baseColor; 
        }
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
        surfaceData.normalTS = normalTS;   
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
            FinalLighting = debugColor;
            MetaAlbedo = debugColor;
            MetaSpecular = specular;
            MetaSmoothness = smoothness;
            MetaOcclusion = occlusion;
            MetaNormal = normalTS;
        }
    #else

    //  Clear Coat Lighting

        half4 shadowMask = CalculateShadowMask(inputData);
        AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        uint meshRenderingLayers = GetMeshRenderingLayer();
        
    //  Adjust specular as we have a transition from coat to material and not air to material
        brdfData.specular = lerp(brdfData.specular, f0ClearCoatToSurface_Lux(brdfData.specular), clearcoatThickness);

        AdditionalData addData;
        addData.coatThickness = clearcoatThickness;
        addData.coatSpecular = clearcoatSpecular;
        addData.normalWS = vertexNormalWS;
        addData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(clearcoatSmoothness);
        addData.roughness = PerceptualRoughnessToRoughness(addData.perceptualRoughness);
        addData.roughness2 = addData.roughness * addData.roughness;
        addData.normalizationTerm = addData.roughness * 4.0h + 2.0h;
        addData.roughness2MinusOne = addData.roughness2 - 1.0h;
        addData.reflectivity = ReflectivitySpecular(clearcoatSpecular);
        addData.grazingTerm = saturate(clearcoatSmoothness + addData.reflectivity);
    //  This contain ssao only
        addData.specOcclusion = aoFactor.indirectAmbientOcclusion;

        addData.enableSecondaryLobe = enableSecondaryLobe;
  
        
        Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);
        LightingData lightingData = CreateLightingData(inputData, surfaceData);

    //  Approximation of refraction on BRDF
        half refractionScale = ((NdotV * 0.5 + 0.5) * NdotV - 1.0) * saturate(1.25 - 1.25 * (1.0 - clearcoatSmoothness)) + 1;
        brdfData.diffuse = lerp(brdfData.diffuse, brdfData.diffuse * refractionScale, clearcoatThickness);

    //  GI
        lightingData.giColor = GlobalIllumination_LuxClearCoat(
            brdfData, addData, inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS, inputData.normalizedScreenSpaceUV,
            addData.normalWS, inputData.normalWS, inputData.viewDirectionWS, NdotV
        );

    //  Main Light
        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        #endif
            {
                lightingData.mainLightColor = LightingPhysicallyBased_LuxClearCoat(brdfData, addData, mainLight, inputData.normalWS, inputData.viewDirectionWS); 
            }

    //  Handle additional lights
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
                        lightingData.additionalLightsColor += LightingPhysicallyBased_LuxClearCoat(brdfData, addData, light, inputData.normalWS, inputData.viewDirectionWS);
                    }
                }
            #endif

            LIGHT_LOOP_BEGIN(pixelLightCount)    
                    Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
                #if defined(_LIGHT_LAYERS)
                    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif
                    {
                        lightingData.additionalLightsColor += LightingPhysicallyBased_LuxClearCoat(brdfData, addData, light, inputData.normalWS, inputData.viewDirectionWS);
                    }
            LIGHT_LOOP_END
        #endif

        FinalLighting = CalculateFinalColor(lightingData, surfaceData.alpha).xyz;

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
        //  Here we pass the flat coat normal
            MetaNormal = half3(0,0,1);
        #endif

//  End Real Lighting ----------

    #endif // End Debug

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
    half3 normalTS,

//  Surface description
    half3 albedo,
    half metallic,
    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,

//  Lighting specific inputs
    half clearcoatSmoothness,
    half clearcoatThickness,
    half3 clearcoatSpecular,

    half3 baseColor,
    half3 secondaryColor,

    bool enableSecondaryColor,
    bool enableSecondaryLobe,

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
        clearcoatSmoothness, clearcoatThickness, clearcoatSpecular, baseColor, secondaryColor, enableSecondaryColor, enableSecondaryLobe,
        lightMapUV, dynamicLightMapUV, MetaAlbedo, FinalLighting, MetaSpecular, MetaSmoothness, MetaOcclusion, MetaNormal);
}