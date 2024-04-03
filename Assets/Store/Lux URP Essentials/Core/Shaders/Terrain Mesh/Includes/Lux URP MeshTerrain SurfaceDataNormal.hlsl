// Function to get the normal for the DepthNormal pass
#if defined(_NORMALMAP) && defined(_NORMALINDEPTHNORMALPASS)
    inline void InitializeNormalData(Varyings input, out half3 normalTS)
    {
        
        float2 detailUV = input.uv * _SplatTiling;
        half4 splatControl = 0;
        half3 topdownNormal = 0;

        #if defined(_USEVERTEXCOLORS)
            splatControl = input.color;
        #else
            splatControl.rgb = SAMPLE_TEXTURE2D(_SplatMap, sampler_SplatMap, input.uv.xy).rgb;
        #endif
        splatControl.a = 1.0h - splatControl.r - splatControl.g - splatControl.b;
        
        #if defined(_TOPDOWNPROJECTION)
            float2 uvWS = input.positionWS.xz * _TopDownTiling;
        #endif
        
        normalTS = half3(0,0,1);
        
        #if defined(_NORMALMAP)
            half4 nrm = 0.0h;
            #if defined(_TOPDOWNPROJECTION)
                topdownNormal = UnpackNormal (SAMPLE_TEXTURE2D(_Normal0, sampler_Normal0, uvWS));
            //  Without safe normalization of gba normals are off withing the blend range.
                splatControl.gba /= dot( max(splatControl.gba, half3(0.0001h, 0.0001h, 0.0001h)), half3(1.0h,1.0h,1.0h));
            #else
                nrm = SAMPLE_TEXTURE2D(_Normal0, sampler_Normal0, detailUV) * splatControl.r;
            #endif
            nrm += SAMPLE_TEXTURE2D(_Normal1, sampler_Normal0, detailUV) * splatControl.g;
            nrm += SAMPLE_TEXTURE2D(_Normal2, sampler_Normal0, detailUV) * splatControl.b;
            nrm += SAMPLE_TEXTURE2D(_Normal3, sampler_Normal0, detailUV) * splatControl.a;
            normalTS = UnpackNormal(nrm);
        #endif

        #if defined(_TOPDOWNPROJECTION) && defined(_NORMALMAP)
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            normalTS = normalize(TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz)));
        //  We use Reoriented Normal Mapping to bring the the top down normal into world space
            half3 n1 = /*normalize*/(input.normalWS.xzy);
            half3 n2 = topdownNormal.xyz;
            n1.z += 1.0h;
            n2.xy *= -1.0h;
            half3 topDownNormalWS = n1 * dot(n1, n2) / n1.z - n2;
            topDownNormalWS = topDownNormalWS.xzy;
        //  Finally we blend both normals in world space 
            normalTS = normalize(normalTS * (1.0h - splatControl.r) + topDownNormalWS * splatControl.r);
        #endif
    }
#endif