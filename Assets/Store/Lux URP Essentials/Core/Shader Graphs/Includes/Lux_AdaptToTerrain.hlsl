inline float DecodeFloatRG( float2 enc ) {
    float2 kDecodeDot = float2(1.0, 1/255.0);
    return dot(enc, kDecodeDot);
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

void AdaptToTerrain_float
(
    float3 PositionOS,
    half3  NormalOS,
    half3  TangentOS,
    float3 PositionAWS,


    out float3 o_positionOS,
    out half3 o_normalOS,
    out half3 o_tangentOS
)
{

    o_positionOS = PositionOS;
    o_normalOS = NormalOS;
    o_tangentOS = TangentOS;

    if (_EnableAdaptToTerrain)
    {

        float2 terrainUV = (PositionAWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
        terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;
        half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
        float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;

        float scale = length(GetObjectToWorldMatrix()[1].xyz);
        float3 t_positionAWS = PositionAWS;
        t_positionAWS.y = terrainHeight + ( (PositionOS.y + _TerrainOffset) * scale);

        o_positionOS = TransformWorldToObject(t_positionAWS);

        half3 terrainNormal;
        terrainNormal.xz = terrainSample.ba * 2.0 - 1.0;
        terrainNormal.y = sqrt(1.0 - saturate(dot(terrainNormal.xz, terrainNormal.xz)));
        half3 terrainNormalOS = TransformWorldToObjectDir(terrainNormal, true); // needs normalize

        half3 upVector = half3(0, 1, 0);
        
        if (_AccurateNormals)
        {
            half rotation = dot(upVector, terrainNormalOS);
            // Rotation to radians!
            rotation = acos(rotation);
            half3 axis = cross(upVector, terrainNormalOS);
            axis = normalize(axis); // needs normalize
            half3x3 rotMatrix = GetRotationMatrix(axis, rotation);
            o_normalOS = mul(rotMatrix, NormalOS);
            o_tangentOS = mul(rotMatrix, TangentOS);
        }
        else 
        {
            //o_normalOS = ReorientNormal(normalOS, terrainNormalOS, upVector);   // like mul()
            o_normalOS = ReorientNormalTS(NormalOS.xzy, terrainNormalOS.xzy).xzy; // less accurate but ok as well
            o_tangentOS = TangentOS;
        }

    }

}
