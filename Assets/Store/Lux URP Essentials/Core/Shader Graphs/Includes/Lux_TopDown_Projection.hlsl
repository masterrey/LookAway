void TopDownProjection_half(

//  Base inputs
    half3   NormalWS,
    half3   TangentWS,
    half3   BitangentWS,
    float3  PositionAWS,
    half3   ViewDirWS,

    half3   Albedo,
    half3   NormalTS,
    half    Smoothness,
    half    Occlusion,
    half    Metallic,

    half    TopDownMask,
    half3   TopDownAlbedo,
    half3   TopDownNormalTS,
    half    TopDownMetallic,
    half    TopDownOcclusion,
    half    TopDownSmoothness,

    half    TopDownNormalLimit,
    half    TopDownSharpness,
    half    TopDownLowerPixelNormalInfluence,
    half    TopDownLowerNormalMinStrength,

    bool    TopDownFuzz,
    half    TopDownFuzzStrength,
    half    TopDownFuzzPower,
    half    TopDownFuzzBias,


    out half3 Albedo_o,
    out half3 NormalWS_o,
    out half Smoothness_o,
    out half Occlusion_o,
    out half Metallic_o,
    out half Blend_o
)
{

    half3x3 TangentToWorld = half3x3(TangentWS, BitangentWS, NormalWS);
    half3 normalWS = TransformTangentToWorld(NormalTS, TangentToWorld);
    

//  Calculate blend factor
    half blendFactor = lerp(NormalWS.y, normalWS.y, TopDownLowerPixelNormalInfluence);
//  Prevent projected texture from gettings stretched by masking out steep faces
    blendFactor = saturate( lerp(-TopDownNormalLimit, 1, blendFactor) );

    blendFactor = smoothstep(1.0h - TopDownMask, 1.0h, blendFactor); 

//  Sharpen blend
    blendFactor = saturate(blendFactor / TopDownSharpness);
    half normalBlendFactor = blendFactor;
    
    //blendFactor *= blendFactor * blendFactor * blendFactor;

//  Calculate normal in world space
    NormalWS_o = normalWS;
//  Use Reoriented Normal Mapping to bring the top down normal into world space
    half3 n1 = lerp(NormalWS, normalWS, saturate(1.0h - normalBlendFactor + TopDownLowerNormalMinStrength).xxx );
//  We must apply some crazy swizzling here: Swizzle world space to tangent space
    n1 = n1.xzy;
    half3 n2 = TopDownNormalTS.xyz;
    n1.z += 1.0h;
    n2.xy *= -1.0h;
    half3 topDownNormal = n1 * dot(n1, n2) / max(0.001, n1.z) - n2;
//  Swizzle tangent space to world space
    topDownNormal = topDownNormal.xzy;
//  Finally we blend both normals in world space 
    NormalWS_o = lerp(NormalWS_o, topDownNormal, normalBlendFactor.xxx );

    half3 topDownAlbedo = TopDownAlbedo;

//  Simple Fuzz
    if (TopDownFuzz)
    {
        half NdotV = dot(NormalWS_o, ViewDirWS);
        half fuzz = exp2( (1.0h - NdotV) * TopDownFuzzPower - TopDownFuzzPower) + TopDownFuzzBias;
        topDownAlbedo = topDownAlbedo * (fuzz * TopDownFuzzStrength + 1.0h);
    }

//  Blend all other parameters
    Albedo_o = lerp(Albedo, topDownAlbedo, blendFactor.xxx);
    Smoothness_o = lerp(Smoothness, TopDownSmoothness, blendFactor);
    Occlusion_o = lerp(Occlusion, TopDownOcclusion, blendFactor);
    Metallic_o = lerp(Metallic, TopDownMetallic, blendFactor);

    Blend_o = blendFactor;

}


void TopDownProjection_float(

//  Base inputs
    half3   NormalWS,
    half3   TangentWS,
    half3   BitangentWS,
    float3  PositionAWS,
    half3   ViewDirWS,

    half3   Albedo,
    half3   NormalTS,
    half    Smoothness,
    half    Occlusion,
    half    Metallic,

    half    TopDownMask,
    half3   TopDownAlbedo,
    half3   TopDownNormalTS,
    half    TopDownMetallic,
    half    TopDownOcclusion,
    half    TopDownSmoothness,

    half    TopDownNormalLimit,
    half    TopDownSharpness,
    half    TopDownLowerPixelNormalInfluence,
    half    TopDownLowerNormalMinStrength,
    
    bool    TopDownFuzz,
    half    TopDownFuzzStrength,
    half    TopDownFuzzPower,
    half    TopDownFuzzBias,

    out half3 Albedo_o,
    out half3 NormalWS_o,
    out half Smoothness_o,
    out half Occlusion_o,
    out half Metallic_o,
    out half Blend_o
)
{
    TopDownProjection_half(
        NormalWS, TangentWS, BitangentWS, PositionAWS, ViewDirWS,
        Albedo, NormalTS, Smoothness, Occlusion, Metallic,
        TopDownMask, TopDownAlbedo, TopDownNormalTS, TopDownMetallic, TopDownOcclusion, TopDownSmoothness,
        TopDownNormalLimit, TopDownSharpness, TopDownLowerPixelNormalInfluence, TopDownLowerNormalMinStrength,
        TopDownFuzz, TopDownFuzzStrength, TopDownFuzzPower, TopDownFuzzBias,
        Albedo_o, NormalWS_o, Smoothness_o, Occlusion_o, Metallic_o, Blend_o 
    );
}
