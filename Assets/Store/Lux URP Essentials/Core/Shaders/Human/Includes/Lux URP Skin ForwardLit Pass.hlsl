#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs
struct Attributes
{
    float3 positionOS                   : POSITION;
    float3 normalOS                     : NORMAL;
    float4 tangentOS                    : TANGENT;
    float2 texcoord                     : TEXCOORD0;
    #if defined(LIGHTMAP_ON)
        float2 staticLightmapUV         : TEXCOORD1;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV        : TEXCOORD2;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
    
struct Varyings
{
    float2 uv                           : TEXCOORD0;
    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        float3 positionWS               : TEXCOORD1;
    #endif
    half3 normalWS                      : TEXCOORD2;
    #ifdef _NORMALMAP
        half4 tangentWS                 : TEXCOORD3;
    #endif
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half4 fogFactorAndVertexLight   : TEXCOORD4;
    #else
        half  fogFactor                 : TEXCOORD4;
    #endif
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord              : TEXCOORD5;
    #endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 6);
    #ifdef DYNAMICLIGHTMAP_ON
        float2  dynamicLightmapUV       : TEXCOORD7;
    #endif

    float4 positionCS                   : SV_POSITION;
    
    #if defined(_DISTANCEFADE)
        nointerpolation half fade       : TEXCOORD8;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

//--------------------------------------
//  Vertex shader

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//  Set distance fade value
    #if defined(_DISTANCEFADE)
        float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
        float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
        float dist = dot(diff, diff);
        output.fade = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );
    #endif

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

    half fogFactor = 0.0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = input.texcoord;
    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;

    #ifdef _NORMALMAP
        real sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = float4(normalInput.tangentWS.xyz, sign);
    #endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
    
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    #else
        output.fogFactor = fogFactor;
    #endif

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        output.positionWS = vertexInput.positionWS;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    //  tweak the sampling position
        vertexInput.positionWS += output.normalWS.xyz * _SkinShadowSamplingBias;
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif
    output.positionCS = vertexInput.positionCS;

    return output;
}

//--------------------------------------
//  Fragment shader and functions

inline void InitializeSkinLitSurfaceData(float2 uv, half fade, out SurfaceData outSurfaceData, out AdditionalSurfaceData outAdditionalSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)) * _BaseColor;

    outSurfaceData.alpha = half(1.0);
    outSurfaceData.albedo = albedoAlpha.rgb;
    outSurfaceData.metallic = half(0.0);
    outSurfaceData.specular = _SpecularColor.rgb;

//  Normal Map
    #if defined (_NORMALMAP)
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        
        #if defined(_DETAILNORMALMAP)
        //  Get detail normal
            float2 detailUV = TRANSFORM_TEX(uv, _DetailBumpMap);
            half4 sampleDetailNormal = SAMPLE_TEXTURE2D(_DetailBumpMap, sampler_BumpMap, detailUV);
            half3 detailNormalTS = UnpackNormalScale(sampleDetailNormal, _DetailBumpScale);
        //  With UNITY_NO_DXT5nm unpacked vector is not normalized for BlendNormalRNM
            // For visual consistancy we going to do in all cases
            detailNormalTS = normalize(detailNormalTS);
            outSurfaceData.normalTS = BlendNormalRNM(outSurfaceData.normalTS, detailNormalTS);
        #endif

        #if defined(_NORMALMAPDIFFUSE)
            half4 sampleNormalDiffuse = SAMPLE_TEXTURE2D_BIAS(_BumpMap, sampler_BumpMap, uv, _Bias);
        //  Do not manually unpack the normal map as it might use RGB.
            outAdditionalSurfaceData.diffuseNormalTS = UnpackNormal(sampleNormalDiffuse);
        #else
            outAdditionalSurfaceData.diffuseNormalTS = half3(0,0,1);
        #endif
    #else
        outSurfaceData.normalTS = half3(0,0,1);
        outAdditionalSurfaceData.diffuseNormalTS = half3(0,0,1);
    #endif

    half4 SSSAOSample = SAMPLE_TEXTURE2D(_SSSAOMap, sampler_SSSAOMap, uv);
    outAdditionalSurfaceData.translucency = SSSAOSample.g;
    outAdditionalSurfaceData.skinMask = SSSAOSample.r;
    outSurfaceData.occlusion = lerp(half(1.0), SSSAOSample.a, _OcclusionStrength);
    outAdditionalSurfaceData.curvature = SSSAOSample.b;

    outSurfaceData.smoothness = albedoAlpha.a * _Smoothness;
    outSurfaceData.emission = half(0.0);

    outSurfaceData.clearCoatMask = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);

}

void InitializeInputData(Varyings input, half3 normalTS, half3 diffuseNormalTS, out InputData inputData
    #ifdef _NORMALMAP
        , inout float3 bitangent
    #endif
    , inout half3 diffuseNormalWS
    )
{
    inputData = (InputData)0;
    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        inputData.positionWS = input.positionWS;
    #endif

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    
    #ifdef _NORMALMAP
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        half3x3 ToW = half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, ToW);
        inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
        #ifdef _NORMALMAPDIFFUSE
            diffuseNormalWS = TransformTangentToWorld(diffuseNormalTS, ToW);
            diffuseNormalWS = NormalizeNormalPerPixel(diffuseNormalWS);
        #else
        //  Here we let the user decide to use the per vertex or the specular normal.
            diffuseNormalWS = (_VertexNormal) ? NormalizeNormalPerPixel(input.normalWS.xyz) : inputData.normalWS;
        #endif
    #else
        inputData.normalWS = NormalizeNormalPerPixel(input.normalWS);
        diffuseNormalWS = inputData.normalWS;
    #endif

    inputData.viewDirectionWS = viewDirWS;
    
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS + input.normalWS * _SkinShadowSamplingBias);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif
    
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
        inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    #else
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
    #endif

    #if defined(DYNAMICLIGHTMAP_ON)
        //inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, diffuseNormalWS);
    #else
        //inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, diffuseNormalWS);
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #endif

}

//half4 LitPassFragment(Varyings input) : SV_Target
//{
void LitPassFragment(
    Varyings input
    , out half4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

//  Get the surface description
    SurfaceData surfaceData;
    AdditionalSurfaceData additionalSurfaceData;

    #if defined(_DISTANCEFADE)
        half distanceFade = input.fade;
    #else 
        half distanceFade = 1.0;
    #endif
    InitializeSkinLitSurfaceData(input.uv.xy, distanceFade, surfaceData, additionalSurfaceData);

//  Prepare surface data (like bring normal into world space and get missing inputs like gi
    half3 diffuseNormalWS;
    InputData inputData;
    #ifdef _NORMALMAP
        float3 bitangent;
    #endif
    InitializeInputData(input, surfaceData.normalTS, additionalSurfaceData.diffuseNormalTS, inputData
        #ifdef _NORMALMAP
            , bitangent
        #endif
        , diffuseNormalWS
    );

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        half3 albedo = surfaceData.albedo;
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
        half suppression = 1.0 - saturate( abs( dot(albedo, albedo) - dot(surfaceData.albedo, surfaceData.albedo) ) * 256.0 );
        additionalSurfaceData.skinMask *= suppression;
        additionalSurfaceData.translucency *= lerp(suppression, 1.0, _DecalTransmission);
    #endif
#endif

    #if defined(_RIMLIGHTING)
        half rim = saturate(1.0 - saturate( dot(inputData.normalWS, inputData.viewDirectionWS) ) );
        half power = _RimPower;
        if(_RimFrequency > 0.0 ) {
            half perPosition = lerp(0.0, 1.0, dot(1.0, frac(UNITY_MATRIX_M._m03_m13_m23) * 2.0 - 1.0 ) * _RimPerPositionFrequency ) * half(PI);
            power = lerp(power, _RimMinPower, (1.0 + sin(_Time.y * _RimFrequency + perPosition) ) * 0.5 );
        }
        surfaceData.emission += pow(rim, power) * _RimColor.rgb * _RimColor.a;
    #endif

//  Apply lighting
    half4 color = LuxURPSkinFragmentPBR(
        inputData, 
        surfaceData,
    //  Subsurface Scattering
        half4(_TranslucencyStrength * additionalSurfaceData.translucency, _TranslucencyPower, _ShadowStrength, _Distortion),
    //  AmbientReflection Strength
        _AmbientReflectionStrength,
    //  Diffuse Normal
        // #if defined(_NORMALMAP) && defined(_NORMALMAPDIFFUSE)
        //     NormalizeNormalPerPixel( TransformTangentToWorld(surfaceData.diffuseNormalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz)) )
        // #else
        //     input.normalWS
        // #endif
        diffuseNormalWS,
        _SubsurfaceColor.rgb,
        (_SampleCurvature) ? additionalSurfaceData.curvature * _Curvature : lerp(additionalSurfaceData.translucency, 1.0, _Curvature),
    //  Lerp lighting towards standard according the distance fade
        additionalSurfaceData.skinMask * distanceFade,
        _MaskByShadowStrength,
        _Backscatter
        );    

//  Add fog
    color.rgb = MixFog(color.rgb, inputData.fogCoord);

    outColor = color;

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}