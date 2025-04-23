#if !defined(LUXCOPYINPUTDATA)
    #define(LUXCOPYINPUTDATA)

    InputData LuxCopyInputData(InputData inputData)
    {
        
        InputData o_inputData = (InputData)0;

        o_inputData.positionWS = inputData.positionWS;
        o_inputData.positionCS = inputData.positionCS;
        o_inputData.normalWS = inputData.normalWS;
        o_inputData.viewDirectionWS = inputData.viewDirectionWS;
        o_inputData.shadowCoord = inputData.shadowCoord;
        o_inputData.fogCoord = inputData.fogCoord;
        o_inputData.vertexLighting = inputData.vertexLighting; 
        o_inputData.bakedGI = inputData.bakedGI;
        o_inputData.normalizedScreenSpaceUV = inputData.normalizedScreenSpaceUV;
        o_inputData.shadowMask = inputData.shadowMask;
        // o_inputData.tangentToWorld = inputData.tangentToWorld;
        // #if defined(DEBUG_DISPLAY)
        //     o_inputData.dynamicLightmapUV = inputData.dynamicLightmapUV;
        //     o_inputData.staticLightmapUV = inputData.staticLightmapUV;
        //     o_inputData.vertexSH = inputData.vertexSH;
        //     o_inputData.brdfDiffuse = inputData.brdfDiffuse;
        //     o_inputData.brdfSpecular = inputData.brdfSpecular;
        //     o_inputData.uv = inputData.uv;
        //     o_inputData.mipCount = inputData.mipCount;
        //     o_inputData.texelSize = inputData.texelSize;
        //     o_inputData.mipInfo = inputData.mipInfo;
        //     o_inputData.streamInfo = inputData.streamInfo;
        //     o_inputData.originalColor = inputData.originalColor;
        // #endif

        return o_inputData;
    }

#endif