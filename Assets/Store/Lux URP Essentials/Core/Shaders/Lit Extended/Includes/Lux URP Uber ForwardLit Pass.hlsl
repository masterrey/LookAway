#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
#define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


//  ///////////////////////////////////////////////
//  Lux
//  We use a different keyword but want to keep as much of the original code, so:
#if defined(_PARALLAX)
    #define _PARALLAXMAP
#endif
//  ///////////////////////////////////////////////

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
    #define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if defined(_NORMALMAP) || defined(_PARALLAXMAP) || defined(_DETAIL) || defined (_BENTNORMAL)
    #define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif


#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

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

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                 : TEXCOORD8;
#endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, float3 bitangentWS, half3 viewDirWS, half3 normalTS, half facing, out InputData inputData)
{
    inputData = (InputData)0;

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        inputData.positionWS = input.positionWS;
    #endif

    #if defined(_NORMALMAP) || defined(_SAMPLENORMAL)
//  URP 12 facing added as we had to remove it from viewDirTS code...
        normalTS.z *= facing;
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS.xyz, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS.xyz * facing;
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

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
        inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    #else
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
    #endif
    #if defined(DYNAMICLIGHTMAP_ON)
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    #else
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
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

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassVertexUber(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    
    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
//    #if defined (_NORMALMAP) || defined(_PARALLAX) || defined (_BENTNORMAL) || defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)  || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        real sgn = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS, sgn);
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
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    #else
        output.fogFactor = fogFactor;
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

// Fragment Shader

#include "Includes/Lux URP Lit Extended Lighting.hlsl"

void LitPassFragmentUber(
    Varyings input, half facing : VFACE
    , out half4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

//  LOD crossfading
    // #if defined(LOD_FADE_CROSSFADE) && !defined(SHADER_API_GLES)
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

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

//     #if defined(_PARALLAX)
// //  NOTE: Take possible back faces into account.
// //  URP 12: We can't do this anymore as Depth and DepthNormal do not do this :(
// //  We can if we tweak Depth and Depth normal as well
//         input.normalWS.xyz *= facing;
//         half3x3 tangentSpaceRotation =  half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS.xyz);
//         half3 viewDirTS = SafeNormalize( mul(tangentSpaceRotation, viewDirWS) );
//     #else
//         half3 viewDirTS = 0; 
//     #endif


//  Even if we could do better we just use URP code here...
    #if defined(_PARALLAX)
        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            half3 viewDirTS = input.viewDirTS;
            viewDirTS.z *= facing;
        #else
            half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
            viewDirTS.z *= facing;
        #endif
    #else 
        half3 viewDirTS = 0;
    #endif

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceDataUber(input.uv, viewDirTS, surfaceData);

    InputData inputData;
//  Custom function! which uses bitangentWS, viewDirWS and facing as additional inputs here.
    InitializeInputData(input, bitangentWS, viewDirWS, surfaceData.normalTS, facing, inputData);

    #if defined(_BENTNORMAL)
        half3 bentNormal  = SampleNormalExtended(input.uv, TEXTURE2D_ARGS(_BentNormalMap, sampler_BentNormalMap), 1);     
        #if defined(_SAMPLENORMAL)
            bentNormal = normalize(half3(bentNormal.xy + surfaceData.normalTS.xy, bentNormal.z*surfaceData.normalTS.z));
        #endif
        bentNormal = TransformTangentToWorld(bentNormal, half3x3(input.tangentWS.xyz, bitangentWS.xyz, input.normalWS.xyz));
        //bentNormal = mul(GetObjectToWorldMatrix(), float4(bentNormal, 0) );
        bentNormal = NormalizeNormalPerPixel(bentNormal);
        #if !defined(LIGHTMAP_ON) && !defined(DYNAMICLIGHTMAP_ON)
            inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, bentNormal);
        #endif
    #endif

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

//  Multicative blending
    #if defined(_ALPHAMODULATE_ON)
        surfaceData.albedo = lerp(half3(1,1,1), surfaceData.albedo, surfaceData.alpha.xxx);
    #endif

    #ifdef _DBUFFER
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif

    half4 color = LuxExtended_UniversalFragmentPBR(
        inputData,
        surfaceData,
        #if defined(_ENABLE_AO_FROM_GI) && defined(LIGHTMAP_ON)
            _GItoAO, _GItoAOBias,
        #else
            1, 0,
        #endif
        #if defined(_BENTNORMAL)
            bentNormal,
        #else
            half3(0,0,0),
        #endif
        input.normalWS.xyz,
        _HorizonOcclusion
    );

//  URP still does not handle fog properly?!   
    #if defined(_SURFACE_TYPE_TRANSPARENT) 
        
        //  From MixFogColor()
            #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
                if (IsFogEnabled())
                {
                    float fogIntensity = ComputeFogIntensity(inputData.fogCoord);
                    #if defined(_ALPHAPREMULTIPLY_ON)
                    //  additive - here we simply fade out color according to fogIntensity :(
                        if(_Blend == 2) {
                            color = lerp(half4(0,0,0,0), color, fogIntensity);
                        }
                    //  premul - we premuliply the fog color to make it match the blend mode.
                        else {
                            color.rgb = lerp(unity_FogColor.rgb * color.a, color.rgb, fogIntensity);   
                        }
                    #else
                    //  alpha
                        if(_Blend == 0)
                        {
                            color.rgb = MixFog(color.rgb, inputData.fogCoord);   
                        }
                    //  multiply - here we simply fade out color according to fogIntensity :(
                        else {
                            color = lerp(half4(1,1,1,0), color, fogIntensity);  
                        }
                    #endif
                }
            #endif
    #else 
        color.rgb = MixFog(color.rgb, inputData.fogCoord);
    #endif    

    outColor = color;

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
} 

#endif