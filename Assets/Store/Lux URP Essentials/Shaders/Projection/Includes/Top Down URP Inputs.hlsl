#ifndef INPUT_BASE_INCLUDED
#define INPUT_BASE_INCLUDED


    CBUFFER_START(UnityPerMaterial)
        
//        #if !defined(UNITY_PASS_SHADOWCASTER)
//#if !defined(CUSTOMMETAPASS)
        float4 _BaseMap_ST;

        half4 _SpecColor;
        half _BumpScale;
//#endif
//        #endif

        half _GlossMapScale;
        half _GlossMapScaleDyn;

        half4 _EmissionColor;
        half _Occlusion;

        
        half _BumpScaleDyn;

        half _NormalFactor;
        half _NormalLimit;
        half _TopDownTiling;
        float3 _TerrainPosition;
        half _LowerNormalMinStrength;
        half _LowerNormalInfluence;

        half _HeightBlendSharpness;

    //  Simple Fuzz
        half    _FuzzStrength;
        half    _FuzzAmbient;
        half    _FuzzWrap;
        half    _FuzzPower;        
        half    _FuzzBias;

    CBUFFER_END



    struct VertexInput
    {
        float4 positionOS   : POSITION;
        float3 normalOS     : NORMAL;
        float4 tangentOS    : TANGENT;
        float2 texcoord     : TEXCOORD0;
        float2 lightmapUV   : TEXCOORD1;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };


    struct VertexOutput {
        
        float4 positionCS               : SV_POSITION;
        //#ifdef _ADDITIONAL_LIGHTS
        float3 positionWS               : TEXCOORD0;
        //#endif
        #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(DEPTHONLYPASS)
            float4 uv                   : TEXCOORD1;
            #if !defined(CUSTOMMETAPASS)
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 2);
                float3 normalWS                  : TEXCOORD3;
                #ifdef _NORMALMAP
                    float4 tangentWS             : TEXCOORD4;    // xyz: tangent, w: tangent sign
                #endif
                float3 viewDirWS                 : TEXCOORD5;
                
                float4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord          : TEXCOORD7;
                #endif
            #endif

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
        half fuzzMask;
    };



#endif