#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

//  Structs
struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 uv           : TEXCOORD0;
    float2 uv1          : TEXCOORD1;
    float2 uv2          : TEXCOORD2;
    //#ifdef _TANGENT_TO_WORLD
        float4 tangentOS    : TANGENT;
    //#endif
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float4 uv           : TEXCOORD0;    // float4!
    float3 positionWS   : TEXCOORD1;
    half3  normalWS     : TEXCOORD2;    // needed by the surface function
    #ifdef _NORMALMAP
        half4 tangentWS : TEXCOORD3;    
    #endif
};

// Include the surface function
#include "Lux URP TopDown SurfaceData.hlsl"


Varyings UniversalVertexMeta(Attributes input)
{
    Varyings output;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionWS = vertexInput.positionWS;
    output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2,
        unity_LightmapST, unity_DynamicLightmapST);
    
    output.uv.xy = TRANSFORM_TEX(input.uv, _BaseMap);
    output.uv.zw = vertexInput.positionWS.xz * _TopDownTiling + _TerrainPosition.xz;

    #if defined (_DYNSCALE)
        float scale = length( TransformObjectToWorld( float3(1,0,0) ) - UNITY_MATRIX_M._m03_m13_m23 );
// Does this work in the meta pass?
        output.uv.xy *= scale;
    #endif

    output.normalWS = normalInput.normalWS;
    #ifdef _NORMALMAP
        float sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = float4(normalInput.tangentWS.xyz, sign);
    #endif

    return output;
}

half4 UniversalFragmentMetaLit(Varyings input) : SV_Target
{
    SurfaceData surfaceData;
    AdditionalSurfaceData additionalSurfaceData;
    InitializeStandardLitSurfaceData(input, surfaceData, additionalSurfaceData);

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    MetaInput metaInput;
    metaInput.Albedo = brdfData.diffuse + brdfData.specular * brdfData.roughness * 0.5;
    //metaInput.SpecularColor = surfaceData.specular;
    metaInput.Emission = surfaceData.emission;

    return MetaFragment(metaInput);
}