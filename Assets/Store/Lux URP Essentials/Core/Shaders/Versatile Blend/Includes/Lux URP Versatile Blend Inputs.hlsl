#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "../Includes/Lux URP Blend Lighting.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)
        float   _Shift;
        half    _BlendWidth;
        half    _BlendSharpness;
        half    _AlphaShift;
        half    _AlphaWidth;
        float   _ShadowShiftThreshold;
        float   _ShadowShift;
        float   _ShadowShiftView;
        half    _BumpScale;
        half4   _BaseColor;
        half    _Cutoff;
        float4  _BaseMap_ST;
        half    _Smoothness;
        half4   _SpecColor;
        half    _OcclusionStrength;
    CBUFFER_END

//  Additional textures
    #if defined(_MASKMAP)
        TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
    #endif
//  Depth texture
    #if defined(SHADER_API_GLES)
        TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
    #else
        TEXTURE2D_X_FLOAT(_CameraDepthTexture);
        float4 _CameraDepthTexture_TexelSize;
    #endif
    
//  Global Inputs

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
    #endif

//  Structs
    struct VertexInput
    {
        float3 positionOS                   : POSITION;
        float3 normalOS                     : NORMAL;
        float4 tangentOS                    : TANGENT;
        float2 texcoord                     : TEXCOORD0;
        float2 staticLightmapUV             : TEXCOORD1;
        float2 dynamicLightmapUV            : TEXCOORD2;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    
    struct VertexOutput
    {
        float2 uv                               : TEXCOORD0;
        
        #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(DEPTHONLYPASS)
            //#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                float3 positionWS               : TEXCOORD1;
            //#endif
            float3 normalWS                     : TEXCOORD2;
            #if defined(_NORMALMAP)
                half4 tangentWS                : TEXCOORD3;
            #endif
            #ifdef _ADDITIONAL_LIGHTS_VERTEX
                half4 fogFactorAndVertexLight   : TEXCOORD4; // x: fogFactor, yzw: vertex light
            #else
                half  fogFactor                 : TEXCOORD4;
            #endif

            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord              : TEXCOORD5;
            #endif

            float2 screenUV                     : TEXCOORD6;
            
            DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
            #ifdef DYNAMICLIGHTMAP_ON
                float2  dynamicLightmapUV       : TEXCOORD8;
            #endif
        #endif

        #ifdef USE_APV_PROBE_OCCLUSION
            float4 probeOcclusion               : TEXCOORD10;
        #endif

        float4 positionCS                       : SV_POSITION;

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    struct SurfaceDescription
    {
        half3 albedo;
        half alpha;
        half3 normalTS;
        half3 emission;
        half metallic;
        half3 specular;
        half smoothness;
        half occlusion;
    };

#endif