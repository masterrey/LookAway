using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace LuxURPEssentials
{
    [ExecuteAlways]
    public class LuxURP_SetupGlobals : MonoBehaviour
    {
        
        public Texture2D _BestFittingNormal;

        void SetupGlobals() {
            if (_BestFittingNormal != null) {
                Shader.SetGlobalTexture("_BestFittingNormal", _BestFittingNormal);    
            }
        }

        void OnEnable()
        {
            SetupGlobals();   
        }

        void OnValidate()
        {
            SetupGlobals();    
        }
    }
}