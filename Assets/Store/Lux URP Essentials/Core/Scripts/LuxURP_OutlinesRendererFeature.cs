using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace LuxURPEssentials
{
    
    [System.Serializable]
    public enum InjectionPoints {
        _AfterRenderingOpaques = RenderPassEvent.AfterRenderingOpaques,
        _BeforeRenderingTransparents = RenderPassEvent.BeforeRenderingTransparents,
        _AfterRenderingTransparents = RenderPassEvent.AfterRenderingTransparents
    }

    public class LuxURP_OutlinesRendererFeature : ScriptableRendererFeature
    {
        
        public LayerMask _layerMask = -1;
        public InjectionPoints _injectionPoint = InjectionPoints._AfterRenderingTransparents;

        private UnityEngine.Rendering.Universal.RenderObjects _renderObjectsFeature;
        private const string _shaderPassName = "LuxOutline";
        private const string _profilerTag = "Lux Outline RendererFeature";
        

        public override void Create()
        {
            name = "Lux URP Outlines";
            _renderObjectsFeature = ScriptableObject.CreateInstance<UnityEngine.Rendering.Universal.RenderObjects>();
            _renderObjectsFeature.settings.passTag = _profilerTag;
            _renderObjectsFeature.settings.filterSettings.LayerMask = _layerMask;
            _renderObjectsFeature.settings.filterSettings.PassNames = new string[1] { _shaderPassName };
            _renderObjectsFeature.settings.filterSettings.LayerMask = _layerMask;
            _renderObjectsFeature.settings.Event = (RenderPassEvent)_injectionPoint; //RenderPassEvent.AfterRenderingTransparents; //.BeforeRenderingTransparents; // Neither is really good... 

            _renderObjectsFeature.Create();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            //_renderObjectsFeature.settings.filterSettings.LayerMask = _layerMask;
            _renderObjectsFeature.AddRenderPasses(renderer, ref renderingData);
        }
    }
}