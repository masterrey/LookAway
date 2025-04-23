

void VertexSH_half(
    float3 PositionWS,
    half3 NormalWS,

    out half3 o_vertexSH,
    out float4 o_probeOcclusion
)
{
    o_vertexSH = 0;
    o_probeOcclusion = (float4)0;
    #if !defined(SHADERGRAPH_PREVIEW)
        OUTPUT_SH4(PositionWS, NormalWS.xyz, GetWorldSpaceNormalizeViewDir(PositionWS), o_vertexSH, o_probeOcclusion);    
    #endif
}

void VertexSH_float(
    float3 PositionWS,
    half3 NormalWS,

    out half3 o_vertexSH,
    out float4 o_probeOcclusion
)
{
    o_vertexSH = 0;
    o_probeOcclusion = (float4)0;
    #if !defined(SHADERGRAPH_PREVIEW)
        OUTPUT_SH4(PositionWS, NormalWS.xyz, GetWorldSpaceNormalizeViewDir(PositionWS), o_vertexSH, o_probeOcclusion);    
    #endif
}