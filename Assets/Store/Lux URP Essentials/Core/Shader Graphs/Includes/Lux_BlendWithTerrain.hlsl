float DecodeFloatRG( float2 enc )
{
    float2 kDecodeDot = float2(1.0, 1/255.0);
    return dot(enc, kDecodeDot);
}

half PowTwo(half val)
{
    return val * val;
}

half3 ReorientNormal(in half3 u, in half3 t, in half3 s) {
    // Build the shortest-arc quaternion
    half4 q = half4(cross(s, t), dot(s, t) + 1) / max(0.001, sqrt(2 * (dot(s, t) + 1)) ); // May produce NANs in vertex shaders!
    // Rotate the normal
    return u * (q.w * q.w - dot(q.xyz, q.xyz)) + 2 * q.xyz * dot(q.xyz, u) + 2 * q.w * cross(q.xyz, u);
}

half3 ReorientNormalTS(half3 n1, half3 n2) {
    n1 += half3( 0,  0, 1);
    n2 *= half3(-1, -1, 1);
    return n1 * dot(n1, n2) / max(0.001, n1.z) - n2;
}

half3x3 GetRotationMatrix(half3 axis, half angle)
{
    //axis = normalize(axis); // moved to calling function
    #ifdef OPENGL
        half s = sin(angle);
        half c = cos(angle);
    #else 
        half s;
        half c;
        sincos(angle, s, c);
    #endif
    half oc = 1.0 - c;

    return half3x3 (oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s,
        oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s,
        oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c);
}

void BlendWithTerrainVert_float
(
    float3 positionOS,
    half3  normalOS,
    half3  tangentOS,
    float3 positionAWS,


    out float3 o_positionOS,
    out half3 o_normalOS,
    out half3 o_tangentOS,

    out half o_blend
)
{

    o_positionOS = positionOS;
    o_normalOS = normalOS;
    o_tangentOS = tangentOS;
    o_blend = 0;

    if (!_BlendPerPixel)
    {
        float2 terrainUV = (positionAWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
        terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;
        half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
        float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;

    //  Get terrain normal and bring it into object space
        half3 terrainNormal;
        terrainNormal.xz = terrainSample.ba * 2.0 - 1.0;
        terrainNormal.y = sqrt(1.0 - saturate(dot(terrainNormal.xz, terrainNormal.xz)));
        //terrainNormal = normalize(terrainNormal); // does not help
        half3 terrainNormalOS = TransformWorldToObjectDir(terrainNormal, true); // needs normalize

    //  Calculate texture blend value
        half3 normalWS = TransformObjectToWorldDir(normalOS, false);
    //  When it comes to texturing we are interested the normalWS.y - as we want to prevent textures from streching.
        half upWS = normalWS.y;
        o_blend = saturate( (terrainHeight + _TextureBlendHeight - positionAWS.y) * _TextureBlendContraction);
        half textureBlendSteepness = saturate( upWS + _TextureBlendSteepness);
        o_blend *= textureBlendSteepness;

        //o_blend_origNormalWS.yzw = normalWS;

    //  Calculate normal blend value
    //  Here we take the dot product between the both
        half nDotn = dot(normalOS, terrainNormalOS);
        half normalBlend = saturate( (terrainHeight + _NormalBlendHeight - positionAWS.y) * _NormalBlendContraction);
        normalBlend = normalBlend * saturate(nDotn + _NormalBlendSteepness);
        o_normalOS = lerp(normalOS, terrainNormalOS, normalBlend.xxx );

        float scale = length(GetObjectToWorldMatrix()[1].xyz);
        o_positionOS = positionOS + normalOS * normalBlend / scale * _ExtrudeAlongNormal * (1.0 - nDotn);
        o_tangentOS = tangentOS;
    }
}


void BlendWithTerrainFrag_float
(
    float3  positionAWS,

    half3   albedo,
    half3   normalTS,
    half    smoothness,
    half    occlusion,
    half    metallic,

    half    blend,

    half3   NormalWS,
    half3   TangentWS,
    half3   BitangentWS,


    out half3   o_albedo,
    out half3   o_normal,
    out half    o_smoothness,
    out half    o_occlusion,
    out half    o_metallic
)
{
    
    half blendTexture = blend;

    if (_BlendPerPixel)
    {
        float2 terrainUV = (positionAWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
        terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;
        half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
        float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;

    //  Get terrain normal
        half3 terrainNormal;
        terrainNormal.xz = terrainSample.ba * 2.0 - 1.0;
        terrainNormal.y = sqrt(1.0 - saturate(dot(terrainNormal.xz, terrainNormal.xz)));

    //  Calculate texture blend value
    //  When it comes to texturing we are interested the normalWS.y - as we want to prevent textures from streching.
        half upWS = NormalWS.y;
        blendTexture = saturate( (terrainHeight + _TextureBlendHeight - positionAWS.y) * _TextureBlendContraction);
        half textureBlendSteepness = saturate( upWS + _TextureBlendSteepness);
        blendTexture *= textureBlendSteepness;

    //  Calculate normal blend value
    //  Here we take the dot product between the both
        half nDotn = dot(NormalWS, terrainNormal);
        half normalBlend = saturate( (terrainHeight + _NormalBlendHeight - positionAWS.y) * _NormalBlendContraction);
        normalBlend = normalBlend * saturate(nDotn + _NormalBlendSteepness);
        NormalWS = lerp(NormalWS, terrainNormal, normalBlend.xxx );
    }

/////////////////////////////////

    half3x3 tangentToWorld = half3x3(TangentWS, BitangentWS, NormalWS);
    half3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);

    o_albedo = albedo;
    o_normal = normalWS; 
    o_smoothness = smoothness;
    o_occlusion = occlusion;
    o_metallic = metallic;

//  break up stretching
    float2 offset = normalTS.xy * PowTwo( saturate(1.0 - NormalWS.y)) * _BreakUpStretching;

    float2 terrainTexUV = (positionAWS.xz - _TerrainPos.xz + offset) * _TerrainTexTiling;
    float2 ddxU = ddx(terrainTexUV);
    float2 ddyV = ddy(terrainTexUV);

    UNITY_BRANCH
    if (blendTexture > 0.0)
    {
        
        half4 terrainAlbedoSample = SAMPLE_TEXTURE2D_GRAD(_TerrainAlbedoMap, sampler_TerrainAlbedoMap, terrainTexUV, ddxU, ddyV); 
        terrainAlbedoSample.rgb *= _TerrainTint.rgb;
        half4 terrainNormalSample = SAMPLE_TEXTURE2D_GRAD(_TerrainNormalMap, sampler_TerrainNormalMap, terrainTexUV, ddxU, ddyV);

        half terrainSmoothness = terrainAlbedoSample.a;
        half terrainOcclusion = 1.0;
        half terrainMetallic = 0.0;

        if (_EnableTerrainMaskMap)
        {
            half4 terrainMaskSample = SAMPLE_TEXTURE2D_GRAD(_TerrainMaskMap, sampler_TerrainMaskMap, terrainTexUV, ddxU, ddyV);
            terrainSmoothness = terrainMaskSample.a;
            terrainOcclusion = terrainMaskSample.g;
            terrainMetallic = terrainMaskSample.r;
        }
        
        if (_BreakUpBlending)
        {
            half breakUpFromOcclusion = lerp(1.0, occlusion, saturate(_BreakUpOcclusionInfluence));
            half baseLuminance = saturate(Luminance(albedo) * breakUpFromOcclusion);
            half breakup = 1.0 - blendTexture;
            breakup = smoothstep(breakup, saturate(breakup + _BlendSharpness), 1 - baseLuminance);
            blendTexture = lerp(breakup, blendTexture, blendTexture * blendTexture * blendTexture);
        }

        o_albedo = lerp(o_albedo, terrainAlbedoSample.rgb, blendTexture.xxx);
        o_smoothness = lerp(o_smoothness, terrainSmoothness, blendTexture);
        o_occlusion = lerp(o_occlusion, terrainOcclusion, blendTexture);
        o_metallic = lerp(o_metallic, terrainMetallic, blendTexture);

        half3 terrainNormalTS = UnpackNormalScale(terrainNormalSample, _TerrainNormalStrength);
    //  Use Reoriented Normal Mapping to bring the top down normal into world space
        half3 n1 = NormalWS;
    //  We must apply some crazy swizzling here: Swizzle world space to tangent space
        n1 = n1.xzy;
        half3 n2 = terrainNormalTS.xyz;
        n1.z += 1.0h;
        n2.xy *= -1.0h;
        half3 topDownNormal = n1 * dot(n1, n2) / max(0.001, n1.z) - n2;
    //  Swizzle tangent space to world space
        topDownNormal = topDownNormal.xzy;
    //  Finally we blend both normals in world space 
        o_normal = normalize( lerp(normalWS, topDownNormal, blendTexture.xxx ) );

    //  Ground Truth
        // half3 terrainTangent = cross(half3(0, 0, 1), NormalWS);
        // half3 terrainbitangentWS = cross(NormalWS, terrainTangent);
        // half3x3 tangentToWorldTerrain = half3x3(-terrainTangent, terrainbitangentWS, NormalWS);

        // half3 terrainNormalWS = TransformTangentToWorld(terrainNormalTS, tangentToWorldTerrain);
        // o_normal = lerp(normalWS, terrainNormalWS, blendTexture.xxx);
    //  ////////////////

    //  o_albedo = PowTwo( saturate(1.0 - NormalWS.y));
    }
}