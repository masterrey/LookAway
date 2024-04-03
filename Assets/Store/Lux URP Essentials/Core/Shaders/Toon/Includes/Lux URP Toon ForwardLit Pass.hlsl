#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs
struct Attributes
{
    float3 positionOS                   : POSITION;
    float3 normalOS                     : NORMAL;
    #if defined(_NORMALMAP) || (defined(_ANISOTROPIC) && !defined(_SPECULARHIGHLIGHTS_OFF))
        float4 tangentOS                : TANGENT;
    #endif
    #if defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO) || defined(_NORMALMAP) || defined(_MASKMAP)
        float2 texcoord                 : TEXCOORD0;
    #endif
    #ifdef LIGHTMAP_ON
        float2 staticLightmapUV         : TEXCOORD1;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV        : TEXCOORD2;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    #if defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO) || defined(_TEXMODE_TWO) || defined(_NORMALMAP) || defined(_MASKMAP)
        float2 uv                       : TEXCOORD0;
    #endif
    float3 positionWS                   : TEXCOORD1;
    half3 normalWS                      : TEXCOORD2;
    #if defined(_NORMALMAP) || (defined(_ANISOTROPIC) && !defined(_SPECULARHIGHLIGHTS_OFF))
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

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
#include "Includes/Lux URP Toon SurfaceData.hlsl"


//--------------------------------------
//  Vertex shader

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput; // 
    vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    
    #if defined(_NORMALMAP) || (defined(_ANISOTROPIC) && !defined(_SPECULARHIGHLIGHTS_OFF))
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    #else
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(0,0,0,0));
    #endif

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    #if defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO) || defined(_TEXMODE_TWO) || defined(_NORMALMAP) || defined(_MASKMAP)
        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    #endif

    output.normalWS = normalInput.normalWS;

    #if defined (_NORMALMAP) || (defined(_ANISOTROPIC) && !defined(_SPECULARHIGHLIGHTS_OFF))
        half sign = input.tangentOS.w * GetOddNegativeScale();
        output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
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

//--------------------------------------
//  Fragment shader and functions

void InitializeInputData(Varyings input, half3 normalTS, half facing, out InputData inputData)
{
    inputData = (InputData)0;
    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        inputData.positionWS = input.positionWS;
    #endif

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    #if defined(_NORMALMAP)
        normalTS.z *= facing;
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS * facing;
    #endif

//  Not normalized normals cause uggly specular highlights on mobile. So we always normalize.
    #if !defined(_SPECULARHIGHLIGHTS_OFF)
        inputData.normalWS = normalize(inputData.normalWS);
    #else
        inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    #endif
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

void LitPassFragment(
    Varyings input, half facing : VFACE
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
    #if defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO) || defined(_TEXMODE_TWO) || defined(_NORMALMAP) || defined(_MASKMAP)
        InitializeSurfaceData(input.uv, surfaceData, additionalSurfaceData);
    #else
        InitializeSurfaceData(float2(0,0), surfaceData, additionalSurfaceData);
    #endif

//  Prepare surface data (like bring normal into world space and get missing inputs like gi)
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, facing, inputData);

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        // Most likely we do not want a full decal incl. normals etc here
        // ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
        // ApplyDecalToBaseColor(input.positionCS, surfaceData.albedo);
    #endif
#endif

    #if defined(_RIMLIGHTING)
        half rim = saturate(1.0h - saturate( dot(inputData.normalWS, inputData.viewDirectionWS) ) );
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
        additionalSurfaceData.albedoShaded = lerp(half3(1,1,1), additionalSurfaceData.albedoShaded, surfaceData.alpha.xxx);
    #endif

//  Apply lighting
    half4 color = LuxURPToonFragmentPBR(
        inputData,

        #if defined(_ANISOTROPIC) && !defined(_SPECULARHIGHLIGHTS_OFF)
            input.tangentWS,
            _Anisotropy,
        #endif
         
        surfaceData.albedo,
        additionalSurfaceData.albedoShaded,

        _ShadedDecalColor.rgb,

        surfaceData.metallic, 
        surfaceData.specular,

        _Steps,
        _DiffuseStep,
        _DiffuseFallOff,
        
        _EnergyConservation,
        _SpecularStep,
        _SpecularFallOff,

        _ColorizedShadowsMain,
        _ColorizedShadowsAdd,
        _LightColorContribution,
        _AddLightFallOff,
        
        _ShadowFallOff,
        _ShadoBiasDirectional,
        _ShadowBiasAdditional,

        _ToonRimColor.rgb,
        _ToonRimPower,
        _ToonRimFallOff,
        _ToonRimAttenuation,

        surfaceData.smoothness, 
        surfaceData.occlusion, 
        surfaceData.emission, 
        surfaceData.alpha,

        input.positionCS
    );    
//  Add fog
//  URP still does not handle fog properly?!   
    #if defined(_SURFACE_TYPE_TRANSPARENT) 
        
        //  From MixFogColor()
            #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
                if (IsFogEnabled())
                {
                    float fogIntensity = ComputeFogIntensity(inputData.fogCoord);
                    #if defined(_ALPHAPREMULTIPLY_ON)
                    //  additive - here we simply fade out color according to fogIntensity :(
                        if(_LuxBlend == 2) {
                            color = lerp(half4(0,0,0,0), color, fogIntensity);
                        }
                    //  premul
                        else {
                            color.rgb = lerp(unity_FogColor.rgb * color.a, color.rgb, fogIntensity);    
                        }
                    #else
                    //  alpha
                        if(_LuxBlend == 0)
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


//  Fix alpha - matches: color.a = OutputAlpha(color.a, IsSurfaceTypeTransparent(_Surface));
    color.a = _LuxSurface == 1 ? color.a : 1;
    outColor = color;

    //outColor = surfaceData.alpha;

    #ifdef _WRITE_RENDERING_LAYERS
        uint renderingLayers = GetMeshRenderingLayer();
        outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}

           