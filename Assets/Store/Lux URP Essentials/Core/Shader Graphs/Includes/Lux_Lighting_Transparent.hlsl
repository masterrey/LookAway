#if !defined(SHADERGRAPH_PREVIEW) || defined(LIGHTWEIGHT_LIGHTING_INCLUDED)

//  As we do not have access to the vertex lights we will make the shader always sample add lights per pixel
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        #undef _ADDITIONAL_LIGHTS_VERTEX
        #define _ADDITIONAL_LIGHTS
    #endif
#endif


void Lighting_half(

//  Base inputs
    float3 positionWS,
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

//  Lightmapping
    float2 staticLightmapUV,
    float2 dynamicLightMapUV,

    half3 vertexSH,
    float4 ProbeOcclusion,

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

//  This fixes the fog issue
    #if defined (_ALPHAPREMULTIPLY_ON)
        unity_FogColor *= alpha;
    //  Two Materials Setup: We would have to tweak alpha according to fog intensity? which we do not have.
    #endif

//  /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  Real Lighting

//  Has to be zero initialized    
    half3x3 tangentToWorld = (half3x3)0;

    if (enableNormalMapping)
    {
        tangentToWorld = half3x3(tangentWS.xyz, bitangentWS.xyz, normalWS.xyz);
        normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
    }
    normalWS = NormalizeNormalPerPixel(normalWS);
    viewDirectionWS = SafeNormalize(viewDirectionWS);

//  Reconstruct positionCS somehow...
    float4 positionCS = TransformWorldToHClip(positionWS);
    
    float2 normalizedScreenSpaceUV = positionCS.xy;
    normalizedScreenSpaceUV /= positionCS.w;
    normalizedScreenSpaceUV = normalizedScreenSpaceUV * 0.5f + 0.5f;
    #if UNITY_UV_STARTS_AT_TOP
        normalizedScreenSpaceUV.y = 1.0 - normalizedScreenSpaceUV.y;
    #endif

//  GI Lighting

//  These have to be zero initialized, otherwise decals and debug error!
    half3 bakedGI = (half3)0.0;
    half4 t_shadowMask = (half4)0.0;

    #if defined(DYNAMICLIGHTMAP_ON)
        dynamicLightMapUV = dynamicLightMapUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
        bakedGI = SAMPLE_GI(staticLightmapUV, dynamicLightmapUV, vertexSH, diffuseNormalWS);
        staticLightmapUV = staticLightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
        t_shadowMask = SAMPLE_SHADOWMASK(staticLightmapUV);
    #elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
        bakedGI = SAMPLE_GI(
            vertexSH,                                               
            GetAbsolutePositionWS(positionWS),
            normalWS,
            viewDirectionWS,
            normalizedScreenSpaceUV * _ScreenSize.xy,
            ProbeOcclusion,
            t_shadowMask  
        );
    #else
        staticLightmapUV = staticLightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
        bakedGI = SAMPLE_GI(staticLightmapUV, vertexSH, normalWS);
        t_shadowMask = SAMPLE_SHADOWMASK(staticLightmapUV);
    #endif

//  /////////////////////////////
//  Structs - Fill standard URP structs so we can use the built in functions
    InputData inputData = (InputData)0;
    {
        inputData.positionWS = positionWS;
        inputData.normalWS = normalWS;
        inputData.viewDirectionWS = viewDirectionWS;
        inputData.bakedGI = bakedGI;
        #if _MAIN_LIGHT_SHADOWS_SCREEN
            inputData.shadowCoord = ComputeScreenPos(positionCS);
        #else
            inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
        #endif
        inputData.normalizedScreenSpaceUV = normalizedScreenSpaceUV;
        inputData.shadowMask = t_shadowMask;

        #if defined(DEBUG_DISPLAY)
            inputData.positionCS = positionCS; //?
            #if defined(DYNAMICLIGHTMAP_ON)
                inputData.dynamicLightmapUV = dynamicLightmapUV;
            #endif
            #if defined(LIGHTMAP_ON)
                inputData.staticLightmapUV = staticLightmapUV;
            #else
                inputData.vertexSH = vertexSH;
            #endif
        #endif
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
//  /////////////////////////////
    
    #if defined(_SPECULARHIGHLIGHTS_OFF)
        bool specularHighlightsOff = true;
    #else
        bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;
    //InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);
    InitializeBRDFData(surfaceData, brdfData);

//  Debugging
    #if defined(DEBUG_DISPLAY)
        // half4 debugColor;
        // if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
        // {
        //     //return debugColor;
        //     FinalLighting = debugColor.rgb;
        //     MetaAlbedo = debugColor.rgb;
        //     MetaSpecular = specular;
        //     MetaSmoothness = smoothness;
        //     MetaOcclusion = occlusion;
        //     MetaNormal = normalTS;
        // }
        FinalLighting = 0;
        MetaAlbedo = albedo;
        MetaSpecular = specular;
        MetaSmoothness = smoothness;
        MetaOcclusion = occlusion;
        MetaNormal = normalTS;
    #else
        half4 shadowMask = CalculateShadowMask(inputData);
        AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        uint meshRenderingLayers = GetMeshRenderingLayer();
        Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

        // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
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

    //  Main Light
    #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
        {
            lightingData.mainLightColor = LightingPhysicallyBased(
                brdfData,
                brdfData,                       // brdfDataClearCoat,
                mainLight,
                inputData.normalWS,
                inputData.viewDirectionWS,
                0,                              // surfaceData.clearCoatMask,
                specularHighlightsOff
            );
        }

    //  Handle additional lights
        #if defined(_ADDITIONAL_LIGHTS)
            uint pixelLightCount = GetAdditionalLightsCount();

            #if USE_FORWARD_PLUS
                [loop] for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
                {
                    FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
                    Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
                #ifdef _LIGHT_LAYERS
                    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                #endif
                    {
                        lightingData.additionalLightsColor += LightingPhysicallyBased(
                            brdfData,
                            brdfData,                       // brdfDataClearCoat,
                            mainLight,
                            inputData.normalWS,
                            inputData.viewDirectionWS,
                            0,                              // surfaceData.clearCoatMask,
                            specularHighlightsOff
                        );
                    }
                }
            #endif

            LIGHT_LOOP_BEGIN(pixelLightCount)
                Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            #ifdef _LIGHT_LAYERS
                if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
                {
                    lightingData.additionalLightsColor += LightingPhysicallyBased(
                        brdfData,
                        brdfData,                       // brdfDataClearCoat,
                        light,
                        inputData.normalWS,
                        inputData.viewDirectionWS,
                        0,                              // surfaceData.clearCoatMask,
                        specularHighlightsOff
                    );
                }
            LIGHT_LOOP_END
        #endif

        #if defined(_ADDITIONAL_LIGHTS_VERTEX)
            lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
        #endif

        FinalLighting = CalculateFinalColor(lightingData, surfaceData.alpha).rgb;

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

    #endif // END: Debug

#endif
}

// Unity 2019.1. needs a float version

void Lighting_float(

//  Base inputs
    float3 positionWS,
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

//  Lightmapping
    float2 staticLightmapUV,
    float2 dynamicLightMapUV,

    half3 vertexSH,
    float4 ProbeOcclusion,

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
        positionWS, viewDirectionWS, normalWS, tangentWS, bitangentWS, enableNormalMapping, normalTS, 
        albedo, metallic, specular, smoothness, occlusion, alpha,
        staticLightmapUV, dynamicLightMapUV, vertexSH, ProbeOcclusion,
        MetaAlbedo, FinalLighting, MetaSpecular, MetaSmoothness, MetaOcclusion, MetaNormal
    );
}