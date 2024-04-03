void FlatNormal_float(

//  Base inputs
    float3 positionWS,
    float3 tangentWS,
    float3 bitangentWS,


    bool enableNormalMap,
    half3 normalTS,

    out half3 normalWS
)
{

//  Create custom per vertex normal // SafeNormalize does not work here on Android?!
    half3 tnormal = half3( normalize( cross(ddy(positionWS), ddx(positionWS)) ) );
//  TODO: Vulkan on Android here shows inverted normals?
    #if defined(SHADER_API_VULKAN)
        tnormal *= -1;
    #endif

    if(enableNormalMap)
    {
    //  Adjust tangentWS as we have tweaked normalWS
        tangentWS = Orthonormalize(tangentWS, tnormal);
        tnormal = TransformTangentToWorld(normalTS, half3x3(tangentWS, bitangentWS, tnormal));
        tnormal = normalize(tnormal);
    }

    normalWS = tnormal;

}