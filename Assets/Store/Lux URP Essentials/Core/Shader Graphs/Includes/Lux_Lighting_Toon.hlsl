
#if !defined(SHADERGRAPH_PREVIEW) || defined(UNIVERSAL_LIGHTING_INCLUDED)

//  As we do not have access to the vertex lights we will make the shader always sample add lights per pixel
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        #undef _ADDITIONAL_LIGHTS_VERTEX
        #define _ADDITIONAL_LIGHTS
    #endif

    #if defined(UNIVERSAL_LIGHTING_INCLUDED)

        half3 LightingSpecular_Toon (Light light, half lightingRemap, half3 normalWS, half3 viewDirectionWS, half3 specular, half specularSmoothness, half smoothness, half specularStep, half specularUpper){
            half3 halfVec = SafeNormalize(light.direction + viewDirectionWS);
            half NdotH = saturate(dot(normalWS, halfVec));
            half modifier = pow(NdotH /* lightingRemap*/, specularSmoothness);
        //  Normalization? Na, we just multiply by smoothness in the return statement.
            // #define ONEOVERTWOPI 0.159155h
            // half normalization = (specularSmoothness + 1) * ONEOVERTWOPI;
        //  Sharpen / CHECK: This deforms the highlight?!
            half modifierSharpened = smoothstep(specularStep, specularUpper, modifier);
            return light.color * specular * modifierSharpened * smoothness;
        }

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
    half3 shadedAlbedo,

    bool enableSpecular,
    half3 specular,
    half smoothness,
    half occlusion,

//  Smoothsteps
    half diffuseStep,
    half diffuseFalloff,
    half specularStep,
    half specularFalloff,
    half shadowFalloff,
    half shadowBiasDirectional,
    half shadowBiasAdditional,

//  Colorize shaded parts
    bool colorizeMainLight,
    bool colorizeAddLights,

//  Rim Lighting
    bool enableRimLighting,
    half rimPower,
    half rimFalloff,
    half4 rimColor,
    half rimAttenuation,

//  Lightmapping
    float2 lightMapUV,

//  Final lit color
    out half3 Lighting,
    out half3 MetaAlbedo,
    out half3 MetaSpecular
)
{

#if defined(SHADERGRAPH_PREVIEW) || !defined(UNIVERSAL_LIGHTING_INCLUDED)
    Lighting = albedo;
    MetaAlbedo = half3(0,0,0);
    MetaSpecular = half3(0,0,0);
#else

//  Real Lighting ----------


    half3 tnormal = normalWS;
    if (enableNormalMapping) {
        tnormal = TransformTangentToWorld(normalTS, half3x3(tangentWS.xyz, bitangentWS.xyz, normalWS.xyz));
    }
    normalWS = NormalizeNormalPerPixel(tnormal);
    viewDirectionWS = SafeNormalize(viewDirectionWS);

//  Remap values
    half diffuseUpper = saturate(diffuseStep + diffuseFalloff);
    //rimFalloff *= 20.0h;

//  GI Lighting
    half3 bakedGI;
    #ifdef LIGHTMAP_ON
        lightMapUV = lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
        bakedGI = SAMPLE_GI(lightMapUV, half3(0,0,0), normalWS);
    #else
//  CHECK: Do we have3 to multiply SH with occlusion here?
        bakedGI = SampleSH(normalWS) * occlusion; 
    #endif

//  Get Shadow Sampling Coords / Unfortunately per pixel...
    #if SHADOWS_SCREEN
        float4 clipPos = TransformWorldToHClip(positionWS);
        float4 shadowCoord = ComputeScreenPos(clipPos);
    #else
        float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
    #endif

    Light mainLight = GetMainLight(shadowCoord);
    //mainLight.shadowAttenuation = smoothstep(0.0h, shadowFalloff, mainLight.shadowAttenuation);
    mainLight.shadowAttenuation = smoothstep( (1 - shadowFalloff) * shadowFalloff, shadowFalloff, mainLight.shadowAttenuation);

    MixRealtimeAndBakedGI(mainLight, normalWS, bakedGI, half4(0, 0, 0, 0));

//  Set up Lighting
    half lightIntensity = 0;
    half3 specularLighting = 0;
    half3 rimLighting = 0;
    half3 lightColor = 0;

    half luminance;
    
//  Main Light
    half NdotL = saturate(dot(normalWS, mainLight.direction)); 
    NdotL = smoothstep(diffuseStep, diffuseUpper, NdotL);
//  NdotL = (dot(normalWS, mainLight.direction));
//  NdotL = (NdotL + 1) * 0.5;
//  NdotL = floor(NdotL * 4) * 0.25;

    half atten = NdotL * mainLight.distanceAttenuation * saturate(shadowBiasDirectional + mainLight.shadowAttenuation);

    if (colorizeMainLight) {
        lightColor = mainLight.color * mainLight.distanceAttenuation;  
    }
    else {
        lightColor = mainLight.color * atten;
    }
    luminance = Luminance(mainLight.color); 
    lightIntensity += luminance * atten;

//  Specular
    half specularSmoothness;
    half3 spec;
    half specularUpper;
    if (enableSpecular) {
        specularSmoothness = exp2(10 * smoothness + 1);
        specularUpper = saturate(specularStep + specularFalloff * (1.0h + smoothness));
        spec = LightingSpecular_Toon(mainLight, NdotL, normalWS, viewDirectionWS, specular, specularSmoothness, smoothness, specularStep, specularUpper);
        specularLighting = spec * atten;
    }

//  Rim Lighting
    if (enableRimLighting) {
        half rim = saturate(1.0h - saturate( dot(normalWS, viewDirectionWS)) );
        //rimLighting = smoothstep(rimPower, rimPower + rimFalloff, rim) * rimColor.rgb;
    //  Stabilize rim
        float delta = fwidth(rim);
        rimLighting = smoothstep(rimPower - delta, rimPower + rimFalloff  + delta, rim) * rimColor.rgb;
    }

//  Handle additional lights
    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint i = 0u; i < pixelLightCount; ++i) {
            Light light = GetAdditionalLight(i, positionWS);
            //light.shadowAttenuation = smoothstep(0.0h, shadowFalloff, light.shadowAttenuation);
            light.shadowAttenuation = smoothstep( (1 - shadowFalloff) * shadowFalloff, shadowFalloff, light.shadowAttenuation);

            NdotL = saturate(dot(normalWS, light.direction)); 
            NdotL = smoothstep(diffuseStep, diffuseUpper, NdotL);
            atten = NdotL * light.distanceAttenuation * saturate(shadowBiasAdditional + light.shadowAttenuation);
   
            if(colorizeAddLights) { 
                lightColor += light.color * light.distanceAttenuation;
            }
            else {
                lightColor += light.color * atten;
            }

            luminance = Luminance(light.color); //dot(light.color, half3(0.2126729h,  0.7151522h, 0.0721750h) );
            lightIntensity += luminance * atten;
            if (enableSpecular) {
                spec = LightingSpecular_Toon(light, NdotL, normalWS, viewDirectionWS, specular, specularSmoothness, smoothness, specularStep, specularUpper);
                specularLighting += spec * atten;
            }
        }
    #endif

//  Combine Lighting
    half3 litAlbedo = lerp(shadedAlbedo, albedo, saturate(lightIntensity.xxx) );
    Lighting =
    //  ambient diffuse lighting
        bakedGI * albedo 			// litAlbedo // used to use this?
    //  direct diffuse lighting
        + litAlbedo * lightColor
        + (specularLighting * lightIntensity
        + rimLighting * lerp(1.0h, lightIntensity, rimAttenuation) )
        * lightColor
    ;


//  Set Albedo for meta pass
    #if defined(UNIVERSAL_META_PASS_INCLUDED)
        Lighting = half3(0,0,0);
        MetaAlbedo = albedo;
        MetaSpecular = half3(0.02,0.02,0.02);
    #else
        MetaAlbedo = half3(0,0,0);
        MetaSpecular = half3(0,0,0);
    #endif

//  End Real Lighting ----------

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
    half3 shadedAlbedo,

    bool enableSpecular,
    half3 specular,
    half smoothness,
    half occlusion,

//  Smoothsteps
    half diffuseStep,
    half diffuseFalloff,
    half specularStep,
    half specularFalloff,
    half shadowFalloff,
    half shadowBiasDirectional,
    half shadowBiasAdditional,

//  Colorize shaded parts
    bool colorizeMainLight,
    bool colorizeAddLights,

//  Rim Lighting
    bool enableRimLighting,
    half rimPower,
    half rimFalloff,
    half4 rimColor,
    half rimAttenuation,

//  Lightmapping
    float2 lightMapUV,

//  Final lit color
    out half3 Lighting,
    out half3 MetaAlbedo,
    out half3 MetaSpecular
)
{
    Lighting_half(
        positionWS, viewDirectionWS, normalWS, tangentWS, bitangentWS, enableNormalMapping, normalTS, 
        albedo, shadedAlbedo, enableSpecular, specular, smoothness, occlusion,
        diffuseStep, diffuseFalloff, specularStep, specularFalloff, shadowFalloff, shadowBiasDirectional, shadowBiasAdditional, colorizeMainLight, colorizeAddLights,
        enableRimLighting, rimPower, rimFalloff, rimColor, rimAttenuation,
        lightMapUV, Lighting, MetaAlbedo, MetaSpecular
    );
}