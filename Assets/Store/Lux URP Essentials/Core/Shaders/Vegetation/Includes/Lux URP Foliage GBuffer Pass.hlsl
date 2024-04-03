#ifndef LUX_LIT_GBUFFER_PASS_INCLUDED
#define LUX_LIT_GBUFFER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

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
    #ifdef LIGHTMAP_ON
        float2 staticLightmapUV         : TEXCOORD1;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV        : TEXCOORD2;
    #endif
    half4 color                         : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                           : TEXCOORD0;
    float3 positionWS                   : TEXCOORD1;
    half3 normalWS                      : TEXCOORD2;
    #if defined(_NORMALMAP)
        half4 tangentWS                 : TEXCOORD3;
    #endif
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half3 vertexLighting            : TEXCOORD4;
    #endif
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord              : TEXCOORD5;
    #endif
    //#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    //    half3 viewDirTS                : TEXCOORD6;
    //#endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
    #ifdef DYNAMICLIGHTMAP_ON
        float2  dynamicLightmapUV       : TEXCOORD8;
    #endif

    #if defined(_ALPHATEST_ON)
        half fade                       : TEXCOORD9;
    #endif

    float4 positionCS                   : SV_POSITION;

    #if defined(_DEBUG)
        half4 color                     : COLOR;
    #endif
        
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Include the surface function
#include "Includes/Lux URP Foliage SurfaceData.hlsl"


//--------------------------------------
//  Vertex shader

Varyings LitGBufferPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

//  Set distance fade value
    float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
    float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
    float dist = dot(diff, diff);
    float fade = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );

//  Shrink mesh if alpha testing is disabled
    #if !defined(_ALPHATEST_ON)
        input.positionOS.xyz *= fade;
    #else 
        output.fade = fade;  
    #endif

//  Wind in ObjectSpace -------------------------------
    animateVertex(input.color, input.normalOS.xyz, input.positionOS.xyz);
//  End Wind -------------------------------

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

//  Flip normals in view space
    // #if defined _NORMALVS
    //     half3 normalVS = TransformWorldToViewDir(normalInput.normalWS, false); 
    //     normalVS.z = abs(normalVS.z);
    //     normalInput.normalWS = NormalizeNormalPerVertex( mul( (real3x3)UNITY_MATRIX_I_V, normalVS) );

    //     #ifdef _NORMALMAP
    //     //  Adjust tangentWS as we have tweaked normalWS
    //         normalInput.tangentWS.xyz = Orthonormalize(normalInput.tangentWS.xyz, normalInput.normalWS.xyz);
    //     #endif
    // #endif

    output.normalWS = normalInput.normalWS;
    #ifdef _NORMALMAP
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
        output.tangentWS = tangentWS;
    #endif
    
    output.uv.xy = input.texcoord;

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

    #if defined(_DEBUG)
        output.color = input.color;
    #endif

    return output;
}


//--------------------------------------
//  Fragment shader and functions

void InitializeInputData(Varyings input, half3 normalTS, half facing, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.positionCS = input.positionCS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

//  We are using the passed vertexnormal normalWS here!    
    #if defined(_NORMALMAP)
        #if !defined(_GBUFFERLIGHTING_SIMPLE) && !defined(_GBUFFERLIGHTING_VSNORMALS)
            normalTS.z *= facing;
        #endif
        float sgn = input.tangentWS.w;
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS;
        #if !defined(_GBUFFERLIGHTING_SIMPLE) && !defined(_GBUFFERLIGHTING_VSNORMALS)
            inputData.normalWS *= facing;
        #endif
    #endif

    #if defined (_GBUFFERLIGHTING_VSNORMALS)
        // From world to view space
        half3 normalVS = TransformWorldToViewDir(inputData.normalWS, true);
        // Now "flip" the normal
        normalVS.z = abs(normalVS.z);
        // From view to world space again
        inputData.normalWS = normalize( mul((float3x3)UNITY_MATRIX_I_V, normalVS) );
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



// Used in Standard (Physically Based) shader
FragmentOutput LitGBufferPassFragment(Varyings input, half facing : VFACE)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

//  Get the surface description
    SurfaceData surfaceData;
    AdditionalSurfaceData additionalSurfaceData;
    InitializeSurfaceData(input, surfaceData, additionalSurfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, facing, inputData);

#ifdef _DBUFFER
    #if defined(_RECEIVEDECALS)
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif
#endif

    #if defined(_GBUFFERLIGHTING_TRANSMISSION)
        uint meshRenderingLayers = GetMeshRenderingLayer();
    //  Beta 5: must be commented as otherwise screen space shadows bug
        //inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
        half4 shadowMask = CalculateShadowMask(inputData);
        AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        Light mainLight1 = GetMainLight(inputData, shadowMask, aoFactor);

        #if defined(_LIGHT_LAYERS)
            if (IsMatchingLightLayer(mainLight1.layerMask, meshRenderingLayers))
            {
        #endif
                half transPower = _TranslucencyPower;
                half3 transLightDir = mainLight1.direction + inputData.normalWS * _Distortion;
                half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                transDot = exp2(saturate(transDot) * transPower - transPower);

                #if defined(_SAMPLE_LIGHT_COOKIES)
                    real3 cookieColor = SampleMainLightCookie(inputData.positionWS);
                    mainLight1.color *= float4(cookieColor, 1);
                #endif

                half3 transmissionColor = (_OverrideTransmission) ? _TransmissionColor.rgb : surfaceData.albedo;
                surfaceData.emission +=
                    transDot 
                  * (1.0h - saturate(dot(mainLight1.direction, inputData.normalWS)))
                  * mainLight1.color * lerp(1, mainLight1.shadowAttenuation, _ShadowStrength)
                  * additionalSurfaceData.translucency * _TranslucencyStrength
                  * transmissionColor;

                // Light unityLight;
                // unityLight = GetMainLight();
                // unityLight.distanceAttenuation = 1.0; //?

                // #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && Donedefined(_SURFACE_TYPE_TRANSPARENT)
                //     float4 shadowCoord = float4(screen_uv, 0.0, 1.0);
                // #else
                //     float4 shadowCoord = TransformWorldToShadowCoord(posWS.xyz);
                // #endif
                // unityLight.shadowAttenuation = MainLightShadow(shadowCoord, posWS.xyz, shadowMask, _MainLightOcclusionProbes);
        #if defined(_LIGHT_LAYERS)
            }
        #endif
    #endif

    #if defined(_DEBUG)
        surfaceData.specular = 0;
        surfaceData.albedo = 0;
        surfaceData.occlusion = 0;

        if(_DebugVertexColor == 0) {
            surfaceData.emission = half3(input.color.r, 0, 0);
        }
        else if(_DebugVertexColor == 1) {
            surfaceData.emission = half3(0, input.color.g, 0);
        }
        else if(_DebugVertexColor == 2) {
            surfaceData.emission = half3(0, 0, input.color.b);
        }
        else {
            surfaceData.emission = input.color.aaa;
        }
        surfaceData.emission *= _DebugBrightness;
    #endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
    half3 color = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.normalWS, inputData.viewDirectionWS);

    return BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);
}

#endif