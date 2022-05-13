// TODO: https://community.khronos.org/t/slope-scale-depth-bias-in-opengl-3-2-core/62194/3

Shader "Lux URP/Terrain/Blend"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(rti5rpeh441g)]
        
        [Header(Surface Blending)]
        [Space(5)]
      //_Offset 					("Offset", Range(-300, 0)) = 0
        _Shift                      ("Depth Shift", Range(0.0, 0.3)) = 0.1
        [Space(5)]
        [NoScaleOffset]
        _TerrainHeightNormal        ("Terrain Height Normal", 2D) = "white" {}
        [LuxURPVectorThreeDrawer]
        _TerrainPos                 ("Terrain Position", Vector) = (0,0,0,0)
        [LuxURPVectorThreeDrawer]
        _TerrainSize                ("Terrain Size", Vector) = (1,1,1,0)
        [Space(5)]
        _AlphaShift                 ("Alpha Shift", Range(-5, 5)) = 0
        _AlphaWidth                 ("Alpha Contraction", Range(1, 20)) = 4
        [Space(5)]
        _ShadowShiftThreshold       ("Shadow Shift Threshold", Range(0, 0.1)) = 0.05
        _ShadowShift                ("Shadow Shift", Range(0, 1)) = 1
        _ShadowShiftView            ("Shadow Shift View", Range(0, 1)) = 0
        [Space(5)]
        _NormalShift                ("Normal Shift", Range(-5, 5)) = 0
        _NormalWidth                ("Normal Contraction", Range(0, 20)) = 0
        _NormalThreshold 			("Normal Threshold", Range(0,1)) = .2


        [Header(Surface Options)]
        [Space(5)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                       ("Culling", Float) = 2
        [Enum(Off,0,On,1)]
        _ZWrite                     ("ZWrite", Int) = 1
    //  [Toggle(_ALPHATEST_ON)]
    //  _AlphaClip                  ("Alpha Clipping", Float) = 0.0
    //  _Cutoff                     ("    Threshold", Range(0.0, 1.0)) = 0.5
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0


        [Header(Surface Inputs)]
        [Space(5)]
        [MainColor]
        _BaseColor                  ("Color", Color) = (1,1,1,1)
        [MainTexture]
        _BaseMap                    ("Albedo (RGB) Alpha (A)", 2D) = "white" {}

        [Space(5)]
        _Smoothness                 ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor                  ("Specular", Color) = (0.2, 0.2, 0.2)

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                ("Enable Normal Map", Float) = 0.0
        [NoScaleOffset]
        _BumpMap                    ("     Normal Map", 2D) = "bump" {}
        _BumpScale                  ("     Normal Scale", Float) = 1.0


        [Header(Advanced)]
        [Space(5)]
        [ToggleOff]
        _SpecularHighlights         ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections     ("Environment Reflections", Float) = 1.0
        [Space(5)]
        [Toggle(_RECEIVE_SHADOWS_OFF)]
        _Shadows                    ("Disable Receive Shadows", Float) = 0.0

    //  Needed by the inspector
        [HideInInspector] _Culling  ("Culling", Float) = 0.0

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _MainTex  ("Albedo", 2D) = "white" {}
        [HideInInspector] _Color    ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry+2"
        }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend SrcAlpha OneMinusSrcAlpha          
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma target 2.0

            #if !defined(DEPTH_SEMANTIC)
                #if defined(SHADER_API_D3D11)
                    #define DEPTH_SEMANTIC SV_DepthGreaterEqual
                #else
                    #define DEPTH_SEMANTIC SV_Depth
                #endif
            #endif            

            // -------------------------------------
            // Material Keywords
            #define _SPECULAR_SETUP 1

            #pragma shader_feature_local _NORMALMAP
            // #pragma shader_feature _ALPHATEST_ON

        //  We have to sample SH per pixel
            #if defined (EVALUATE_SH_VERTEX)
                #undef EVALUATE_SH_VERTEX
            #endif
            #if defined(EVALUATE_SH_MIXED)
                #undef EVALUATE_SH_MIXED
            #endif

            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Lightweight Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Terrain Blend Inputs.hlsl"

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

        //--------------------------------------
        //  Vertex shader


            VertexOutput LitPassVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput; 
                vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                float3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
                half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

            //  Pull positionCS.z towards camera / fine but clipping issues if we come very close. NANs?
                float fac = _ProjectionParams.y * 10;
                #if UNITY_REVERSED_Z
                    vertexInput.positionCS.z += _Shift / max(_ProjectionParams.y, vertexInput.positionCS.w) * fac;
                #else
                    vertexInput.positionCS.z -= _Shift / max(_ProjectionParams.y, vertexInput.positionCS.w) * fac;
                #endif

                output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);

                // already normalized from normal transform to WS.
                output.normalWS = normalInput.normalWS;
                output.viewDirWS = viewDirWS;
 
                #ifdef _NORMALMAP
                    float sign = input.tangentOS.w * GetOddNegativeScale();
                    output.tangentWS = float4(normalInput.tangentWS.xyz, sign);
                #endif

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
                
                output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

                //#ifdef _ADDITIONAL_LIGHTS
                    output.positionWS = vertexInput.positionWS;
                //#endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    output.shadowCoord = GetShadowCoord(vertexInput);
                #endif
                output.positionCS = vertexInput.positionCS;

                return output;
            }

        //--------------------------------------
        //  Fragment shader and functions

            inline void InitializeSurfaceData(
                float2 uv,
                out SurfaceDescription outSurfaceData)
            {
                half4 albedoAlpha = SampleAlbedoAlpha(uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                outSurfaceData.alpha = Alpha(albedoAlpha.a, 1, _Cutoff);
                outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

                
                outSurfaceData.metallic = 0;
                outSurfaceData.specular = _SpecColor.rgb;
                outSurfaceData.smoothness = _Smoothness;
                
                outSurfaceData.smoothness *= albedoAlpha.a;

                outSurfaceData.occlusion = 1;
            
            //  Normal Map
                #if defined (_NORMALMAP)
                    outSurfaceData.normalTS = SampleNormal(uv.xy, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
                #else
                    outSurfaceData.normalTS = half3(0,0,1);
                #endif

                outSurfaceData.emission = 0;
            }

            void InitializeInputData(VertexOutput input, half3 normalTS, half occlusion, half facing, out InputData inputData)
            {
                inputData = (InputData)0;
                #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                    inputData.positionWS = input.positionWS;
                #endif

                half3 viewDirWS = SafeNormalize(input.viewDirWS);
                
                #if defined(_NORMALMAP)
                    normalTS.z *= facing;
                    float sgn = input.tangentWS.w;      // should be either +1 or -1
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
                #else
                    inputData.normalWS = input.normalWS * facing;
                #endif

                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                inputData.viewDirectionWS = viewDirWS;
                
                //#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
                //    inputData.shadowCoord = input.shadowCoord;
                //#else
                //    inputData.shadowCoord = float4(0, 0, 0, 0);
                //#endif

                /*
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = input.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif
                */

                inputData.fogCoord = input.fogFactorAndVertexLight.x;
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH * occlusion, inputData.normalWS);
            }


            inline float DecodeFloatRG( float2 enc ) {
                float2 kDecodeDot = float2(1.0, 1/255.0);
                return dot( enc, kDecodeDot );
            }

        //  half4 LitPassFragment(VertexOutput input, half facing : VFACE, out float outDepth : DEPTH_SEMANTIC) : SV_Target
            half4 LitPassFragment(VertexOutput input, half facing : VFACE) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            //  Get the surface description
                SurfaceDescription surfaceData;
                InitializeSurfaceData(input.uv, surfaceData);

            //  Get terrain height
                float2 terrainUV = (input.positionWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
                terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;

                half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
                float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;



                surfaceData.alpha = smoothstep(0.0h, 1.0h, 1.0h - saturate( (terrainHeight - input.positionWS.y + _AlphaShift) * _AlphaWidth ) );   

            //  Blend geometry normal towards the terrain normal
                half3 terrainNormal;
            //  This is not a tangent normal! So we have to swizzle y and z.
                terrainNormal.xz = terrainSample.ba * 2.0 - 1.0;
                terrainNormal.y = sqrt(1.0 - saturate(dot(terrainNormal.xz, terrainNormal.xz)));
                half normalBlend = saturate( (terrainHeight - input.positionWS.y + _NormalShift) * _NormalWidth );  
                normalBlend = normalBlend * (smoothstep( 0, _NormalThreshold, saturate(dot(terrainNormal.xyz, input.normalWS.xyz ))));
                normalBlend = 1.0h - normalBlend;
                input.normalWS.xyz = lerp( terrainNormal.xyz, input.normalWS.xyz, normalBlend);

            //  Prepare surface data (like bring normal into world space and get missing inputs like gi)
                InputData inputData;
                InitializeInputData(input, surfaceData.normalTS, surfaceData.occlusion, facing, inputData);

            //  shadowShift contains the (tweaked) distance to the terrain surface for pixels under the terrain
                float shadowShift = -min(0, input.positionWS.y - _ShadowShiftThreshold - terrainHeight);
                float3 viewShift = shadowShift * _ShadowShiftView * inputData.viewDirectionWS;
                shadowShift *= _ShadowShift;
                float3 finalShift = float3(0, shadowShift, 0) + viewShift;

            //  Calculate shadowCoord. We have to do it per pixel :(
                #if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
                    #if defined(_MAIN_LIGHT_SHADOWS_CASCADE)
                        half cascadeIndex = ComputeCascadeIndex(input.positionWS);
                    #else
                        half cascadeIndex = 0;
                    #endif
                //  As we do not want shadows on the blended parts from the geometry they intersect with we have to "somehow" shift the shadowCoords.
                //  Shifting along view dir: Best so far...
//                  inputData.shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(input.positionWS + inputData.viewDirectionWS * _ShadowShift /*_AlphaShift*/, 1.0));
                //  Pulling pixels towards the light fails if we look along the light direction...
//                  inputData.shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(input.positionWS + _MainLightPosition.xyz * _ShadowShift /*_AlphaShift*/, 1.0));
                //  Shifting along the terrain normal?
//              inputData.shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(input.positionWS   + terrainNormal * _ShadowShift * shadowShift , 1.0));
                //  We simply lift the shadow sampling coord
                    inputData.shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(input.positionWS + finalShift, 1.0));
                #endif

            //  Tweak viewDir
                half3 tweakedViewDir = GetCameraPositionWS() - float3(input.positionWS.x, terrainHeight, input.positionWS.z);
                tweakedViewDir = SafeNormalize(tweakedViewDir);
                inputData.viewDirectionWS = lerp(tweakedViewDir, inputData.viewDirectionWS, normalBlend);

            //  Apply lighting
                //half4 color = UniversalFragmentPBR
                half4 color = LuxFragmentBlendPBR(inputData, surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha,
                    finalShift
                );

            //  Add fog
                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                return color;
            }

            ENDHLSL
        }


    //  Shadows -----------------------------------------------------
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            //#pragma shader_feature _ALPHATEST_ON
            

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Terrain Blend Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
        //  Shadow caster specific input
            float3 _LightDirection;

            VertexOutput ShadowPassVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                #if defined(_ALPHATEST_ON)
                    output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldDir(input.normalOS);

                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                return output;
            }

            half4 ShadowPassFragment(VertexOutput input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #if defined(_ALPHATEST_ON)
                    half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;
                    clip (mask - _Cutoff);
                #endif

                return 0;
            }
            ENDHLSL
        }

    //  Depth -----------------------------------------------------

        Pass
        {
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            // #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #define DEPTHONLYPASS
            #include "Includes/Lux URP Terrain Blend Inputs.hlsl"

            VertexOutput DepthOnlyVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if defined(_ALPHATEST_ON)
                    output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 DepthOnlyFragment(VertexOutput input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #if defined(_ALPHATEST_ON)
                    half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy).a;
                    clip (mask - _Cutoff);
                #endif

                return 0;
            }

            ENDHLSL
        }

    //  Meta -----------------------------------------------------
        
        Pass
        {
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMeta

            //#define _SPECULAR_SETUP

        //  First include all our custom stuff
            #include "Includes/Lux URP Terrain Blend Inputs.hlsl"

        //--------------------------------------
        //  Fragment shader and functions

            inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
            {
                half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                outSurfaceData.alpha = 1;
                outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
                outSurfaceData.metallic = 0;
                outSurfaceData.specular = _SpecColor.rgb;
                outSurfaceData.smoothness = _Smoothness;
                outSurfaceData.normalTS = half3(0,0,1);
                outSurfaceData.occlusion = 1;
                outSurfaceData.emission = 0;
            }

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }
    FallBack "Hidden/InternalErrorShader"
}
