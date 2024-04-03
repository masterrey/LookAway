#ifndef INPUT_BASE_INCLUDED
    #define INPUT_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"


    CBUFFER_START(UnityPerMaterial)
            
        float4 _BaseMap_ST;
        half4 _BaseColor;
        half _Cutoff;
        
        half4 _SpecColor;
        half _Smoothness;
        half _BumpScale;

        half _Shrink;
        half _ShadowOffset;
    CBUFFER_END

//  DOTS - we only define a minimal set here. The user might extend it to whatever is needed.
    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
            UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
        
        #define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)
    #endif

#endif