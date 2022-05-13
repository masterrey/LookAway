using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace LuxURPEssentials.Demo {
	public class CheckSettings : MonoBehaviour
	{
	    // Start is called before the first frame update
	    void Start()
	    {
	        UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset urp = GraphicsSettings.renderPipelineAsset as UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset;

	        if (urp.supportsCameraDepthTexture == true) {
	        	Debug.Log("CameraDepthTexture supported.");
	        }
	        else {
	        	Debug.Log("CameraDepthTexture not supported.");
	        }

	        if (urp.supportsCameraOpaqueTexture == true) {
	        	Debug.Log("CameraOpaqueTexture supported.");
	        }
	        else {
	        	Debug.Log("CameraOpaqueTexture not supported.");
	        }

	    }
	}
}