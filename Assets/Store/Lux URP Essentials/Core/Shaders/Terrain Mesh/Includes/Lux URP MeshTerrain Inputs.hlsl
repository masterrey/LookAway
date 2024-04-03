#ifndef INPUT_LUXURP_BASE_INCLUDED
#define INPUT_LUXURP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)
        float2  _SplatTiling;
        half4   _SpecColor;
        half    _Occlusion;
        float   _TopDownTiling;
    //  Needed by Meta Pass
        half    _ApplyTopDownProjection;

        //float4  _BaseMap_ST;
        //half4   _BaseColor;
        //half    _Cutoff;
    CBUFFER_END

//  Additional textures
    TEXTURE2D(_DetailA0); SAMPLER(sampler_DetailA0);
    TEXTURE2D(_Normal0); SAMPLER(sampler_Normal0);
    TEXTURE2D(_DetailA1);
    TEXTURE2D(_Normal1);
    TEXTURE2D(_DetailA2);
    TEXTURE2D(_Normal2);
    TEXTURE2D(_DetailA3);
    TEXTURE2D(_Normal3);
    TEXTURE2D(_SplatMap); SAMPLER(sampler_SplatMap);

//  Global Inputs



#endif