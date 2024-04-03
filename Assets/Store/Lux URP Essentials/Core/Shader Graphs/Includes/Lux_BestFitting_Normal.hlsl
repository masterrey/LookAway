
//  //////////////////////////
//  The hack:
//  In "PBRGBufferPass.hlsl" the normal gets normalized: inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
//  So the best fitting normal will be corrupted and look facetted just like the origial one...
//  For this reason we declare a customNormalWS and include our custom "SurfaceDataToGbuffer" function by including "Lux_GBuffer.hlsl"

#if (SHADERPASS == SHADERPASS_GBUFFER)
    half3 customNormalWS;
    #include "Lux_GBuffer.hlsl"
#endif

void BestFittingNormal_float(

//  Base inputs
    half3 normalWS,
    half3 tangentWS,
    half3 bitangentWS,

    half3 normalTS,
    bool  enable,

    out half3 o_normalWS
)
{


//  Tangent space normal to world space
    half3 tnormal = TransformTangentToWorld(normalTS, half3x3(tangentWS, bitangentWS, normalWS));
//  We only need/want the best fitting normal in the GBuffer. So we return the regular normal here.
    o_normalWS = tnormal;

    #if (SHADERPASS == SHADERPASS_GBUFFER) && !defined(_GBUFFER_NORMALS_OCT)
        
        if (enable)
        {
            
            float3 vNormal = normalize( (float3)tnormal);
            // get unsigned normal for cubemap lookup (note the full float precision is required)
            float3 vNormalUns = abs(vNormal);
            // get the main axis for cubemap lookup
            float maxNAbs = max(vNormalUns.z, max(vNormalUns.x, vNormalUns.y));
            // get texture coordinates in a collapsed cubemap
            float2 vTexCoord = vNormalUns.z < maxNAbs ? (vNormalUns.y < maxNAbs ? vNormalUns.yz : vNormalUns.xz) : vNormalUns.xy;
            vTexCoord = vTexCoord.x < vTexCoord.y ? vTexCoord.yx : vTexCoord.xy;
            vTexCoord.y /= vTexCoord.x;
            // fit normal into the edge of unit cube
            vNormal /= maxNAbs;
            // look-up fitting length and scale the normal to get the best fit
            half fFittingScale = SAMPLE_TEXTURE2D(_BestFittingNormal, sampler_BestFittingNormal, vTexCoord).a;
            // scale the normal to get the best fit
            vNormal.rgb *= fFittingScale; 
            // squeeze back to unsigned
            // vNormal.rgb  = vNormal * .5h + .5h;
            tnormal = (half3)vNormal.rgb;
        }
    
        customNormalWS = tnormal;

    #endif
}