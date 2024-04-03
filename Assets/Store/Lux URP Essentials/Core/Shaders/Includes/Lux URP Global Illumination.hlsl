half3 LuxSplitGlobalIllumination(
    BRDFData brdfData,
    float clearCoatMask,
    half3 bakedGI,
    half occlusion,
//  Lux
    half specOcclusion,
    float3 positionWS,
    half3 normalWS,
    half3 viewDirectionWS
)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);

//  Lux: Instead of "adding" occlusion to the final result we do it per component
    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, 1.0h) * specOcclusion;

    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

    if (IsOnlyAOLightingFeatureEnabled())
    {
        color = half3(1,1,1); // "Base white" for AO debug lighting mode
    }
//  Lux: Instead of "adding" occlusion to the final result we do it per component
    //return color * occlusion;
#endif
}