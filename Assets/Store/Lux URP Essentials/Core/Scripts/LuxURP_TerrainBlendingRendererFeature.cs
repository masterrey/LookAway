using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace LuxURPEssentials
{
    public class LuxURP_TerrainBlendingRendererFeature : ScriptableRendererFeature
    {
        
        public LayerMask _layerMask = -1;

        private UnityEngine.Rendering.Universal.RenderObjects _renderObjectsFeature;
        private const string _shaderPassName = "LuxTerrainBlending";
        private const string _profilerTag = "Lux TerrainBlending RendererFeature";

        public override void Create()
        {
            name = "Lux URP TerrainBlending";
            _renderObjectsFeature = ScriptableObject.CreateInstance<UnityEngine.Rendering.Universal.RenderObjects>();
            _renderObjectsFeature.settings.passTag = _profilerTag;
            _renderObjectsFeature.settings.filterSettings.LayerMask = _layerMask;
            _renderObjectsFeature.settings.filterSettings.PassNames = new string[1] { _shaderPassName };
            _renderObjectsFeature.settings.filterSettings.LayerMask = _layerMask;
            _renderObjectsFeature.settings.Event = RenderPassEvent.AfterRenderingOpaques;

            _renderObjectsFeature.Create();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            //_renderObjectsFeature.settings.filterSettings.LayerMask = _layerMask;
            _renderObjectsFeature.AddRenderPasses(renderer, ref renderingData);
        }
    }
}