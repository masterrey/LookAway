Shader "Lux URP/Projection/Decal Lit"
{
    Properties
    {
        [HeaderHelpLuxURP_URL(skzrp97i0tvt)]
        
        [Header(Surface Options)]
        [Space(8)]
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows                                 ("Receive Shadows", Float) = 1.0
        [Toggle(ORTHO_SUPPORT)]
        _OrthoSpport                                    ("Enable Orthographic Support", Float) = 0
        [Toggle(HQ_SAMPLING)]
        _HQSampling                                     ("Enable HQ Sampling", Float) = 0
        [Toggle(NORMALS_SAMPLING)]
        _NormalBuffer                                   ("Enable Normal Buffer (SSAO)", Float) = 0

        [Header(Surface Inputs)]
        [Space(8)]
        [HDR]_Color                                     ("Color", Color) = (1,1,1,1)
        [NoScaleOffset] _BaseMap                        ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
        _Smoothness                                     ("Smoothness", Range (0, 1)) = 0.1
        _SpecColor                                      ("Specular", Color) = (0.2, 0.2, 0.2)

        [Space(10)]
        [Toggle(_DECALNORMAL)] _DecalNormal             ("Blend with Decal Normal", Float) = 0.0  
        _DecalNormalStrength                            ("     Decal Normal Strength", Range(0, 1)) = 0.5

        [Space(10)]
        [Toggle(_NORMALMAP)] _ApplyNormal               ("Enable Normal Map", Float) = 1.0
        [NoScaleOffset] _BumpMap                        ("     Normal Map", 2D) = "bump" {}
        _BumpScale                                      ("     Normal Scale", Float) = 1.0

        [Header(Mask Map)]
        [Space(8)]
        [Toggle(_COMBINEDTEXTURE)] _CombinedTexture     ("Enable Mask Map", Float) = 0.0
        [NoScaleOffset] _MaskMap                        ("     Metallness (R) Occlusion (G) Emission (B) Smoothness (A) ", 2D) = "bump" {}
        [HDR]_EmissionColor                             ("     Emission Color", Color) = (0,0,0,0)
        _Occlusion                                      ("     Occlusion", Range(0.0, 1.0)) = 1.0

        [Header(Distance Fading)]
        [Space(8)]
        [LuxURPDistanceFadeDrawer]
        _DistanceFade                                   ("Distance Fade Params", Vector) = (2500, 0.001, 0, 0)

        [Header(Stencil)]
        [Space(8)]
        [IntRange] _StencilRef                          ("Stencil Reference", Range (0, 255)) = 0
        [IntRange] _ReadMask                            ("     Read Mask", Range (0, 255)) = 255
        [IntRange] _WriteMask                           ("     Write Mask", Range (0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)]
        _StencilCompare                                 ("Stencil Comparison", Int) = 8 // always

        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights                             ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections                         ("Environment Reflections", Float) = 1.0

    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Transparent" // +59 smalltest to get drawn on top of transparents
        }
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Stencil {
                Ref  [_StencilRef]
                ReadMask [_ReadMask]
                WriteMask [_WriteMask]
                Comp [_StencilCompare]
            }


            Blend SrcAlpha OneMinusSrcAlpha

        //  We draw backfaces to prevent clipping
            Cull Front
        //  So we have to set ZTest to always
            ZTest Always
        //  It is a decal!
            ZWrite Off

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            // _NORMALMAP must NOT be shader_feature_local – otherwise fade fails?! Na, it just fails. Toggling "Mask Map" may help bringing back the decal.
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _COMBINEDTEXTURE
            #pragma shader_feature_local _DECALNORMAL

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            #pragma shader_feature_local ORTHO_SUPPORT
            #pragma shader_feature_local_fragment HQ_SAMPLING

            #pragma multi_compile_fragment _ NORMALS_SAMPLING
            

            #define _SPECULAR_SETUP 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            
            
            #pragma vertex vert
            #pragma fragment frag

            // Lighting include is needed because of GI
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4   _Color;
                half    _Smoothness;
                half3   _SpecColor;
                float2  _DistanceFade;
                half    _BumpScale;
                half3   _EmissionColor;
                half    _Occlusion;
                half    _DecalNormalStrength;

                float4  _BaseMap_TexelSize;
            CBUFFER_END
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            
            #if defined(SHADER_API_GLES)
                TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            #else
                TEXTURE2D_X_FLOAT(_CameraDepthTexture); //SAMPLER(sampler_CameraDepthTexture);
            #endif
            float4 _CameraDepthTexture_TexelSize;
            #if defined(_COMBINEDTEXTURE)
                TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
            #endif
			#if defined(NORMALS_SAMPLING)
				TEXTURE2D_X_FLOAT(_CameraNormalsTexture);
			#endif

            struct VertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO

                float4 viewRayOS : TEXCOORD0;
                float3 camPosOS : TEXCOORD1;
                float4 screenUV : TEXCOORD2;

                float fogCoord : TEXCOORD3;

                #if defined(_NORMALMAP) || defined(_DECALNORMAL)
                    half3 normalWS              : TEXCOORD4;
                #endif
                
                #if defined(_NORMALMAP)
                    half3 tangentWS             : TEXCOORD5;    
                    half3 bitangentWS           : TEXCOORD6;
                #endif

                half fade : TEXCOORD7;
            };

            VertexOutput vert (VertexInput v)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(v.vertex.xyz);

            //  We do all calculations in Object Space
                float4 positionVS = mul(UNITY_MATRIX_V, mul(UNITY_MATRIX_M, v.vertex));
                float3 viewRayVS = positionVS.xyz;

            //  positionVS.z here acts as view space to object space ratio (negative)
                output.viewRayOS.w = positionVS.z;
            //  NOTE: Fix direction of the viewRay
                float4x4 ViewToObjectMatrix = mul(GetWorldToObjectMatrix(), UNITY_MATRIX_I_V);
                output.viewRayOS.xyz = mul((float3x3)ViewToObjectMatrix, -viewRayVS).xyz;

                output.camPosOS = ViewToObjectMatrix._m03_m13_m23;                

            //  Get the screen uvs needed to sample the depth texture
                output.screenUV = ComputeScreenPos(output.positionCS);

                output.fogCoord = ComputeFogFactor(output.positionCS.z);

            //  Set distance fade value
                float3 worldInstancePos = UNITY_MATRIX_M._m03_m13_m23;
                float3 diff = (_WorldSpaceCameraPos - worldInstancePos);
                float dist = dot(diff, diff);
                output.fade = saturate( (_DistanceFade.x - dist) * _DistanceFade.y );
            //  Clip
                if(output.fade == 0) {
                    output.positionCS /= output.fade;
                }

                #if defined(_NORMALMAP) || defined(_DECALNORMAL)
                    output.normalWS = TransformObjectToWorldNormal(half3(0.0h, 1.0h, 0.0h));
                #endif

                #if defined(_NORMALMAP)
                    output.tangentWS = TransformObjectToWorldDir(half3(1.0h, 0.0h, 0.0h));
                    half tangentSign = (-1.0h) * unity_WorldTransformParams.w;
                    output.bitangentWS = cross(output.normalWS, output.tangentWS) * tangentSign;
                #endif
                
                return output;
            }

        //  https://www.gamedev.net/forums/topic/678043-how-to-blend-world-space-normals/
        //  same as in: ScriptableRenderPipeline/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl
            
            half3 ReorientNormalInWorldSpace(in half3 u, in half3 t, in half3 s) {
            //  Build the shortest-arc quaternion
                half dotSTplusOne = dot(s, t) + 1.0h;
                half4 q = half4(cross(s, t), dotSTplusOne ) / sqrt(2.0h * ( dotSTplusOne ));
            //  Rotate the normal
                return u * (q.w * q.w - dot(q.xyz, q.xyz)) + 2.0h * q.xyz * dot(q.xyz, u) + 2.0h * q.w * cross(q.xyz, u);
            }

            #define oneMinusDielectricSpecConst half(1.0 - 0.04)


        //  HQ decal sampling from: http://www.humus.name/index.php?page=3D&ID=84
        //  Decal MipmapLevel to avoid the 2x2 pixels artefacts on the edges where the decal is projected to.
            //float2 ComputeDecalDDX(VertexOutput input, float2 uv, float2 decalUV) {

            void ComputeDecalDDX(VertexOutput input, float2 uv, float2 decalUV, out float2 uvDiff, out float2 depths) {
                float2 ScreenDeltaX = float2(1, 0);
                float depth0 = LOAD_TEXTURE2D_X(_CameraDepthTexture, _ScaledScreenParams.xy * uv - ScreenDeltaX).x;
                depth0 = LinearEyeDepth(depth0, _ZBufferParams);
                float depth1 = LOAD_TEXTURE2D_X(_CameraDepthTexture, _ScaledScreenParams.xy * uv + ScreenDeltaX).x;
                depth1 = LinearEyeDepth(depth1, _ZBufferParams);

                float2 UvDiffX0 = decalUV - ((input.camPosOS + input.viewRayOS.xyz * depth0).xz + float2(0.5, 0.5));
                float2 UvDiffX1 = ((input.camPosOS + input.viewRayOS.xyz * depth1).xz + float2(0.5, 0.5)) - decalUV;
                
                //return dot(UvDiffX0, UvDiffX0) < dot(UvDiffX1, UvDiffX1) ? UvDiffX0 : UvDiffX1;
                uvDiff = dot(UvDiffX0, UvDiffX0) < dot(UvDiffX1, UvDiffX1) ? UvDiffX0 : UvDiffX1;
                depths = float2(depth0, depth1);
            }
            //float2 ComputeDecalDDY(VertexOutput input, float2 uv, float2 decalUV) {
            void ComputeDecalDDY(VertexOutput input, float2 uv, float2 decalUV, out float2 uvDiff, out float2 depths) {
                float2 ScreenDeltaY = float2(0, 1);
                float depth0 = LOAD_TEXTURE2D_X(_CameraDepthTexture, _ScaledScreenParams.xy * uv - ScreenDeltaY).x;
                depth0 = LinearEyeDepth(depth0, _ZBufferParams);
                float depth1 = LOAD_TEXTURE2D_X(_CameraDepthTexture, _ScaledScreenParams.xy * uv + ScreenDeltaY).x;
                depth1 = LinearEyeDepth(depth1, _ZBufferParams);

                float2 UvDiffY0 = decalUV - ((input.camPosOS + input.viewRayOS.xyz * depth0).xz + float2(0.5, 0.5));
                float2 UvDiffY1 = ((input.camPosOS + input.viewRayOS.xyz * depth1).xz + float2(0.5, 0.5)) - decalUV;
                
                //return dot(UvDiffY0, UvDiffY0) < dot(UvDiffY1, UvDiffY1) ? UvDiffY0 : UvDiffY1;
                uvDiff = dot(UvDiffY0, UvDiffY0) < dot(UvDiffY1, UvDiffY1) ? UvDiffY0 : UvDiffY1;
                depths = float2(depth0, depth1);
            }
        //  HQ decal sampling END


            half4 frag (VertexOutput input ) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                input.viewRayOS.xyz *= rcp(input.viewRayOS.w); // precision problem? calculating 1.0 / w in vertex shader.

                float2 uv = input.screenUV.xy / input.screenUV.w;
            //  Fix screenUV for Single Pass Stereo Rendering
                #if defined(UNITY_SINGLE_PASS_STEREO)
                    uv.x = uv.x * 0.5f + (float)unity_StereoEyeIndex * 0.5f;
                #endif

                #if defined(SHADER_API_GLES)
                    float rawDepth = SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, uv, 0);
                #else
                    float rawDepth = LOAD_TEXTURE2D_X(_CameraDepthTexture, uint2(_ScaledScreenParams.xy * uv )).x;
                    //float2 sampleCoords = (floor(uv * _ScaledScreenParams.xy) + 0.5) / _ScaledScreenParams.xy;
                    //float rawDepth = LOAD_TEXTURE2D_X(_CameraDepthTexture, uint2(_ScaledScreenParams.xy * sampleCoords )).x;
                #endif

                float3 positionOS;
                float3 positionWS;

            //  Get Position in Object Space
                #if defined(ORTHO_SUPPORT)
                    UNITY_BRANCH
                    if(unity_OrthoParams.w == 1) {
                        float depthOrtho = rawDepth;
                        #if defined(UNITY_REVERSED_Z)
                        //  Needed to handle openGL
                            #if UNITY_REVERSED_Z == 1
                                depthOrtho = 1.0f - depthOrtho;
                            #endif
                        #endif
                        
                    //  Get ortho Depth
                    //  Old code, works with HDRP10.1 again... crazy
                        depthOrtho = lerp(_ProjectionParams.y, _ProjectionParams.z, depthOrtho);
                        float2 rayOrtho = -float2( unity_OrthoParams.xy * ( input.screenUV.xy - 0.5) * 2 /* to clip space */);
                        float4 vposOrtho = float4(rayOrtho, -depthOrtho, 1);
                        float3 wposOrtho = mul(unity_CameraToWorld, vposOrtho).xyz;
                        wposOrtho -= _WorldSpaceCameraPos * 2; // TODO: Why * 2 ????
                        wposOrtho *= -1;
                        float3 positionOrthoOS = mul( GetWorldToObjectMatrix(), float4(wposOrtho, 1)).xyz;
                        
                        // depthOrtho = lerp(_ProjectionParams.y, _ProjectionParams.z, depthOrtho);
                        // float2 rayOrtho = float2( unity_OrthoParams.xy * ( input.screenUV.xy - 0.5) * 2 /* to clip space */);
                        // float4 vposOrtho = float4(rayOrtho, -depthOrtho, 1);
                        // float3 wposOrtho = mul(unity_CameraToWorld, vposOrtho).xyz;
                        // float3 positionOrthoOS = mul( GetWorldToObjectMatrix(), float4(wposOrtho, 1)).xyz;
                        
                        positionOS = positionOrthoOS;
                        positionWS = wposOrtho;
                    }
                    else {
                    //  Get perspective Depth
                        float depth = LinearEyeDepth(rawDepth, _ZBufferParams);
                    //  Position in Object Space
                        positionOS = input.camPosOS + input.viewRayOS.xyz * depth;
                        positionWS = mul(GetObjectToWorldMatrix(), float4(positionOS, 1)).xyz; 
                    }
                #else
                //  Get perspective Depth
                    float depth = LinearEyeDepth(rawDepth, _ZBufferParams);
                //  Position in Object Space
                    positionOS = input.camPosOS + input.viewRayOS.xyz * depth;
                    positionWS = mul(GetObjectToWorldMatrix(), float4(positionOS, 1)).xyz; 
                #endif

            //  Clip decal to volume
                clip(float3(0.5, 0.5, 0.5) - abs(positionOS.xyz));

                float2 texUV = positionOS.xz + float2(0.5, 0.5);

            //  HQ Decal Sampling
                #if defined(HQ_SAMPLING) && !defined(ORTHO_SUPPORT)
                    float2 UvPixelDiffX;
                    float2 UvPixelDiffY;
                    float2 depthX;
                    float2 depthY;
                    ComputeDecalDDX(input, uv, texUV, UvPixelDiffX, depthX);
                    ComputeDecalDDY(input, uv, texUV, UvPixelDiffY, depthY);
                    UvPixelDiffX *= _BaseMap_TexelSize.zw;
                    UvPixelDiffY *= _BaseMap_TexelSize.zw;

                    float MaxDiff = max(dot(UvPixelDiffX, UvPixelDiffX), dot(UvPixelDiffY, UvPixelDiffY));
                    float Mip = 0.5 * log2(MaxDiff);
                    half4 col = SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_BaseMap, texUV, Mip) * _Color;
                #else
                    half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, texUV) * _Color;
                #endif

            //  Distance Fade
                #if defined(ORTHO_SUPPORT)
                    half alpha = col.a * ((unity_OrthoParams.w == 1.0h) ? 1.0h : input.fade);
                #else
                    half alpha = col.a * input.fade;
                #endif

                #if defined(_COMBINEDTEXTURE)
                    #if defined(HQ_SAMPLING) && !defined(ORTHO_SUPPORT)
                        half4 combinedTextureSample = SAMPLE_TEXTURE2D_LOD(_MaskMap, sampler_MaskMap, texUV, Mip);
                    #else
                        half4 combinedTextureSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, texUV);
                    #endif
                    half3 specular = lerp(_SpecColor, col.rgb, combinedTextureSample.rrr);
                //  Remap albedo
                    col.rgb *= oneMinusDielectricSpecConst - combinedTextureSample.rrr * oneMinusDielectricSpecConst;
                    half smoothness = combinedTextureSample.a;
                    half occlusion = lerp(1.0h, combinedTextureSample.g, _Occlusion);
                    half3 emission = _EmissionColor * combinedTextureSample.b;
                #else
                    half3 specular = _SpecColor;
                    half smoothness = _Smoothness;
                    half occlusion = 1.0h;
                    half3 emission = 0;
                #endif

            //  Prepare inputs for the lighting function and get normals

            //	I hate this ZERO initialize - but it is just the quicket way here
                InputData inputData = (InputData)0;
                inputData.positionWS = positionWS;

            //	SSAO
                // #if defined(_SCREEN_SPACE_OCCLUSION)
				// 	inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                // #endif

            //  URP 14: normalizedScreenSpaceUV are needed for GI as well
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

            //	Normals
				#if defined(NORMALS_SAMPLING) && defined(_SCREEN_SPACE_OCCLUSION) 
				//	view space normal!
					//float2 nSample = LOAD_TEXTURE2D_X(_CameraNormalsTexture, _ScaledScreenParams.xy * uv).rg;
					//inputData.normalWS = UnpackNormalOctRectEncode(nSample.rg);
					//inputData.normalWS = mul((float3x3)UNITY_MATRIX_I_V, inputData.normalWS );
                //  URP 12
                    inputData.normalWS = LOAD_TEXTURE2D_X(_CameraNormalsTexture, _ScaledScreenParams.xy * uv).rgb;
				#else
                
	            //  As ddx and ddy may return super small values we have to normalize on platforms where half actually means something 
	                #if REAL_IS_HALF
	                    inputData.normalWS = normalize( cross( ddy(positionWS), ddx(positionWS) ) );
	                #else
	                    #if defined(_DECALNORMAL)
	                //  In case we blend we have to normalize first as well.
	                        inputData.normalWS = normalize( cross( ddy(positionWS), ddx(positionWS) ) );
	                    #else
	                        inputData.normalWS = cross( ddy(positionWS), ddx(positionWS) );
	                    #endif
	                #endif

	                #if defined(_DECALNORMAL)
	                    inputData.normalWS = (lerp(inputData.normalWS, input.normalWS.xyz, _DecalNormalStrength));
	                #endif

                    #if defined(HQ_SAMPLING) && !defined(ORTHO_SUPPORT)
                        //positionOS = input.camPosOS + input.viewRayOS.xyz * depth;
                        //positionWS = mul(GetObjectToWorldMatrix(), float4(positionOS, 1)).xyz;
                        float3 RayWS = mul((float3x3)GetObjectToWorldMatrix(), input.viewRayOS.xyz);
                        //float3 posWS = _WorldSpaceCameraPos + RayWS * min(depthX.x, min(depthX.y, min(depthY.x, depthY.y)));
                        float3 posWS = _WorldSpaceCameraPos + normalize(RayWS) * (depthX.x + depthX.y + depthY.x +depthY.y) / 4;
                        posWS = (posWS + positionWS) / 2;

                        RayWS = normalize(RayWS);

                        float3 p1 = _WorldSpaceCameraPos + RayWS * depthX.x;
                        float3 p2 = _WorldSpaceCameraPos + RayWS * depthX.y;
                        float3 p3 = _WorldSpaceCameraPos + RayWS * depthY.x;
                        float3 p4 = _WorldSpaceCameraPos + RayWS * depthY.y;

                    //  get the difference between the current and each offset position
                        float3 hDeriv = p2 - p1; //positionWS;
                        float3 vDeriv = p4 - p3; //positionWS;

                    //  get view space normal from the cross product of the diffs
                        inputData.normalWS = half3(normalize(cross(vDeriv, hDeriv)));
                        posWS = (p1 + p2 + p3 + p4) / 4; // schlecht!
                        inputData.normalWS = normalize( cross( ddy(posWS), ddx(posWS) ) );
                    #endif                    

				#endif

                #if defined(_NORMALMAP)
                    #if defined(HQ_SAMPLING) && !defined(ORTHO_SUPPORT)
                        half4 normalSample = SAMPLE_TEXTURE2D_LOD(_BumpMap, sampler_BumpMap, texUV, Mip);
                    #else
                        half4 normalSample = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, texUV);
                    #endif

                    #if BUMP_SCALE_NOT_SUPPORTED
                        half3 normalTS = UnpackNormal(normalSample);
                    #else
                        half3 normalTS = UnpackNormalScale(normalSample, _BumpScale);
                    #endif
                    half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
                    inputData.normalWS = ReorientNormalInWorldSpace(inputData.normalWS, normalWS, input.normalWS.xyz);
                #endif
                    
                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(positionWS);

                #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                    inputData.shadowCoord = input.screenUV;
                #else
                    inputData.shadowCoord = TransformWorldToShadowCoord(positionWS);
                #endif

                inputData.fogCoord = 0;
             // We can't calculate per vertex lighting
                inputData.vertexLighting = 0;
            //  So we have to sample SH fully per pixel
                inputData.bakedGI = SampleSH(inputData.normalWS);

                // col = UniversalFragmentPBR(
                //     inputData, 
                //     col.rgb, 
                //     0, //surfaceData.metallic, 
                //     specular, 
                //     smoothness,
                //     occlusion,
                //     emission,
                //     alpha);

            //  URP 14: We have to use latest lighting here to make glossienvironmentreflections work properly.
                
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = col.rgb;
                surfaceData.metallic = 0;
                surfaceData.specular = specular;
                surfaceData.smoothness = smoothness;
                surfaceData.occlusion = occlusion;
                surfaceData.emission = emission;
                surfaceData.alpha = alpha;
                
                col = UniversalFragmentPBR(inputData, surfaceData);

                col.rgb = MixFog(col.rgb, input.fogCoord);

                return half4(col.rgb, alpha);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
    CustomEditor "LuxURPUniversalCustomShaderGUI"
}