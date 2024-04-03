#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

//  Structs
struct Attributes
{
    float3 positionOS                   : POSITION;
    #if defined(_ALPHATEST_ON)
        float2 texcoord                 : TEXCOORD0;
    #else
        float3 normalOS                 : NORMAL;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS                   : SV_POSITION;
    #if defined(_ALPHATEST_ON)
        float2 uv                       : TEXCOORD0;
    #endif
    half  fogFactor                     : TEXCOORD1;
    //UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


Varyings OutlinePassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
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
        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    //  Extrude
        #if defined(_OUTLINEINSCREENSPACE)
            if (_Border > 0.0h) {
                float3 normal = mul(UNITY_MATRIX_MVP, float4(input.normalOS, 0)).xyz; // to clip space
                float2 offset = normalize(normal.xy);
                float2 ndc = _ScreenParams.xy * 0.5;
                output.positionCS.xy += ((offset * _Border) / ndc * output.positionCS.w);
            }
        #endif
    #else
        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    #endif

    output.fogFactor = ComputeFogFactor(output.positionCS.z);
    return output;
}

//  Helper
inline float2 shufflefast (float2 offset, float2 shift) {
    return offset * shift;
}

half4 OutlinePassFragment(Varyings input) : SV_TARGET
{
    //UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON)
        float2 uv = input.uv;

        float2 offset = float2(1,1);
        #if defined(_OUTLINEINSCREENSPACE)
            float2 shift = fwidth(uv) * (_Border * 0.5f);
        #else
            float2 shift = _Border.xx * float2(0.5, 0.5) * _BaseMap_TexelSize.xy;
        #endif

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

        //shuffleAlpha = saturate(shuffleAlpha); // not needed
        //shuffleAlpha *= 0.25;                  // bad!

    //  Mask inner parts - does not work properly with different _Cutoff values?!
    //  So we go with ZTest Less 
        //shuffleAlpha = shuffleAlpha * ( 1 - step(_Cutoff, innerAlpha) );
        //shuffleAlpha = lerp(shuffleAlpha, 0, step(_Cutoff, innerAlpha) );
    //  Apply clip
        clip(shuffleAlpha - _Cutoff);
    #endif
    half4 color = _OutlineColor;
    color.rgb = MixFog(color.rgb, input.fogFactor);
    return color;
}