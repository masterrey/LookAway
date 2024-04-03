Shader "Lux SRP Displacement/Simple Displacement Trail"
{
    Properties
    {
        _MainTex ("Displacement Source Texture", 2D) = "bump" {}
        [Toggle(_DYNAMICALPHA)]
        _DynamicAlpha               ("Dynamic Alpha", Float) = 0
        _Alpha                      ("    Alpha", Range(0,1)) = 1
        [Toggle(_NORMAL)]
        _RotateNormal               ("Rotate Normal", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend Mode", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend Mode", Float) = 10
    }
    SubShader
    {
        Tags {
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        ZWrite Off
        Blend [_SrcBlend] [_DstBlend]
        LOD 100

        Pass
        {
            Name "LuxGrassDisplacementFX"
            Tags{"LightMode" = "LuxGrassDisplacementFX"}
            
            
            HLSLPROGRAM
            #pragma target 2.0
            
            #pragma vertex SimpleDisplacementFXVertex
            #pragma fragment SimpleDisplacementFXFragment

            #pragma shader_feature_local _DYNAMICALPHA
            #pragma shader_feature_local _NORMAL

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct VertexInput
            {
                float3 positionOS       : POSITION;
                half4 color             : COLOR;
                float2 uv               : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1; 
                half4 color : TEXCOORD2;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            CBUFFER_START(UnityPerMaterial)
                //half _Alpha;
            CBUFFER_END

            #if defined (_DYNAMICALPHA)
                UNITY_INSTANCING_BUFFER_START(Props)
                    UNITY_DEFINE_INSTANCED_PROP(half, _Alpha)
                UNITY_INSTANCING_BUFFER_END(Props)
            #endif
            
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            
            VertexOutput SimpleDisplacementFXVertex (VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                
                VertexPositionInputs vertexPosition = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexPosition.positionCS;
                output.uv = input.uv;
                output.color = input.color;
                output.positionWS = vertexPosition.positionWS;

                return output;
            }

            float3x3 cotangent_frame(float3 normal, float3 position, float2 uv)
            {
                // get edge vectors of the pixel triangle
                float3 dp1 = ddx( position );
                float3 dp2 = ddy( position ) * _ProjectionParams.x;
                float2 duv1 = ddx( uv );
                float2 duv2 = ddy( uv ) * _ProjectionParams.x;
                // solve the linear system
                float3 dp2perp = cross( dp2, normal );
                float3 dp1perp = cross( normal, dp1 );
                float3 T = dp2perp * duv1.x + dp1perp * duv2.x;
                float3 B = dp2perp * duv1.y + dp1perp * duv2.y;
                // construct a scale-invariant frame
                float invmax = rsqrt( max( dot(T,T), dot(B,B) ) );
                // matrix is transposed, use mul(VECTOR, MATRIX)
                return float3x3( T * invmax, B * invmax, normal );
            }

            half4 SimpleDisplacementFXFragment (VertexOutput input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                col.a *= input.color.a
                #if defined(_DYNAMICALPHA)
                    * UNITY_ACCESS_INSTANCED_PROP(Props, _Alpha)
                #endif
                ;

                col.rgb = col.rgb * 2 - 1; // unpack normalTS
            //  Create TBN rotation. Trails neither have normals nor tangents. So we reconstruct them.
                float3x3 tbn = cotangent_frame(float3(0, 1, 0), input.positionWS, input.uv);
                col.rgb = mul(col.rgb, tbn);
            //  Swizzle to "tangent space" and repack
                col.rgb = col.rbg * 0.5 + 0.5;
                
                return col;
            }
            ENDHLSL
        }
    }
}