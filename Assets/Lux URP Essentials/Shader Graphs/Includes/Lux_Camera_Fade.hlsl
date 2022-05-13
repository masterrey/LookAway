float Dither32(float2 Pos) {
    float Ret = dot( float3(Pos.xy, 0.5f), float3(0.40625f, 0.15625f, 0.46875f ) );
    return frac(Ret);
}

void CameraFade_float(
//  Base inputs
    float4 positionSP,
    float3 positionWS,
    float  CameraInversFadeRange,
    float  CameraFadeDist,
    float  AlphaIN,

    out real Alpha

) {
	#if !defined(SHADERPASS_SHADOWCASTER)
    	Alpha = AlphaIN * saturate( (positionSP.w - CameraFadeDist) * CameraInversFadeRange - Dither32(positionSP.xy / positionSP.w * _ScreenParams.xy ) );
    #else
    	#if defined(FADESHADOWS_ON)
    		float distanceToCam = distance(positionWS, GetCameraPositionWS() );
    		Alpha = AlphaIN * saturate( (distanceToCam - CameraFadeDist) * CameraInversFadeRange - Dither32(positionSP.xy / positionSP.w * _ScreenParams.xy ) );
    	#else
    		Alpha = AlphaIN;
    	#endif
    #endif
}