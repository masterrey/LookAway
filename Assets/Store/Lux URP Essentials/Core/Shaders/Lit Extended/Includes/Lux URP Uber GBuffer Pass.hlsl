#ifndef UNIVERSAL_LIT_GBUFFER_PASS_INCLUDED
#define UNIVERSAL_LIT_GBUFFER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

// TODO: Currently we support viewDirTS caclulated in vertex shader and in fragments shader.
// As both solutions have their advantages and disadvantages (etc. shader target 2.0 has only 8 interpolators).
// We need to find out if we can stick to one solution, which we needs testing.
// So keeping this until I get manaul QA pass.



//  ///////////////////////////////////////////////
//  Lux
//  We use a different keyword but want to keep as much of the original code, so:
#if defined(_PARALLAX)
    #define _PARALLAXMAP
#endif
//  ///////////////////////////////////////////////


#if defined(_PARALLAXMAP) && (SHADER_TARGET >= 30)
    #define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if defined(_NORMALMAP) || defined(_PARALLAXMAP) || defined(_DETAIL) || defined (_BENTNORMAL)
    #define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// keep this file in sync with LitForwardPass.hlsl

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    #ifdef LIGHTMAP_ON
        float2 staticLightmapUV  : TEXCOORD1;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV : TEXCOORD2;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS               : TEXCOORD1;
#endif

    half3 normalWS                  : TEXCOORD2;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS                 : TEXCOORD3;    // xyz: tangent, w: sign
#endif
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half3 vertexLighting            : TEXCOORD4;    // xyz: vertex lighting
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD5;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                 : TEXCOORD6;
#endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
#ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV       : TEXCOORD8; // Dynamic lightmap UVs
#endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, half3 bitangentWS, half3 normalTS, half facing, out InputData inputData)
{
    inputData = (InputData)0;

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        inputData.positionWS = input.positionWS;
    #endif

    inputData.positionCS = input.positionCS;
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    
    #if defined(_NORMALMAP) || defined(_DETAIL)
        normalTS.z *= facing;
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS.xyz, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS * facing;
    #endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = 0.0; // we don't apply fog in the guffer pass

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        inputData.vertexLighting = input.vertexLighting.xyz;
    #else
        inputData.vertexLighting = half3(0, 0, 0);
    #endif

#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitGBufferPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;

    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif

    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
        output.tangentWS = tangentWS;
    #endif

    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
        half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
        output.viewDirTS = viewDirTS;
    #endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
        output.vertexLighting = vertexLight;
    #endif

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        output.positionWS = vertexInput.positionWS;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// Horizon Occlusion for Normal Mapped Reflections: http://marmosetco.tumblr.com/post/81245981087
half LuxGetHorizonOcclusion(half3 R, half3 normalWS, half3 vertexNormal, half horizonFade)
{
    //half3 R = reflect(-V, normalWS);
    half specularOcclusion = saturate(1.0 + horizonFade * dot(R, vertexNormal));
    // smooth it
    return specularOcclusion * specularOcclusion;
}
half3 LuxExtended_GlobalIllumination(BRDFData brdfData, half3 bakedGI, half occlusion, float3 positionWS, half3 normalWS, half3 viewDirectionWS, half3 bentNormal, half3 geoNormalWS, half horizonOcllusion)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);

    half3 indirectDiffuse = bakedGI * occlusion;

    half reflOcclusion = 1;
    #if defined(_BENTNORMAL)
        reflOcclusion = saturate(dot(normalWS, bentNormal));
        /*
        occlusion = sqrt(1.0 - saturate(occlusion/reflOcclusion));
        occlusion = TWO_PI *  (1.0 - occlusion);
        occlusion = saturate(occlusion * INV_FOUR_PI);
        reflOcclusion = 1;
        */
    #endif

//  Horizon Occlusion
    #if defined (_SAMPLENORMAL) && defined(_UBER)
        reflOcclusion *= LuxGetHorizonOcclusion( reflectVector, normalWS, geoNormalWS, horizonOcllusion);
    #endif

    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, 1.0h) * reflOcclusion * occlusion;

    return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}

// Used in Standard (Physically Based) shader
FragmentOutput LitGBufferPassFragment(Varyings input, half facing : VFACE)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

//  LOD crossfading
    // #if defined(LOD_FADE_CROSSFADE) && !defined(SHADER_API_GLES)
    //     //LODDitheringTransition(input.positionCS.xy, unity_LODFade.x);
    //     clip (unity_LODFade.x - Dither32(input.positionCS.xy, 1));
    // #endif
    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

//  Camera Fading
    #if defined(_ALPHATEST_ON) && defined(_FADING_ON)
        clip ( input.positionCS.w - _CameraFadeDist - Dither32(input.positionCS.xy, 1));                   
    #endif

//  Calculate bitangent upfront
    #if defined (REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
        float sgn = input.tangentWS.w;
        half3 bitangentWS = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    #else
        half3 bitangentWS = 0;
    #endif

    half3 viewDirTS = 0;
    #if defined(_PARALLAXMAP)
        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            viewDirTS = input.viewDirTS;
            viewDirTS.z *= facing;
        #else
            viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, input.viewDirWS);
            viewDirTS.z *= facing;
        #endif
    #endif

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceDataUber(input.uv, viewDirTS, surfaceData);

    InputData inputData;
    InitializeInputData(input, bitangentWS, surfaceData.normalTS, facing, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

    #if defined(_ENABLE_GEOMETRIC_SPECULAR_AA)
        half3 worldNormalFace = input.normalWS.xyz;
        half roughness = 1.0h - surfaceData.smoothness;
        //roughness *= roughness; // as in Core?
        half3 deltaU = ddx( worldNormalFace );
        half3 deltaV = ddy( worldNormalFace );
        half variance = _ScreenSpaceVariance * ( dot(deltaU, deltaU) + dot(deltaV, deltaV) );
        half kernelSquaredRoughness = min( 2.0h * variance , _SAAThreshold );
        half squaredRoughness = saturate( roughness * roughness + kernelSquaredRoughness );
        surfaceData.smoothness = 1.0h - sqrt(squaredRoughness);
    #endif

    #if defined(_RIMLIGHTING)
        half rim = saturate(1.0h - saturate( dot(inputData.normalWS, inputData.viewDirectionWS ) ) );
        half power = _RimPower;
        if(_RimFrequency > 0 ) {
            half perPosition = lerp(0.0h, 1.0h, dot(1.0h, frac(UNITY_MATRIX_M._m03_m13_m23) * 2.0h - 1.0h ) * _RimPerPositionFrequency ) * 3.1416h;
            power = lerp(power, _RimMinPower, (1.0h + sin(_Time.y * _RimFrequency + perPosition) ) * 0.5h );
        }
        surfaceData.emission += pow(rim, power) * _RimColor.rgb * _RimColor.a;
    #endif

#ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
#endif


    #if defined(_BENTNORMAL)
        half3 bentNormal  = SampleNormalExtended(input.uv, TEXTURE2D_ARGS(_BentNormalMap, sampler_BentNormalMap), 1);     
        #if defined(_SAMPLENORMAL)
            bentNormal = normalize(half3(bentNormal.xy + surfaceData.normalTS.xy, bentNormal.z*surfaceData.normalTS.z));
        #endif
        bentNormal = TransformTangentToWorld(bentNormal, half3x3(input.tangentWS.xyz, bitangentWS.xyz, input.normalWS.xyz));
        //bentNormal = mul(GetObjectToWorldMatrix(), float4(bentNormal, 0) );
        bentNormal = NormalizeNormalPerPixel(bentNormal);
        #if !defined(LIGHTMAP_ON) && !defined(DYNAMICLIGHTMAP_ON)
            inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, bentNormal);
        #endif
    #endif

    // Stripped down version of UniversalFragmentPBR().

    // in LitForwardPass GlobalIllumination (and temporarily LightingPhysicallyBased) are called inside UniversalFragmentPBR
    // in Deferred rendering we store the sum of these values (and of emission as well) in the GBuffer
    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
    //half3 color = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
    half3 color = LuxExtended_GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS,
        #if defined(_BENTNORMAL)
            bentNormal,
        #else
            half3(0,0,0),
        #endif
        input.normalWS, _HorizonOcclusion);

    #if !defined(_GBUFFER_NORMALS_OCT) && defined(_BESTFITTINGNORMALS_ON)

        // inputData.normalWS is already normalized here
        float3 vNormal = (float3)inputData.normalWS;
          
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
        inputData.normalWS = (half3)vNormal.rgb;
    #endif

    return BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);
}

#endif
