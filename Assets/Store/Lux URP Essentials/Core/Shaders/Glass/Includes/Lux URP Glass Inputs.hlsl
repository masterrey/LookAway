#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "../Includes/Lux URP Transparent Lighting.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)
        half    _FinalAlpha;
        float   _IOR;
        half    _BumpRefraction;
        float   _IsThinShell;

        half4   _BaseColor;
        half    _Smoothness;
        half4   _SpecColor;

        float   _ScreenEdgeFade;

    //  None glass
        half    _SmoothnessBase;
        half4   _SpecColorBase;    

    //  Needed by LitMetaPass
        float4  _BaseMap_ST;
        float4  _BumpMap_ST;
        half    _BumpScale;
        float4  _MaskMap_ST;

        half4   _RimColor;
        half    _RimPower;
        half    _RimMinPower;
        half    _RimFrequency;
        half    _RimPerPositionFrequency;
    CBUFFER_END

//  Additional textures

    TEXTURE2D_X(_CameraOpaqueTexture);
//  Not needed anymore since URP 14.0.7
    // SAMPLER(sampler_LinearClamp);
    
    float4 _CameraOpaqueTexture_TexelSize;
    SamplerState my_linear_clamp_sampler;

    #if defined(SHADER_API_GLES)
        TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
    #else
        TEXTURE2D_X(_CameraDepthTexture); //SAMPLER(sampler_PointClamp);
    #endif
    float4 _CameraDepthTexture_TexelSize;
    
    #if defined(_MASKMAP)
        TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
    #endif
    #if defined(_TINTMAP)
        TEXTURE2D(_TintMap); SAMPLER(sampler_TintMap);
    #endif

//  Global Inputs

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
    #endif

//  Keep old naming because of the meta pass...

//  Structs
    struct VertexInput
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
   //   half4 color                         : COLOR;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    
    struct VertexOutput
    {
        float4 positionCS                   : SV_POSITION;
        float2 uv                           : TEXCOORD0;

        #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(DEPTHONLYPASS)
            DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 1);
            #ifdef DYNAMICLIGHTMAP_ON
                float2  dynamicLightmapUV   : TEXCOORD4; // Dynamic lightmap UVs
            #endif
            //#ifdef _ADDITIONAL_LIGHTS
                float3 positionWS           : TEXCOORD2;
            //#endif
            half3 normalWS                  : TEXCOORD3;
            //float3 viewDirWS              : TEXCOORD4;
            #if defined(_NORMALMAP)
                half4 tangentWS             : TEXCOORD5;
            #endif
            half4 fogFactorAndVertexLight   : TEXCOORD6;
            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord          : TEXCOORD7;
            #endif
            float4 projectionCoord          : TEXCOORD8;
            float  scale                    : TEXCOORD9;

        #endif

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