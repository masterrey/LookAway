//#if !defined(SHADERGRAPH_PREVIEW)
#if !defined(SHADERGRAPH_PREVIEW) || defined(LIGHTWEIGHT_LIGHTING_INCLUDED)

//  As we do not have access to the vertex lights we will make the shder always sample add lights per pixel
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        #undef _ADDITIONAL_LIGHTS_VERTEX
        #define _ADDITIONAL_LIGHTS
    #endif
#endif


void Lighting_half(

//  Base inputs
    float3 positionWS,
    half3 viewDirectionWS,

//  Surface description
    half3 albedo,
    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,
 
    float2 lightMapUV,

//  Final lit color
    out half3 Lighting,
    out half3 MetaAlbedo,
    out half3 MetaSpecular
)
{

//#if defined(SHADERGRAPH_PREVIEW)
#if defined(SHADERGRAPH_PREVIEW) || ( !defined(LIGHTWEIGHT_LIGHTING_INCLUDED) && !defined(UNIVERSAL_LIGHTING_INCLUDED) )
    Lighting = albedo;
    MetaAlbedo = half3(0,0,0);
    MetaSpecular = half3(0,0,0);
#else

//  Real Lighting ----------
    half metallic = 0;

    half3 tnormal = normalize(cross(ddy(positionWS), ddx(positionWS)));
    half3 normalWS = tnormal;

    viewDirectionWS = SafeNormalize(viewDirectionWS);

//  GI Lighting
    half3 bakedGI;
    #ifdef LIGHTMAP_ON
        lightMapUV = lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
        bakedGI = SAMPLE_GI(lightMapUV, half3(0,0,0), normalWS);
    #else
//  CHECK: Do we have3 to multiply SH with occlusion here?
        bakedGI = SampleSH(normalWS) * occlusion; 
    #endif

    BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);

//  Get Shadow Sampling Coords / Unfortunately per pixel...
    #if SHADOWS_SCREEN
        float4 clipPos = TransformWorldToHClip(positionWS);
        float4 shadowCoord = ComputeScreenPos(clipPos);
    #else
        float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
    #endif

    Light mainLight = GetMainLight(shadowCoord);
    MixRealtimeAndBakedGI(mainLight, normalWS, bakedGI, half4(0, 0, 0, 0));

    Lighting = GlobalIllumination(brdfData, bakedGI, occlusion, normalWS, viewDirectionWS);
    Lighting += LightingPhysicallyBased(brdfData, mainLight, normalWS, viewDirectionWS);

    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint i = 0u; i < pixelLightCount; ++i)
        {
            Light light = GetAdditionalLight(i, positionWS);
            Lighting += LightingPhysicallyBased(brdfData, light, normalWS, viewDirectionWS);
        }
    #endif

    //#ifdef _ADDITIONAL_LIGHTS_VERTEX
    //    Lighting += inputData.vertexLighting * brdfData.diffuse;
    //#endif

//  Set Albedo for meta pass
    #if defined(LIGHTWEIGHT_META_PASS_INCLUDED)
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

//  Surface description
    half3 albedo,
    half3 specular,
    half smoothness,
    half occlusion,
    half alpha,


    float2 lightMapUV,
 

//  Final lit color
    out half3 Lighting,
    out half3 MetaAlbedo,
    out half3 MetaSpecular
)
{
    Lighting_half(
        positionWS, viewDirectionWS, 
        albedo, specular, smoothness, occlusion, alpha,
        lightMapUV,
        Lighting, MetaAlbedo, MetaSpecular
    );
}