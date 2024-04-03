// We have to mute URP's default decal implementation as it would tweak our albedo - which needs to be pure black
// as otherwise default lighting would no be stripped by the shader compiler.
// This mean that decals will use our custom lighting as well.

#ifdef _DBUFFER
    #undef _DBUFFER
    #define _CUSTOMDBUFFER
#endif

// Support for accurate G-Buffer normals
// #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

#if !defined(SHADERGRAPH_PREVIEW)

//  As we do not have access to the vertex lights we will make the shader always sample add lights per pixel
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        #undef _ADDITIONAL_LIGHTS_VERTEX
        #define _ADDITIONAL_LIGHTS
    #endif

    #if defined(UNIVERSAL_LIGHTING_INCLUDED)

        struct AdditionalData {
            half3   tangentWS;
            half3   bitangentWS;
            half3   anisoReflectionNormal;

            half    specularShift;
            half3   specularTint;
            half    primarySmoothness;
            half    secondarySpecularShift;
            half3   secondarySpecularTint;
            half    secondarySmoothness;
        };

    //  /////////

        float RoughnessToBlinnPhongSpecularExponent_Lux(float roughness)
        {
            return clamp(2 * rcp(roughness * roughness) - 2, FLT_EPS, rcp(FLT_EPS));
        }

        //http://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf
        float3 ShiftTangent_Lux(float3 T, float3 N, float shift)
        {
            return normalize(T + N * shift);
        }

        // Note: this is Blinn-Phong, the original paper uses Phong.
        float3 D_KajiyaKay_Lux(float3 T, float3 H, float specularExponent)
        {
            float TdotH = dot(T, H);
            float sinTHSq = saturate(1.0 - TdotH * TdotH);

            float dirAttn = saturate(TdotH + 1.0); // Evgenii: this seems like a hack? Do we really need this?

            // Note: Kajiya-Kay is not energy conserving.
            // We attempt at least some energy conservation by approximately normalizing Blinn-Phong NDF.
            // We use the formulation with the NdotL.
            // See http://www.thetenthplanet.de/archives/255.
            float n    = specularExponent;
            float norm = (n + 2) * rcp(2 * PI);

            return dirAttn * norm * PositivePow(sinTHSq, 0.5 * n);
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


        half3 LightingHair_Lux(
            half3 albedo,
            half3 specular,
            Light light,
            
            half3 normalWS,
            half geomNdotV,
            half3 viewDirectionWS,

            half roughness1,
            half roughness2,
            half3 t1,
            half3 t2,
            half3 specularTint,
            half3 secondarySpecularTint,
            bool enableSecondaryLobe,
            half rimTransmissionIntensity
        )
        {
            half NdotL = dot(normalWS, light.direction);
            half LdotV = dot(light.direction, viewDirectionWS);
            float invLenLV = rsqrt(max(2.0 * LdotV + 2.0, FLT_EPS));

            float3 lightDirectionWSFloat3 = float3(light.direction);
            float3 halfDir = (lightDirectionWSFloat3 + float3(viewDirectionWS)) * invLenLV;

            half3 hairSpec1 = specularTint * D_KajiyaKay_Lux(t1, halfDir, roughness1);
            
            half3 hairSpec2 = enableSecondaryLobe ? secondarySpecularTint * D_KajiyaKay_Lux(t2, halfDir, roughness2) : (half3)0.0;

            float NdotH = saturate(dot(normalWS, halfDir));
            half LdotH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

            half3 F = F_Schlick(specular, LdotH);

        //  Reflection
            half3 specR = 0.25h * F * (hairSpec1 + hairSpec2) * saturate(NdotL) * saturate(geomNdotV * HALF_MAX);

        //  Transmission // Yibing's and Morten's hybrid scatter model hack.
            half scatterFresnel1 = pow(saturate(-LdotV), 9.0h) * pow(saturate(1.0h - geomNdotV * geomNdotV), 12.0h);
        //  This looks shitty (using 20)   
            //half scatterFresnel2 = saturate(PositivePow((1.0h - geomNdotV), 20.0h));
            half scatterFresnel2 = saturate(Pow4(1.0h - geomNdotV));
            half transmission = scatterFresnel1 + rimTransmissionIntensity * scatterFresnel2;
            half3 specT = albedo * transmission;

            half3 diffuse = albedo * saturate(NdotL);

        //  combine
            half3 result = (diffuse + specR + specT) * light.color * light.distanceAttenuation * light.shadowAttenuation; 
            return result;
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

    bool strandirection,
    half specularShift,
    half3 specularTint,
    half primarySmoothness,
    bool enableSecondaryLobe,
    half secondarySpecularShift,
    half3 secondarySpecularTint,
    half secondarySmoothness,
    half rimTransmissionIntensity,

    bool enableVFACE,
    bool isFrontFace,

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

    if (enableVFACE)
    {
        normalTS.z *= isFrontFace ? 1.0h : -1.0h;
    }

    if (enableNormalMapping) {
        normalWS = TransformTangentToWorld(normalTS, half3x3(tangentWS.xyz, bitangentWS.xyz, normalWS.xyz));
    }
    normalWS = NormalizeNormalPerPixel(normalWS);

//  GI Lighting
//  We are using the base normalWS here. So decal normals will not affect GI like in all other shaders.
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
        surfaceData.normalTS = normalTS;   
    }

//  Remap
    primarySmoothness *= surfaceData.smoothness;
    secondarySmoothness *= surfaceData.smoothness;
    surfaceData.smoothness = primarySmoothness;
    
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
            MetaSpecular = surfaceData.specular;
            MetaSmoothness = surfaceData.smoothness;
            MetaOcclusion = occlusion;
            MetaNormal = normalTS;
        }
    #else

    //  Do not apply energy conservation - we have to use surfaceData as it may contain decal data.
        //brdfData.diffuse = surfaceData.albedo;
        //brdfData.specular = surfaceData.specular;

        AdditionalData addData;
    //  Adjust tangentWS in case normal mapping is active
        if (enableNormalMapping) {   
            tangentWS = Orthonormalize(tangentWS, inputData.normalWS);
        }           
        addData.tangentWS = tangentWS;
        addData.bitangentWS = cross(inputData.normalWS, tangentWS);

        half3 strandDirWS = strandirection ? addData.tangentWS : addData.bitangentWS;
    
    //  Set reflection normal and roughness – derived from GetGGXAnisotropicModifiedNormalAndRoughness and optimized for Hair
        half stretch = saturate(1.5h * sqrt(brdfData.perceptualRoughness));
        addData.anisoReflectionNormal = GetAnisotropicModifiedNormal(strandDirWS, inputData.normalWS, inputData.viewDirectionWS, stretch);
        half iblPerceptualRoughness = brdfData.perceptualRoughness * 0.2;

    //  Override perceptual roughness for ambient specular reflections
        //brdfData.perceptualRoughness = iblPerceptualRoughness;

        half4 shadowMask = CalculateShadowMask(inputData);
        AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        uint meshRenderingLayers = GetMeshRenderingLayer();

        Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
        half3 mainLightColor = mainLight.color;

        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

        LightingData lightingData = CreateLightingData(inputData, surfaceData);

    //  In order to use probe blending and proper AO we have to use the new GlobalIllumination function
        lightingData.giColor = GlobalIllumination_LuxAniso(
            brdfData,
            brdfData,   // brdfDataClearCoat,
            0,          // surfaceData.clearCoatMask
            inputData.bakedGI,
            aoFactor.indirectAmbientOcclusion,
            inputData.positionWS,
            addData.anisoReflectionNormal,
            inputData.normalWS,
            inputData.viewDirectionWS,
            inputData.normalizedScreenSpaceUV
        );

    //  Convert primary and secondary smoothness to BlinnPhongExponent
        half primaryRoughness = PerceptualSmoothnessToPerceptualRoughness(primarySmoothness); // * saturate(noise.r * 2) );
        half roughness1 = PerceptualRoughnessToRoughness(primaryRoughness);
        half pbRoughness1 = RoughnessToBlinnPhongSpecularExponent_Lux(roughness1);
        half3 t1 = ShiftTangent_Lux(strandDirWS, inputData.normalWS, specularShift);

        //secondarySmoothness = 0;
        half roughness2 = 0;
        half pbRoughness2 = 0;
        half3 t2 = 0;

        if (enableSecondaryLobe)
        {
            half secondaryRoughness = PerceptualSmoothnessToPerceptualRoughness(secondarySmoothness); // * saturate(noise.r * 2) );
            roughness2 = PerceptualRoughnessToRoughness(secondaryRoughness);
            pbRoughness2 = RoughnessToBlinnPhongSpecularExponent_Lux(roughness2);
            t2 = ShiftTangent_Lux(strandDirWS, inputData.normalWS, secondarySpecularShift);
        }

        half geomNdotV = dot(inputData.normalWS, inputData.viewDirectionWS);


    //  Main Light
        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        #endif
            {
                lightingData.mainLightColor = LightingHair_Lux(
                    surfaceData.albedo, surfaceData.specular, mainLight, inputData.normalWS,
                    geomNdotV, inputData.viewDirectionWS,
                    pbRoughness1, pbRoughness2,
                    t1, t2, specularTint, secondarySpecularTint, enableSecondaryLobe, rimTransmissionIntensity);
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
                        lightingData.additionalLightsColor += LightingHair_Lux(
                            surfaceData.albedo, surfaceData.specular, light, inputData.normalWS,
                            geomNdotV, inputData.viewDirectionWS,
                            pbRoughness1, pbRoughness2,
                            t1, t2, specularTint, secondarySpecularTint, enableSecondaryLobe, rimTransmissionIntensity);
                    }
                }
            #endif

            LIGHT_LOOP_BEGIN(pixelLightCount)    
                    Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
                #if defined(_LIGHT_LAYERS)
                    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif
                    {
                        lightingData.additionalLightsColor += LightingHair_Lux(
                            surfaceData.albedo, surfaceData.specular, light, inputData.normalWS,
                            geomNdotV, inputData.viewDirectionWS,
                            pbRoughness1, pbRoughness2,
                            t1, t2, specularTint, secondarySpecularTint, enableSecondaryLobe, rimTransmissionIntensity);
                    }
            LIGHT_LOOP_END
        #endif

        FinalLighting = CalculateFinalColor(lightingData, surfaceData.alpha).xyz;

//FinalLighting = enableSecondaryLobe;

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
    bool strandirection,
    half specularShift,
    half3 specularTint,
    half primarySmoothness,
    bool enableSecondaryLobe,
    half secondarySpecularShift,
    half3 secondarySpecularTint,
    half secondarySmoothness,
    half rimTransmissionIntensity,

    bool enableVFACE,
    bool isFrontFace,

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
        strandirection, specularShift, specularTint, primarySmoothness, enableSecondaryLobe, secondarySpecularShift, secondarySpecularTint, secondarySmoothness, rimTransmissionIntensity,
        enableVFACE, isFrontFace,
        lightMapUV, dynamicLightMapUV, MetaAlbedo, FinalLighting, MetaSpecular, MetaSmoothness, MetaOcclusion, MetaNormal);
}