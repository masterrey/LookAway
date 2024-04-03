using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace LuxURPEssentials
{

    [System.Serializable]
    public enum ToneMappingModes {
        Custom = 0,
        ACES = 1
    }
    
    [ExecuteAlways]
    public class LuxURP_Tonemapping : MonoBehaviour
    {
    //  using order to fix header/button issue
        [Space(5)]
        [LuxURP_HelpBtn("h.zdqgjigbf0e4")]
        [Space(3)]


        [Space(8)]
        public bool _enableTonemapping = false;

        [Space(8)]
        public ToneMappingModes _mode = ToneMappingModes.Custom;

        [Header("Custom Tonemapping")]

        [Space(8)]
        public bool _enableNeutral = false;

        [Space(4)]
        [Range(-1.0f, 1.0f)]
        public float _gamma = 0.0f;
        [Range(-1.0f, 1.0f)]
        public float _contrast = 0.0f;
        [Range(-1.0f, 1.0f)]
        public float _hue = 0.0f;
        [Range(-1.0f, 1.0f)]
        public float _saturation = 0.0f;
        public Color _filter = Color.white;

        private static readonly int _LuxURP_EnableTonemapping = Shader.PropertyToID("_LuxURP_EnableTonemapping");
        private static readonly int _LuxURP_ToneMappingMode = Shader.PropertyToID("_LuxURP_ToneMappingMode");
        private static readonly int _LuxURP_EnableNeutral = Shader.PropertyToID("_LuxURP_EnableNeutral");
        private static readonly int _LuxURP_Gamma = Shader.PropertyToID("_LuxURP_Gamma");
        private static readonly int _LuxURP_Contrast = Shader.PropertyToID("_LuxURP_Contrast");
        private static readonly int _LuxURP_Saturation = Shader.PropertyToID("_LuxURP_Saturation");
        private static readonly int _LuxURP_Hue = Shader.PropertyToID("_LuxURP_Hue");
        private static readonly int _LuxURP_Filter = Shader.PropertyToID("_LuxURP_Filter");

        void OnEnable()
        {
            UpdateSettings();  
        }

        void OnDisable()
        {
            Shader.SetGlobalFloat(_LuxURP_EnableTonemapping, 0.0f);
        }

        void OnValidate()
        {
           UpdateSettings(); 
        }

        void UpdateSettings()
        {
            Shader.SetGlobalFloat(_LuxURP_EnableTonemapping, _enableTonemapping ? 1.0f : 0.0f);
            Shader.SetGlobalFloat(_LuxURP_ToneMappingMode, (int)_mode);
            Shader.SetGlobalFloat(_LuxURP_EnableNeutral, _enableNeutral ? 1.0f : 0.0f);
            Shader.SetGlobalFloat(_LuxURP_Gamma, 1.0f + _gamma);
            Shader.SetGlobalFloat(_LuxURP_Contrast, 1.0f + _contrast);
            Shader.SetGlobalFloat(_LuxURP_Saturation, _saturation);
            Shader.SetGlobalFloat(_LuxURP_Hue, _hue * 0.5f);
            Shader.SetGlobalColor(_LuxURP_Filter, _filter);
        }
    }
}