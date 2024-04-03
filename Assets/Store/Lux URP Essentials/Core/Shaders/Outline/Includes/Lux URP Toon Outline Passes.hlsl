CBUFFER_START(UnityPerMaterial)
    half4 _BaseColor;
    half _Border;
    half _Cutoff;
CBUFFER_END

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
    #endif

#if defined(_ALPHATEST_ON)
    TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap); float4 _BaseMap_ST;
#endif

#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float4 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    #if defined(_ALPHATEST_ON)
        float2 texcoord     : TEXCOORD0;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    #if defined(LITPASS)
        half fogCoord : TEXCOORD0;
    #endif
    #if defined(DEPTHNORMALSPASS)
        half3 normalWS : TEXCOORD1;
    #endif
    #if defined(_ALPHATEST_ON)
        float2 uv     : TEXCOORD2;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


//--------------------------------------
// Shared vertex shader

Varyings vert (Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    #if !defined(_ALPHATEST_ON)
    //  Extrude
        #if !defined(_OUTLINEINSCREENSPACE)
            #if defined(_COMPENSATESCALE)
                float3 scale;
                scale.x = length(float3(UNITY_MATRIX_M[0].x, UNITY_MATRIX_M[1].x, UNITY_MATRIX_M[2].x));
                scale.y = length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y));
                scale.z = length(float3(UNITY_MATRIX_M[0].z, UNITY_MATRIX_M[1].z, UNITY_MATRIX_M[2].z));
            #endif
                input.positionOS.xyz += input.normalOS * 0.001 * _Border
            #if defined(_COMPENSATESCALE) 
                / scale
            #endif
            ;
        #endif
    #endif

    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

    #if defined(LITPASS)
        output.fogCoord = ComputeFogFactor(output.positionCS.z);
    #endif

    #if !defined(_ALPHATEST_ON)
    //  Extrude
        #if defined(_OUTLINEINSCREENSPACE)
            if (_Border > 0.0h) {
                //float3 normal = mul(UNITY_MATRIX_MVP, float4(v.normal, 0)).xyz; // to clip space
                float3 normal = mul(GetWorldToHClipMatrix(), TransformObjectToWorldNormal(input.normalOS) ).xyz;
                float2 offset = normalize(normal.xy);
                float2 ndc = _ScreenParams.xy * 0.5;
                output.positionCS.xy += ((offset * _Border) / ndc * output.positionCS.w);
            }
        #endif
    #endif

//  Alpha testing
    #if defined(_ALPHATEST_ON)
        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    #endif

    #if defined(DEPTHNORMALSPASS)
        output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    #endif

    return output;
}

//--------------------------------------
//  Shared fragment shader

//  Helper
inline float2 shufflefast (float2 offset, float2 shift) {
    return offset * shift;
}

#if defined(DEPTHNORMALSPASS)
    void frag(
        Varyings input
        , out half4 outNormalWS : SV_Target0
    #ifdef _WRITE_RENDERING_LAYERS
        , out float4 outRenderingLayers : SV_Target1
    #endif
    )
#else
    half4 frag (Varyings input) : SV_Target
#endif
    {
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON)
        
        half innerAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;

    //  Outline
        float2 uv = input.uv;

        float2 offset = float2(1,1);
        float2 shift = fwidth(uv) * _Border * 0.5f;

        float2 sampleCoord = uv + shufflefast(offset, shift); 
        half shuffleAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

        offset = float2(-1,1);
        sampleCoord = uv + shufflefast(offset, shift);
        shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

        offset = float2(1,-1);
        sampleCoord = uv + shufflefast(offset, shift);
        shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;

        offset = float2(-1,-1);
        sampleCoord = uv + shufflefast(offset, shift);
        shuffleAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, sampleCoord).a;
    
    //  Mask inner parts - which is not really needed when using the stencil buffer. Let's do it anyway, just in case.
        shuffleAlpha = lerp(shuffleAlpha, 0, step(_Cutoff, innerAlpha) );
    //  Apply clip
        //outSurfaceData.alpha = Alpha(shuffleAlpha, 1, _Cutoff);
        clip(shuffleAlpha - _Cutoff);
    #endif

    #if defined(LITPASS)
        half4 color = _BaseColor;
        color.rgb = MixFog(color.rgb, input.fogCoord);
        return half4(color);
    #else
        #if defined(DEPTHONLYPASS)
            return input.positionCS.z;
        #else 
            #if defined(_GBUFFER_NORMALS_OCT)
                float3 normalWS = normalize(input.normalWS);
                float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
                float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
                half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
                outNormalWS = half4(packedNormalWS, 0.0);
            #else
                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
                outNormalWS = half4(normalWS, 0.0);
            #endif 
            #ifdef _WRITE_RENDERING_LAYERS
                uint renderingLayers = GetMeshRenderingLayer();
                outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
            #endif 
        #endif  
    #endif
}