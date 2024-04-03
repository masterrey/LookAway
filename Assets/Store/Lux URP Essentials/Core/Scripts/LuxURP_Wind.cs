using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

#if UNITY_EDITOR
	using UnityEditor;
#endif

namespace LuxURPEssentials
{

	[System.Serializable]
    public enum RTSize {
    	_128 = 128,
        _256 = 256,
        _384 = 384,
        _512 = 512,
        _1024 = 1024
    }

    [System.Serializable]
    public enum RTFormat {
    	ARGB32 = 0,
        ARGBHalf = 1
    }

    [System.Serializable]
    public enum GustMixLayer {
    	Layer_0 = 0,
        Layer_1 = 1,
        Layer_2 = 2
    }

	[ExecuteAlways]
	[RequireComponent(typeof(WindZone))]
	//[HelpURL("https://docs.google.com/document/d/1ck3hmPzKUdewHfwsvmPYwSPCP8azwtpzN7aOLJHvMqE/edit#heading=h.wnnhm4pxp610")]
	public class LuxURP_Wind : MonoBehaviour {
	//	using order to fix header/button issue
		[Space(5)]
		[LuxURP_HelpBtn("h.wnnhm4pxp610")]
		[Space(3)]

		public bool UpdateInEditMode = false;
		
		[Header("Render Texture Settings")]
		[Space(4)]
		[Tooltip("Smaller resoltions will speed up rendering but may result in some quantization regarding the final bending.")]
		public RTSize Resolution = RTSize._256;
		[Tooltip("ARGB32 needs less memory and bandwidth but creates a slightly more quantized results - while ARGBHalf needs more memory and bandwith but gives you smoother results.")]
		public RTFormat Format = RTFormat.ARGB32;
		[Tooltip("Expects an RGBA texture with diffirently scaled noise patterns. If left empty the script will grab the default one.")]
		public Texture WindBaseTex;
		public Shader WindCompositeShader;
		
		[Header("Wind Frequency and Turbulence")]
		[Space(4)]
		[Range(0.1f, 1.0f)]
		[Tooltip("Drives the frequency of the turbulence animation according to the main wind strength.")]
		public float WindToFrequency = 0.25f;
		[Tooltip("Drives the strength of turbulence according to the main wind strength.")]
		public AnimationCurve WindToTurbulence = new AnimationCurve(new Keyframe(0, 1), new Keyframe(5, 1));
		[Range(0.0f, 4.0f)]
		[Tooltip("Scales the final turbulence value used by the shaders.")]
		public float MaxTurbulence = 0.5f;

		[Header("Wind Speed and Size")]
		[Space(4)]
		[Tooltip("Base Wind Speed in km/h at Main = 1 (WindZone).")]
        public float BaseWindSpeed = 15;
        [Tooltip("Size of the Wind RenderTexture in World Space.")]
        public float SizeInWorldSpace = 50;
		[Space(4)]
		[Tooltip("Speed of Layer0 (red channel) relative to the Base Wind Speed.")]
		public float speedLayer0 = 1.0f;
		[Tooltip("Speed of Layer1 (green channel) relative to the Base Wind Speed.")]
		public float speedLayer1 = 1.137f;
		[Tooltip("Speed of Layer3 (blue channel) relative to the Base Wind Speed.")]
		public float speedLayer2 = 1.376f;

		[Header("Noise")]
		[Space(4)]
		[Tooltip("Tiling of the gust layer (alpha channel) relative to Size In WorldSpace.")]
		public int GrassGustTiling = 4;
		[Tooltip("Speed of the gust layer (alpha channel) relative to the Base Wind Speed.")]
		public float GrassGustSpeed = 0.278f;
		[Tooltip("Lets you choose a Wind Layer you want the dedicated Gust sample to be combined with.")]
		public GustMixLayer LayerToMixWith = GustMixLayer.Layer_1; 

		[Header("Wind Multipliers")]
		[Space(4)]
		public float Grass = 1.0f;
		public float Foliage = 1.0f;
		public float Trees = 1.0f;

		private RenderTexture WindRenderTexture;
		private Material m_material;

		private Vector2 uvs = new Vector2(0,0);
		private Vector2 uvs1 = new Vector2(0,0);
		private Vector2 uvs2 = new Vector2(0,0);
		private Vector2 uvs3 = new Vector2(0,0);

		private Transform trans;
		private WindZone windZone;
		private float mainWind;
		//private float turbulence;

		private static readonly int WindRTPID = Shader.PropertyToID("_LuxURPWindRT");

		private static readonly int LuxURPWindDirSizePID = Shader.PropertyToID("_LuxURPWindDirSize");
		private static readonly int LuxURPWindStrengthMultipliersPID = Shader.PropertyToID("_LuxURPWindStrengthMultipliers");
		private static readonly int LuxURPSinTimePID = Shader.PropertyToID("_LuxURPSinTime");
		private static readonly int LuxURPGustPID = Shader.PropertyToID("_LuxURPGust");
		private static readonly int LuxURPGustMixLayerPID = Shader.PropertyToID("_LuxURPGustMixLayer");

		private static readonly int _LuxURPWindStrengthTurbulencePulsemagnitudePulseFrequency = Shader.PropertyToID("_LuxURPWindStrengthTurbulencePulsemagnitudePulseFrequency");

		private static readonly int LuxURPBendFrequencyPID = Shader.PropertyToID("_LuxURPBendFrequency");

		private static readonly int LuxURPWindUVsPID = Shader.PropertyToID("_LuxURPWindUVs");
		private static readonly int LuxURPWindUVs1PID = Shader.PropertyToID("_LuxURPWindUVs1");
		private static readonly int LuxURPWindUVs2PID = Shader.PropertyToID("_LuxURPWindUVs2");
		private static readonly int LuxURPWindUVs3PID = Shader.PropertyToID("_LuxURPWindUVs3");

		private int previousRTSize;
		private int previousRTFormat;

		private Vector4 WindDirectionSize = Vector4.zero;
		private float WindTurbulence;

		private static Vector3[] MixLayers = new [] { new Vector3(1f,0f,0f), new Vector3(0f,1f,0f), new Vector3(0f,0f,1f)  };

		#if UNITY_EDITOR
			private double lastTimeStamp = 0.0;
		#endif

		private double currentTime = 0.0;
		private double domainTime_Wind = 0.0f;
		private float temp_WindFrequency = 0.25f;
		private float freqSpeed = 0.0125f;

		private float currentWindPulseFrequency = -1.0f;
		private double domainTime_Pulse = 0.0f;
		private double OneOverPi = (double)(1.0f / Mathf.PI);

		void OnEnable () {
			if(WindCompositeShader == null) {
				WindCompositeShader = Shader.Find("Hidden/Lux URP WindComposite");
			}
			if (WindBaseTex == null ) {
				WindBaseTex = Resources.Load("Lux URP default wind base texture") as Texture;
			}
			SetupRT();
			trans = this.transform;
			windZone = trans.GetComponent<WindZone>();

			previousRTSize = (int)Resolution;
			previousRTFormat = (int)Format;

			#if UNITY_EDITOR
				EditorApplication.update += OnEditorUpdate;
			#endif

		//	Init
			currentWindPulseFrequency = windZone.windPulseFrequency;
		}

		void OnDisable () {
			if (WindRenderTexture != null) {
				WindRenderTexture.Release();
				UnityEngine.Object.DestroyImmediate(WindRenderTexture);
				WindRenderTexture = null;
			}
			if (m_material != null) {
				UnityEngine.Object.DestroyImmediate(m_material);
				m_material = null;
			}
			if (WindBaseTex != null) {
				WindBaseTex = null;
			}

			#if UNITY_EDITOR
				EditorApplication.update -= OnEditorUpdate;
			#endif
		}

		#if UNITY_EDITOR
			void OnEditorUpdate() {
				if(!Application.isPlaying && UpdateInEditMode) {
					Update();
				//	Unity 2019.1.10 on macOS using Metal also needs this
					SceneView.RepaintAll(); 
				}
			}
		#endif

		void SetupRT () {
			if (WindRenderTexture == null || m_material == null)
	        {
	        	var rtf = ((int)Format == 0) ? RenderTextureFormat.ARGB32 : RenderTextureFormat.ARGBHalf;
	            WindRenderTexture = new RenderTexture((int)Resolution, (int)Resolution, 0, rtf, RenderTextureReadWrite.Linear );
	            WindRenderTexture.useMipMap = true;
	            WindRenderTexture.wrapMode = TextureWrapMode.Repeat;
	            m_material = new Material(WindCompositeShader);
	        }
		}

		void OnValidate () {
			if(WindCompositeShader == null) {
				WindCompositeShader = Shader.Find("Hidden/Lux URP WindComposite");
			}
			if (WindBaseTex == null ) {
				WindBaseTex = Resources.Load("Default wind base texture") as Texture;
			}
			if ( (previousRTSize != (int)Resolution ) || ( previousRTFormat != (int)Format ) ) {
				var rtf = ((int)Format == 0) ? RenderTextureFormat.ARGB32 : RenderTextureFormat.ARGBHalf;
				WindRenderTexture = new RenderTexture((int)Resolution, (int)Resolution, 0, rtf, RenderTextureReadWrite.Linear );
	            WindRenderTexture.useMipMap = true;
	            WindRenderTexture.wrapMode = TextureWrapMode.Repeat;
			}
		}
		
		void Update () {

		//	Get wind settings from WindZone
			mainWind = windZone.windMain;
			//turbulence = windZone.windTurbulence;
			WindTurbulence = MaxTurbulence * WindToTurbulence.Evaluate(mainWind);
			
			float delta = Time.deltaTime;

			#if UNITY_EDITOR
				if(!Application.isPlaying) {
					delta = (float)(EditorApplication.timeSinceStartup - lastTimeStamp);
					lastTimeStamp = EditorApplication.timeSinceStartup;
				}
			#endif

			currentTime += (double)delta;

		//	Update the custom time
			temp_WindFrequency = Mathf.MoveTowards(temp_WindFrequency, mainWind * WindToFrequency, freqSpeed);
			domainTime_Wind += delta * (1.0f + temp_WindFrequency);
			Shader.SetGlobalFloat(LuxURPBendFrequencyPID, (float)domainTime_Wind);

			WindDirectionSize.x = trans.forward.x;
			WindDirectionSize.y = trans.forward.y;
			WindDirectionSize.z = trans.forward.z;
			WindDirectionSize.w = 1.0f / SizeInWorldSpace;

			var windVec = new Vector2(WindDirectionSize.x, WindDirectionSize.z ) * delta * (BaseWindSpeed * 0.2777f * WindDirectionSize.w); // * mainWind);

			uvs -= windVec * speedLayer0;
			uvs.x = uvs.x - (int)uvs.x;
			uvs.y = uvs.y - (int)uvs.y;

			uvs1 -= windVec * speedLayer1;
			uvs1.x = uvs1.x - (int)uvs1.x;
			uvs1.y = uvs1.y - (int)uvs1.y;

			uvs2 -= windVec * speedLayer2;
			uvs2.x = uvs2.x - (int)uvs2.x;
			uvs2.y = uvs2.y - (int)uvs2.y;

			uvs3 -= windVec * GrassGustSpeed 			* WindTurbulence; //turbulence;
			uvs3.x = uvs3.x - (int)uvs3.x;
			uvs3.y = uvs3.y - (int)uvs3.y;

		//	Set global shader variables for grass and foliage shaders
			Shader.SetGlobalVector(LuxURPWindDirSizePID, WindDirectionSize);

		//	Set global shader variables for tree creator trees (LOD)
			var turbulence = windZone.windTurbulence;
			var windpulseMagnitude = windZone.windPulseMagnitude;
			var windPulseFrequency = windZone.windPulseFrequency;
			//var treecreatorWindStrength = windpulseMagnitude * mainWind * (1.0f + Mathf.Sin(Time.time * windPulseFrequency) + 1.0f + Mathf.Sin(Time.time * windPulseFrequency * 3.0f) ) * 0.5f;
			var treecreatorWindStrength = mainWind * Trees;
			
		//	Gradually tweak t_animatedWindPulseFrequency
			currentWindPulseFrequency = Mathf.MoveTowards(currentWindPulseFrequency, windPulseFrequency, freqSpeed);
			domainTime_Pulse += delta * (1.0f + currentWindPulseFrequency);
			var t_animatedWindPulseFrequency = (float)(domainTime_Pulse * OneOverPi);

			Shader.SetGlobalVector(_LuxURPWindStrengthTurbulencePulsemagnitudePulseFrequency, new Vector4(treecreatorWindStrength, turbulence, windpulseMagnitude, t_animatedWindPulseFrequency) );

			Vector2 tempWindstrengths;
			tempWindstrengths.x = Grass * mainWind;
			tempWindstrengths.y = Foliage * mainWind;
			Shader.SetGlobalVector(LuxURPWindStrengthMultipliersPID, tempWindstrengths );
		
		//	Use clamped turbulence as otherwise wind direction might get "reversed"
			//Shader.SetGlobalVector(LuxURPGustPID, new Vector2(GrassGustTiling, Mathf.Clamp( turbulence + 0.5f, 0.0f, 1.5f))  );	
			Shader.SetGlobalVector(LuxURPGustPID, new Vector2(GrassGustTiling, WindTurbulence) );

		//	Jitter frequncies and strength
			// Shader.SetGlobalVector(LuxURPSinTimePID, new Vector4(
			// 	// (float)Math.Sin(Time.time * JitterFrequency),
			// 	// (float)Math.Sin(Time.time * JitterFrequency * 0.2317f + 2.0f * Mathf.PI),
			// 	// (float)Math.Sin(Time.time * JitterHighFrequency),
			// 	// turbulence * 0.1f
			// 	(float)Math.Sin(currentTime * JitterFrequency),
			// 	(float)Math.Sin(currentTime * JitterFrequency * 0.2317f + 2.0f * Mathf.PI),
			// 	(float)Math.Sin(currentTime * JitterHighFrequency),
			// 	turbulence * 0.1f
			// ));
		

		//	Set UVs
			Shader.SetGlobalVector(LuxURPWindUVsPID, uvs);
			Shader.SetGlobalVector(LuxURPWindUVs1PID, uvs1);
			Shader.SetGlobalVector(LuxURPWindUVs2PID, uvs2);
			Shader.SetGlobalVector(LuxURPWindUVs3PID, uvs3);

		//	Set Mix Layer
			Shader.SetGlobalVector(LuxURPGustMixLayerPID, MixLayers[(int)LayerToMixWith]);

		#if UNITY_EDITOR
			if (m_material != null && WindRenderTexture != null ) {
		#endif
				Graphics.Blit(WindBaseTex, WindRenderTexture, m_material);
				WindRenderTexture.SetGlobalShaderProperty("_LuxURPWindRT"); // only accepts strings...
		#if UNITY_EDITOR
			}
		#endif
			
		}
	}
}