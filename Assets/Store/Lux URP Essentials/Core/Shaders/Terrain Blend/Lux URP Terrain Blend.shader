// TODO: https://community.khronos.org/t/slope-scale-depth-bias-in-opengl-3-2-core/62194/3

Shader "Lux URP/Terrain/Blend"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(rti5rpeh441g)]
        
        [Header(Surface Blending)]
        [Space(8)]
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
        [Space(8)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                       ("Culling", Float) = 2
        [Enum(Off,0,On,1)]
        _ZWrite                     ("ZWrite", Int) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _ZTest                      ("ZTest", Int) = 4
    //  [Toggle(_ALPHATEST_ON)]
    //  _AlphaClip                  ("Alpha Clipping", Float) = 0.0
    //  _Cutoff                     ("    Threshold", Range(0.0, 1.0)) = 0.5
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows             ("Receive Shadows", Float) = 1.0

        [Header(Deferred Rendering)]
        [Space(8)]
        [Toggle]
        _RenderInDeferred           ("Render in Deferred", Float) = 0
        _BlendThresholdVertex       ("     Vertex Blend Threshold ", Float) = 2.0
        _BlendThresholdPixel        ("     Pixel Blend Threshold", Float) = 1.0

        [Header(Surface Inputs)]
        [Space(8)]
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
        [Space(8)]
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
        [HideInInspector] _Cutoff   ("Alpha Cutoff", Range(0.0, 1.0)) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry-1"
            "ShaderModel"="4.5"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForwardOnly"}
            Blend SrcAlpha OneMinusSrcAlpha          
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            //ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

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

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"


// #if !defined(_ADDITIONAL_LIGHT_SHADOWS)
//     #define _ADDITIONAL_LIGHT_SHADOWS
// #endif

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

        //  Include base inputs and all other needed "base" includes
            #include "Includes/Lux URP Terrain Blend Inputs.hlsl"

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

        //--------------------------------------
        //  Vertex shader

            inline float DecodeFloatRG( float2 enc ) {
                float2 kDecodeDot = float2(1.0, 1/255.0);
                return dot( enc, kDecodeDot );
            }

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

            
            //  Get terrain height
                float fadeFactor = 1.0;
                UNITY_BRANCH if(_RenderInDeferred)
                {
                    float2 terrainUV = (vertexInput.positionWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
                    terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;
                    half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
                    float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;
                    fadeFactor = saturate(terrainHeight + _BlendThresholdVertex - vertexInput.positionWS.y);
                    if (fadeFactor == 0)
                    {
                        output.positionCS = vertexInput.positionCS / 0.0;
                        return output; 
                    }
                } 


            //  Pull positionCS.z towards camera / fine but clipping issues if we come very close. NANs?
                float fac = _ProjectionParams.y * 10 * fadeFactor;
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
                out SurfaceData outSurfaceData)
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

                outSurfaceData.clearCoatMask = 0;
                outSurfaceData.clearCoatSmoothness = 0;
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
                
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = input.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif
                
                inputData.fogCoord = input.fogFactorAndVertexLight.x;
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH * occlusion, inputData.normalWS);

                //inputData.normalizedScreenSpaceUV = input.positionCS.xy;
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
            }


            

        //  half4 LitPassFragment(VertexOutput input, half facing : VFACE, out float outDepth : DEPTH_SEMANTIC) : SV_Target
            half4 LitPassFragment(VertexOutput input, half facing : VFACE) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            //  Get the surface description
                SurfaceData surfaceData;
                InitializeSurfaceData(input.uv, surfaceData);

            //  Get terrain height
                float2 terrainUV = (input.positionWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
                terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;

                half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
                float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;

                surfaceData.alpha = smoothstep(0.0h, 1.0h, 1.0h - saturate( (terrainHeight - input.positionWS.y + _AlphaShift) * _AlphaWidth ) );   

            //  In case we use deferred this shader shall only output a small ring along the intersection
                UNITY_BRANCH if (_RenderInDeferred)
                {
                    surfaceData.alpha *= saturate(terrainHeight + _BlendThresholdPixel - input.positionWS.y);
                    clip(surfaceData.alpha - 0.001);
                }

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

            //  Let's go with the built in macro
                #if ( defined(_MAIN_LIGHT_SHADOWS) || defined(_MAIN_LIGHT_SHADOWS_CASCADE) ) && !defined(_RECEIVE_SHADOWS_OFF)
                    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS + finalShift);
                #endif

            //  Tweak viewDir
                half3 tweakedViewDir = GetCameraPositionWS() - float3(input.positionWS.x, terrainHeight, input.positionWS.z);
                tweakedViewDir = SafeNormalize(tweakedViewDir);
                inputData.viewDirectionWS = lerp(tweakedViewDir, inputData.viewDirectionWS, normalBlend);

            //  Decals
                #ifdef _DBUFFER
                    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
                #endif

            //  Apply lighting
                //half4 color = UniversalFragmentPBR
                half4 color = LuxFragmentBlendPBR(inputData, surfaceData, finalShift, normalBlend);

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
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            //#pragma shader_feature _ALPHATEST_ON
            

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            

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
            Name "DepthOnlyXXX"
            Tags{"LightMode" = "DepthOnlyXXX"}

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            // #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
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

                return input.positionCS.z;
            }

            ENDHLSL
        }

    
    //  We do not use this pass but rely on the 2nd material
        Pass
        {
            Name "DepthNormalsXXXX"
            Tags{"LightMode" = "DepthNormalsXXX"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthNormalVertex
            #pragma fragment DepthNormalFragment

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
            #include "Includes/Lux URP Terrain Blend Inputs.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //  Material Inputs
 
            struct VertexInputDN {
                float3 positionOS                   : POSITION;
                float3 normalOS                     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutputDN {
                float4 positionCS     : SV_POSITION;
                float3 positionWS     : TEXCOORD0;
                float3 normalWS       : TEXCOORD1;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            inline float DecodeFloatRG( float2 enc ) {
                float2 kDecodeDot = float2(1.0, 1/255.0);
                return dot( enc, kDecodeDot );
            }


            VertexOutputDN DepthNormalVertex(VertexInputDN input)
            {
                VertexOutputDN output = (VertexOutputDN)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldDir(input.normalOS, true);
                output.positionWS = TransformObjectToWorld(input.positionOS).xyz;

            //	Start skipped

			// //  Get terrain height
   //              float2 terrainUV = (output.positionWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
   //              terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;

   //              half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
   //              float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;

   //              float alpha = smoothstep(0.0f, 1.0f, 1.0f - saturate( (terrainHeight - output.positionWS.y + _AlphaShift) * _AlphaWidth ) );   

   //          //  Blend geometry normal towards the terrain normal
   //              half3 terrainNormal;
   //          //  This is not a tangent normal! So we have to swizzle y and z.
   //              terrainNormal.xz = terrainSample.ba * 2.0 - 1.0;
   //              terrainNormal.y = sqrt(1.0 - saturate(dot(terrainNormal.xz, terrainNormal.xz)));
   //              half normalBlend = saturate( (terrainHeight - output.positionWS.y + _NormalShift) * _NormalWidth );  
   //              normalBlend = normalBlend * (smoothstep( 0, _NormalThreshold, saturate(dot(terrainNormal.xyz, output.normalWS.xyz ))));
   //              normalBlend = 1.0h - normalBlend;
   //              //output.normalWS  = lerp( terrainNormal.xyz, output.normalWS, normalBlend);
   //          //	End skipped



// URP 12: This caused borders in SSAO ?????
// just skipping it we are fine?
// No: depth prepass does not work of course!!!!!

			//  Pull positionCS.z towards camera / fine but clipping issues if we come very close. NANs?
                float fac = _ProjectionParams.y * 10;
                #if UNITY_REVERSED_Z
                    output.positionCS.z += _Shift / max(_ProjectionParams.y, output.positionCS.w) * fac;
                #else
                    output.positionCS.z -= _Shift / max(_ProjectionParams.y, output.positionCS.w) * fac;
                #endif

                return output;
            }

            half4 DepthNormalFragment(VertexOutputDN input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                //  Get terrain height
                float2 terrainUV = (input.positionWS.xz - _TerrainPos.xz) / _TerrainSize.xz;
                terrainUV = (terrainUV * (_TerrainHeightNormal_TexelSize.zw - 1.0f) + 0.5 ) * _TerrainHeightNormal_TexelSize.xy;

                half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainHeightNormal, sampler_TerrainHeightNormal, terrainUV, 0);
                float terrainHeight = DecodeFloatRG(terrainSample.rg) * _TerrainSize.y + _TerrainPos.y;

                float alpha = smoothstep(0.0f, 1.0f, 1.0f - saturate( (terrainHeight - input.positionWS.y + _AlphaShift) * _AlphaWidth ) );   

            //  Blend geometry normal towards the terrain normal
                half3 terrainNormal;
            //  This is not a tangent normal! So we have to swizzle y and z.
                terrainNormal.xz = terrainSample.ba * 2.0 - 1.0;
                terrainNormal.y = sqrt(1.0 - saturate(dot(terrainNormal.xz, terrainNormal.xz)));
                half normalBlend = saturate( (terrainHeight - input.positionWS.y + _NormalShift) * _NormalWidth );  
                // normalBlend = normalBlend * (smoothstep( 0, _NormalThreshold, saturate(dot(terrainNormal.xyz, input.normalWS.xyz ))));
			
            // //	Always blend normal if below the terrain
			// 	float blendFactor = smoothstep( 0, _NormalThreshold, saturate(dot(terrainNormal.xyz, input.normalWS.xyz )));
			// 	blendFactor = (terrainHeight > input.positionWS.y) ? 1 : blendFactor;
			// 	normalBlend = normalBlend * blendFactor;
                
                normalBlend = 1.0h - normalBlend;


// This comment is from URP 11
   //  We better do not tweak the normal here - as it further increases the "error" between depth and normal.
   //  So the code above is just obsolete.
                
            //    input.normalWS.xyz = lerp( terrainNormal.xyz, input.normalWS.xyz, normalBlend);
                
                float3 normal = input.normalWS;
                //return float4(PackNormalOctRectEncode(TransformWorldToViewDir(normal, true)), 0.0, 0.0);
                return half4(NormalizeNormalPerPixel(normal), 0.0);

            }

            ENDHLSL
        }

    //  Meta -----------------------------------------------------
        
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

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

                outSurfaceData.clearCoatMask = 0;
                outSurfaceData.clearCoatSmoothness = 0;
            }

        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    //  End Passes -----------------------------------------------------
    
    }
    FallBack "Hidden/InternalErrorShader"
}
