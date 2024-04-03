// We have to mute URP's default decal implementation as it would tweak our albedo - which needs to be pure black
// as otherwise default lighting would no be stripped by the shader compiler.
// This mean that decals will use our custom lighting as well.

#ifdef _DBUFFER
    #undef _DBUFFER
    #define _CUSTOMDBUFFER
#endif

#if !defined(SHADERGRAPH_PREVIEW) || defined(LIGHTWEIGHT_LIGHTING_INCLUDED)

//  As we do not have access to the vertex lights we will make the shader always sample add lights per pixel
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        #undef _ADDITIONAL_LIGHTS_VERTEX
        #define _ADDITIONAL_LIGHTS
    #endif

    #if defined(LIGHTWEIGHT_LIGHTING_INCLUDED) || defined(UNIVERSAL_LIGHTING_INCLUDED)

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

        struct AdditionalData {
            half3   sheenColor;
        };

        half3 DirectBDRF_LuxCharlieSheen(BRDFData brdfData, AdditionalData addData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, half NdotL)
        {
        #ifndef _SPECULARHIGHLIGHTS_OFF
            float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
            float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));
            
            float NoH = saturate(dot(float3(normalWS), halfDir));
            half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));
            
            half NdotV = saturate(dot(normalWS, viewDirectionWS ));

        //  Charlie Sheen

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
            return brdfData.diffuse;
        #endif
        }

        half3 LightingPhysicallyBased_LuxCharlieSheen(BRDFData brdfData, AdditionalData addData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL)
        {
            //half NdotL = saturate(dot(normalWS, lightDirectionWS));
            half3 radiance = lightColor * (lightAttenuation * NdotL);
            return DirectBDRF_LuxCharlieSheen(brdfData, addData, normalWS, lightDirectionWS, viewDirectionWS, NdotL) * radiance;
        }

        half3 LightingPhysicallyBased_LuxCharlieSheen(BRDFData brdfData, AdditionalData addData, Light light, half3 normalWS, half3 viewDirectionWS, half NdotL)
        {
            return LightingPhysicallyBased_LuxCharlieSheen(brdfData, addData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, NdotL);
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
    half3 albedo,
    half metallic,
    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,

//  Lighting specific inputs

    half3 sheenColor,

    bool enableTransmission,
    half transmissionStrength,
    half transmissionPower,
    half transmissionDistortion,
    half transmissionShadowstrength,

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


//  /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  Real Lighting

//  Charlie Sheen specific:
    smoothness = lerp(0.0h, 0.6h, smoothness);

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
            FinalLighting = debugColor;
            MetaAlbedo = debugColor;
            MetaSpecular = specular;
            MetaSmoothness = smoothness;
            MetaOcclusion = occlusion;
            MetaNormal = normalTS;
        }
    #else
//  Debugging

    //  Do not apply energy conservation
        brdfData.diffuse = surfaceData.albedo;
        brdfData.specular = surfaceData.specular;

        AdditionalData addData;
        //addData.tangentWS = tangentWS;
        //addData.bitangentWS = bitangentWS;

    //  Charlie Sheen
        //addData.partLambdaV = 0.0h;
        //addData.anisoReflectionNormal = normalWS;
        float NdotV = dot(normalWS, viewDirectionWS);
        addData.sheenColor = sheenColor;


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

        half NdotL;

    //  Main Light
        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        #endif
            {
        
                NdotL = saturate(dot(inputData.normalWS, mainLight.direction));
                lightingData.mainLightColor = LightingPhysicallyBased_LuxCharlieSheen(brdfData, addData, mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL);

            //  Transmission
                if (enableTransmission) {
                    half3 transLightDir = mainLight.direction + inputData.normalWS * transmissionDistortion;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transmissionPower - transmissionPower);
                    lightingData.mainLightColor += brdfData.diffuse * transDot * (1.0h - NdotL) * mainLightColor * lerp(1.0h, mainLight.shadowAttenuation, transmissionShadowstrength) * transmissionStrength * 4;
                }
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
                        lightingData.additionalLightsColor += LightingPhysicallyBased_LuxCharlieSheen(brdfData, addData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL);

                    //  Transmission
                        if (enableTransmission) {
                            half3 transLightDir = light.direction + normalWS * transmissionDistortion;
                            half transDot = dot( transLightDir, -viewDirectionWS );
                            transDot = exp2(saturate(transDot) * transmissionPower - transmissionPower);
                            lightingData.additionalLightsColor += brdfData.diffuse * transDot * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, transmissionShadowstrength) * light.distanceAttenuation * transmissionStrength * 4;
                        }
                    }
                }
            #endif

            LIGHT_LOOP_BEGIN(pixelLightCount)    
                    Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
                #if defined(_LIGHT_LAYERS)
                    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                    {
                #endif
                        half3 lightColor = light.color;
                        NdotL = saturate(dot(inputData.normalWS, light.direction ));
                        lightingData.additionalLightsColor += LightingPhysicallyBased_LuxCharlieSheen(brdfData, addData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL);

                    //  Transmission
                        if (enableTransmission) {
                            half3 transLightDir = light.direction + normalWS * transmissionDistortion;
                            half transDot = dot( transLightDir, -viewDirectionWS );
                            transDot = exp2(saturate(transDot) * transmissionPower - transmissionPower);
                            lightingData.additionalLightsColor += brdfData.diffuse * transDot * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, transmissionShadowstrength) * light.distanceAttenuation * transmissionStrength * 4;
                        }
                #if defined(_LIGHT_LAYERS)
                    }
                #endif
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

    //  End Real Lighting

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

    half3 sheenColor,

    bool enableTransmission,
    half transmissionStrength,
    half transmissionPower,
    half transmissionDistortion,
    half transmissionShadowstrength,

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
        sheenColor, enableTransmission, transmissionStrength, transmissionPower, transmissionDistortion, transmissionShadowstrength,
        lightMapUV, dynamicLightMapUV, MetaAlbedo, FinalLighting, MetaSpecular, MetaSmoothness, MetaOcclusion, MetaNormal);
}