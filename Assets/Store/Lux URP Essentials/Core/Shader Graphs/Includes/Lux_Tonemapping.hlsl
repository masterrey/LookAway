float _LuxURP_EnableTonemapping;
float _LuxURP_ToneMappingMode;
float _LuxURP_EnableNeutral;
float _LuxURP_Gamma;
float _LuxURP_Contrast;
float _LuxURP_Saturation;
float _LuxURP_Hue;
float3 _LuxURP_Filter;

void Tonemapping_half(

//  Base inputs
    half3   FinalLighting,

    bool    EnableACES,
    bool    EnableNeutral,
    half    Gamma,
    half    Contrast,
    half    Saturation,
    half    Hue,
    half3   Filter,

    out half3 FinalLighting_o
)
{

    FinalLighting_o = FinalLighting;

    #if defined(_LOCALTONEMAPPING)
        
        if(EnableACES)
        {
            half3 aces = unity_to_ACES(FinalLighting);
            FinalLighting_o = AcesTonemap(aces);
        }
        else 
        {
            if(EnableNeutral)
            {
                FinalLighting = NeutralTonemap(FinalLighting);   
            }
            float3 HSV = RgbToHsv(FinalLighting);
            HSV.x = frac(HSV.x + Hue * 0.5h);
            HSV.y *= (1.0h + Saturation);
            HSV.z = pow(HSV.z, 1.0h + Gamma) * (1.0h + Contrast);
            FinalLighting_o = HsvToRgb(HSV) * Filter;    
        }
    
    #else

    //  Expects linear color space
        if(_LuxURP_EnableTonemapping)
        {
            
            // _LuxURP_ToneMappingMode: 1 = ACES, 0 = Custom

            if(_LuxURP_ToneMappingMode)
            {
                half3 aces = unity_to_ACES(FinalLighting);
                FinalLighting_o = AcesTonemap(aces);
            }
            else
            {
                if(_LuxURP_EnableNeutral)
                {
                    FinalLighting = NeutralTonemap(FinalLighting);   
                }
                half3 HSV = RgbToHsv(FinalLighting);
                HSV.x = frac(HSV.x + _LuxURP_Hue);
                HSV.y *= (1.0 + _LuxURP_Saturation);
                HSV.z = pow(HSV.z, _LuxURP_Gamma) * _LuxURP_Contrast;
                FinalLighting_o = HsvToRgb(HSV) * _LuxURP_Filter;
            }

        }
    #endif
}