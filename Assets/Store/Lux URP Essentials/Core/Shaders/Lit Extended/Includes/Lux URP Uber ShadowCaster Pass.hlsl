#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float4 positionOS       : POSITION;
    float4 tangentOS        : TANGENT;
    float2 texcoord         : TEXCOORD0;
    float3 normalOS         : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS       : SV_POSITION;
    float2 uv               : TEXCOORD1;
    half3 normalWS          : TEXCOORD2;

    #if defined(_ALPHATEST_ON)
        half4 tangentWS     : TEXCOORD3;
        float screenPos     : TEXCOORD4; // was float4
    #endif

    #if defined(_PARALLAX)
        half3 viewDirTS     : TEXCOORD5;
    #endif

    //UNITY_VERTEX_INPUT_INSTANCE_ID
};

//  Shadow caster specific input
float3 _LightDirection;
float3 _LightPosition;
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);

    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);

    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
        float3 lightDirectionWS = _LightDirection;
    #endif

    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    #if defined(_ALPHATEST_ON)
        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
        #if defined(_PARALLAXSHADOWS)
            output.normalWS = normalInput.normalWS;
            real sgn = input.tangentOS.w * GetOddNegativeScale();
            output.tangentWS = half4(normalInput.tangentWS, sgn);
        #endif
    #endif

//  When rendering backfaces normal extrusion is in the wrong direction...
//  Stopped working in URP 12?!
    //float facingNormal = dot(normalize(normalInput.normalWS), lightDirectionWS );
    //output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, sign(facingNormal) * normalInput.normalWS, lightDirectionWS));
    
    output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalInput.normalWS, lightDirectionWS));

    #if UNITY_REVERSED_Z
        output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif

    #if defined(_ALPHATEST_ON) && defined(_FADING_SHADOWS_ON)
        output.screenPos = distance(positionWS, GetCameraPositionWS() );
    #endif

    return output;
}


half4 ShadowPassFragment(Varyings input, half facing : VFACE) : SV_TARGET
{
    //UNITY_SETUP_INSTANCE_ID(input);

    //  LOD crossfading
    // #if defined(LOD_FADE_CROSSFADE) && !defined(SHADER_API_GLES)
    //     clip (unity_LODFade.x - Dither32(input.positionCS.xy, 1));
    // #endif
    #ifdef LOD_FADE_CROSSFADE
        LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_ALPHATEST_ON)
    //  Camera Fade
        #if defined(_FADING_SHADOWS_ON)
            clip ( input.screenPos - _CameraShadowFadeDist - Dither32(input.positionCS.xy, 1));
        #endif

        float2 uv = input.uv;

    //  Parallax
        #if defined(_PARALLAXSHADOWS)
        //  When it comes to shadows we can calculate the proper viewdirWS only for directional lights
        //  So all other lights will simply skip parallax extrusion
            float isDirectionalLight = UNITY_MATRIX_VP._m33;
            
            UNITY_BRANCH
            if(isDirectionalLight == 1) {
                input.normalWS.xyz *= facing;
                float sgn = input.tangentWS.w;      // should be either +1 or -1
                half3 bitangentWS = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                half3x3 tangentSpaceRotation =  half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS.xyz);
                //half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
            
            //  viewDirWS in case of the directional light equals cam forward
                half3 viewDirWS = UNITY_MATRIX_V[2].xyz;
                half3 viewDirTS = SafeNormalize( mul(tangentSpaceRotation, viewDirWS) );
                
                float3 v = viewDirTS;
                v.z += 0.42;
                v.xy /= v.z;
                float halfParallax = _Parallax * 0.5f;
                float parallax = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).g * _Parallax - halfParallax;
                float2 offset1 = parallax * v.xy;
            //  Calculate 2nd height
                parallax = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv + offset1).g * _Parallax - halfParallax;
                float2 offset2 = parallax * v.xy;
            //  Final UVs
                uv += (offset1 + offset2) * 0.5f;
            }
        #endif

        half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).a * _BaseColor.a;
        clip (alpha - _Cutoff);

    #endif
    return 0;
}