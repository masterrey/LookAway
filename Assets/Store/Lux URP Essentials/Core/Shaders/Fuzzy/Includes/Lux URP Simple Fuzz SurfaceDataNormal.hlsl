//  Surface function
#ifdef _NORMALINDEPTHNORMALPASS
    inline void InitializeNormalData(Varyings input, half facing, out half3 normalTS)
    {
        #ifdef _NORMALMAP
            normalTS = SampleNormal(input.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);

            // #if defined(SHADER_STAGE_FRAGMENT)
            //     normalTS.z *= input.cullFace ? 1 : -1;
            // #endif
            normalTS.z *= facing;

            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            normalTS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
        #else
            normalTS = input.normalWS.xyz;
            
            // #if defined(SHADER_STAGE_FRAGMENT)
            //     normalTS *= input.cullFace ? 1 : -1;
            // #endif
            normalTS.z *= facing;
            
        #endif
    }
#endif