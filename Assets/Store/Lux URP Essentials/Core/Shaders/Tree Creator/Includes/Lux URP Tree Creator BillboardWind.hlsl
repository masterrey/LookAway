#ifndef LUXURP_BILLBOARDLIBRARY_INCLUDED
#define LUXURP_BILLBOARDLIBRARY_INCLUDED



float4 SmoothCurve( float4 x ) {
    return x * x *( 3.0 - 2.0 * x );
}
float4 TriangleWave( float4 x ) {
    return abs( frac( x + 0.5 ) * 2.0 - 1.0 );
}
float4 SmoothTriangleWave( float4 x ) {
    return SmoothCurve( TriangleWave( x ) );
}

half2 SmoothCurve( half2 x ) {   
    return x * x *( 3.0h - 2.0h * x );   
}
half2 TriangleWave( half2 x ) {   
    return abs( frac( x + 0.5h ) * 2.0h - 1.0h );   
}
half2 SmoothTriangleWave( half2 x ) {   
    return SmoothCurve( TriangleWave( x ) );   
}

half SmoothCurve( half x ) {   
    return x * x *( 3.0h - 2.0h * x );   
}
half TriangleWave( half x ) {   
    return abs( frac( x + 0.5h ) * 2.0h - 1.0h );   
}
half SmoothTriangleWave( half x ) {   
    return SmoothCurve( TriangleWave( x ) );   
}

float4 _LuxURPWindDirSize;
float4 _LuxURPWindStrengthTurbulencePulsemagnitudePulseFrequency;

// Billboard bending
void AnimateBillboard_float(
    float3 positionOS,
    float  bendPower,
    float  bendStrength,
    
    out float3 positionOS_o
)
{

    float mainWindAnim = 1;
//  Fade in Wind
    float4 wind;
    wind.xyz = TransformWorldToObjectDir(_LuxURPWindDirSize.xyz);
//  In case we have no Wind Prefab foliage will vanish otherwise.
    wind.xyz = clamp(wind.xyz, -1, 1);
    wind.xyz *= _LuxURPWindStrengthTurbulencePulsemagnitudePulseFrequency.x;
    wind.w = _LuxURPWindStrengthTurbulencePulsemagnitudePulseFrequency.y;

//  Animate incoming wind
    float3 objectWorldPos = UNITY_MATRIX_M._m03_m13_m23;
    float3 absObjectWorldPos = abs(objectWorldPos.xyz * 0.125h);
    half sinuswave = _LuxURPWindStrengthTurbulencePulsemagnitudePulseFrequency.w;
    half2 vOscillations = SmoothTriangleWave( half2(absObjectWorldPos.x + sinuswave, absObjectWorldPos.z + sinuswave * 0.7h) );
//  To make it better match we simplify the calculation
    float fOsc = (vOscillations.x + vOscillations.y) * 0.5;
    mainWindAnim += fOsc * _LuxURPWindStrengthTurbulencePulsemagnitudePulseFrequency.z;


//  Primary bending
    float origLength = length(positionOS);

//  Make sure we have a positive value here 
    float bending = pow( abs(positionOS.y) * bendStrength, bendPower) ;
    positionOS.xyz += bending * wind.xyz * mainWindAnim;
    positionOS = normalize(positionOS) * origLength;
    positionOS_o = positionOS;
}

#endif