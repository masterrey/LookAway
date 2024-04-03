#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
    // We must not include the file above as it declares _BaseMap_TexelSize outside the CBuffer and thus breaks the batcher...
    // SO we include out copy:
    #include "Lux URP Toon SurfaceInputs.hlsl"

//  Must be declared before we can include Lighting.hlsl
    struct AdditionalSurfaceData
    {
        half3 albedoShaded;
    };


//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 
    #include "../Includes/Lux URP Toon Lighting.hlsl"

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)

        half4   _BaseColor;
        half    _Cutoff;
        float4  _BaseMap_ST;
        half    _Smoothness;
        half4   _SpecColor;

    //  Decals
        half4   _ShadedDecalColor;

    //  Toon
        half4   _ShadedBaseColor;
        half    _Steps;
        half    _DiffuseStep;
        half    _DiffuseFallOff;

        half    _Anisotropy;
        half    _EnergyConservation;
        half    _SpecularStep;
        half    _SpecularFallOff;
        
        half    _ColorizedShadowsMain;
        half    _ColorizedShadowsAdd;
        half    _LightColorContribution;
        half    _AddLightFallOff;
        half    _ShadowFallOff;
        half    _ShadoBiasDirectional;
        half    _ShadowBiasAdditional;
        half4   _SpecColor2nd;

        half4   _ToonRimColor;
        half    _ToonRimPower;
        half    _ToonRimFallOff;
        half    _ToonRimAttenuation;

        half4   _EmissionColor;

    //  Simple
        half    _BumpScale;
        float4  _MaskMap_ST;
        half    _OcclusionStrength;

        half    _ShadowOffset;

        half4   _RimColor;
        half    _RimPower;
        half    _RimMinPower;
        half    _RimFrequency;
        half    _RimPerPositionFrequency;

    //  Outline
        half4   _OutlineColor;
        half    _Border;

        half    _Surface;
        half    _LuxSurface;
        half    _LuxBlend;

        float4  _GradientMap_TexelSize;
        float4  _BaseMap_TexelSize;
        
    CBUFFER_END

//  Additional textures
//  Toon
    #if defined(_TEXMODE_TWO)
        TEXTURE2D(_ShadedBaseMap);
    #endif
    #if defined(_MASKMAP)
        TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
    #endif

//  Global Inputs

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
            UNITY_DOTS_INSTANCED_PROP(float , _Surface)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
        #define _Surface                UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Surface)
    #endif

//  Structs
    struct VertexInput
    {
        float3 positionOS                   : POSITION;
        float3 normalOS                     : NORMAL;
        #if defined(_NORMALMAP) || (defined(_ANISOTROPIC) && !defined(_SPECULARHIGHLIGHTS_OFF))
            float4 tangentOS                : TANGENT;
        #endif
        #if defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO) || defined(_NORMALMAP) || defined(_MASKMAP)
            float2 texcoord                 : TEXCOORD0;
        #endif
        #if defined(LIGHTMAP_ON)
            float2 staticLightmapUV         : TEXCOORD1;
        #endif
        #ifdef DYNAMICLIGHTMAP_ON
            float2 dynamicLightmapUV        : TEXCOORD2;
        #endif
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    
    struct VertexOutput
    {
        float4 positionCS                       : SV_POSITION;
        #if defined(_TEXMODE_ONE) || defined(_TEXMODE_TWO) || defined(_TEXMODE_TWO) || defined(_NORMALMAP) || defined(_MASKMAP)
            float2 uv                           : TEXCOORD0;
        #endif

        #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(DEPTHONLYPASS)
            DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 1);
            #ifdef DYNAMICLIGHTMAP_ON
                float2  dynamicLightmapUV       : TEXCOORD8;
            #endif
            #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                float3 positionWS               : TEXCOORD2;
            #endif
            half3 normalWS                      : TEXCOORD3;
            #if defined(_NORMALMAP) || (defined(_ANISOTROPIC) && !defined(_SPECULARHIGHLIGHTS_OFF))
                half4 tangentWS                 : TEXCOORD5;
            #endif
            #ifdef _ADDITIONAL_LIGHTS_VERTEX
                half4 fogFactorAndVertexLight   : TEXCOORD6;
            #else
                half  fogFactor                 : TEXCOORD6;
            #endif
            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord              : TEXCOORD7;
            #endif
        #endif

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    struct SurfaceDescription
    {
        half3 albedo;
        half3 albedoShaded;
        half alpha;
        half3 normalTS;
        half3 emission;
        half metallic;
        half3 specular;
        half smoothness;
        half occlusion;
    };

#endif