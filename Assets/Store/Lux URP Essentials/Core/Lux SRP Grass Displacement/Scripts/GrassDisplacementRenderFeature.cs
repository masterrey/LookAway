// https://forum.unity.com/threads/introduction-of-render-graph-in-the-universal-render-pipeline-urp.1500833/
// https://drive.google.com/file/d/16oaLyv2Rjwqhql7-0fbmgHT5LQ_c7Su1/view


using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace Lux_SRP_GrassDisplacement
{
    public class GrassDisplacementRenderFeature : ScriptableRendererFeature
    {
        
        [System.Serializable]
        public enum RTDisplacementSize {
            _128 = 128,
            _256 = 256,
            _512 = 512,
            _1024 = 1024
        }

        [System.Serializable]
        public class GrassDisplacementSettings
        {
            public RTDisplacementSize Resolution = RTDisplacementSize._256;
            public float Size = 20.0f;
            public bool ShiftRenderTex = false;
        }

        public GrassDisplacementSettings settings = new GrassDisplacementSettings();
        GrassDisplacementPass m_ScriptablePass;

        /// <inheritdoc/>
        public override void Create()
        {
            // Create and setup the pass
            m_ScriptablePass = new GrassDisplacementPass(settings);
            // Configures where the render pass should be injected. // This should work with forward and deferred
            m_ScriptablePass.renderPassEvent = RenderPassEvent.BeforeRendering;
        }


    //  ---------------------------------------------------------
    //  The Pass

        class GrassDisplacementPass : ScriptableRenderPass
        {

            // List of shader tags used to build the renderer list
            private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();


            private RTHandle m_GrassDisplacementFX;
            private RenderTextureDescriptor descriptor;


            private static Matrix4x4 projectionMatrix;
            private static Matrix4x4 worldToCameraMatrix;

            private static float m_Size = 20.0f;
            private static int m_Resolution = 256;
            private static bool m_ShiftRenderTex = false;

            private static float stepSize;
            private static float oneOverStepSize;

            private Vector4 posSize = Vector4.zero;
            private static readonly ShaderTagId m_ShaderTagId = new ShaderTagId("LuxGrassDisplacementFX");
            private static readonly int DisplacementTexPosSizePID = Shader.PropertyToID("_Lux_DisplacementPosition");
            private static readonly int _Lux_DisplacementRT = Shader.PropertyToID("_Lux_DisplacementRT");
            private const string m_PassName = "Render Lux Grass Displacement FX";

            //  There is no 0.5 in 8bit colors...
            private static Color m_ClearColor = new Color(127.0f / 255.0f, 127.0f / 255.0f, 1, 1);

            public GrassDisplacementPass(GrassDisplacementSettings settings)
            {
                
                // Copy custom settings to the private static equivalents
                m_Size = settings.Size;
                m_Resolution = (int)settings.Resolution;
                m_ShiftRenderTex = settings.ShiftRenderTex;

                // Set up all constants
                stepSize = m_Size / (float)m_Resolution;
                oneOverStepSize = 1.0f / stepSize;
                var halfSize = m_Size * 0.5f;
                projectionMatrix = Matrix4x4.Ortho(-halfSize, halfSize, -halfSize, halfSize, 0.1f, 80.0f);
                projectionMatrix = GL.GetGPUProjectionMatrix(projectionMatrix, false);
                worldToCameraMatrix.SetRow(0, new Vector4(1, 0, 0, 0)); //last is x pos
                worldToCameraMatrix.SetRow(1, new Vector4(0, 0, 1, 0)); //last is z pos
                worldToCameraMatrix.SetRow(2, new Vector4(0, 1, 0, 0)); //last is y pos
                worldToCameraMatrix.SetRow(3, new Vector4(0, 0, 0, 1));

                // Create the Render Texture
                var descriptor = new RenderTextureDescriptor(m_Resolution, m_Resolution);
                descriptor.depthBufferBits = 0;
                descriptor.colorFormat = RenderTextureFormat.Default;
                descriptor.dimension = TextureDimension.Tex2D;
                descriptor.enableRandomWrite = false;
                descriptor.useMipMap = false;
                descriptor.autoGenerateMips = false;

                m_GrassDisplacementFX = RTHandles.Alloc (
                    descriptor,
                    FilterMode.Bilinear,
                    TextureWrapMode.Clamp,
                    false,                      // isShadowMap
                    1,                          // anisoLevel
                    0,                          // mipMapBias
                    "_LuxURP_GrassDisplacementRT"
                );
            }

            // This class stores the data needed by the pass, passed as parameter to the delegate function that executes the pass
            private class PassData
            {
                public UnityEngine.Rendering.RenderGraphModule.RendererListHandle rendererListHandle;
                // Lux: We need cameraData in the Execute()
                public UniversalCameraData cameraData;
            }
     
            // Sample utility method to create a renderer list via the RenderGraph API
            private void InitRendererLists(ContextContainer frameData, ref PassData passData, UnityEngine.Rendering.RenderGraphModule.RenderGraph renderGraph)
            {
                // Access the relevant frame data from the Universal Render Pipeline
                UniversalRenderingData universalRenderingData = frameData.Get<UniversalRenderingData>();
                UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
                UniversalLightData lightData = frameData.Get<UniversalLightData>();

                var sortFlags = SortingCriteria.CommonTransparent; // cameraData.defaultOpaqueSortFlags;
                RenderQueueRange renderQueueRange = RenderQueueRange.all; //  opaque;
                FilteringSettings filterSettings = new FilteringSettings(renderQueueRange, -1);

                DrawingSettings drawSettings = RenderingUtils.CreateDrawingSettings(m_ShaderTagId, universalRenderingData, cameraData, lightData, sortFlags);
     
                var param = new RendererListParams(universalRenderingData.cullResults, drawSettings, filterSettings);
                passData.rendererListHandle = renderGraph.CreateRendererList(param);

                //  Lux: We have to add cameraData
                passData.cameraData = cameraData;

            }
     
            // This static method is used to execute the pass and passed as the RenderFunc delegate to the RenderGraph render pass
            static void ExecutePass(PassData data, UnityEngine.Rendering.RenderGraphModule.RasterGraphContext context)
            {
                var camera = data.cameraData.camera;
                var cameraTransform = camera.transform;
                var cameraPos = cameraTransform.position;

    #if ENABLE_VR && ENABLE_XR_MODULE
                var isStereoEnabled = data.cameraData.xr.enabled;
                var stereoRenderingMode = XRSettings.stereoRenderingMode;
                if (isStereoEnabled) {
                    context.cmd.SetSinglePassStereo(SinglePassStereoMode.None);
                }
    #endif

                //  Push cameraPos forward – if enabled    
                var camForward = cameraTransform.forward;
                if (m_ShiftRenderTex)
                {
                    var t_camForward = new Vector2(camForward.x, camForward.z);
                    t_camForward.Normalize();
                    // unstable
                    // cameraPos.x += camForward.x * m_Size * 0.5f;
                    // cameraPos.z += camForward.z * m_Size * 0.5f;
                    // still rather unstable...
                    cameraPos.x += t_camForward.x * m_Size * 0.33f;
                    cameraPos.z += t_camForward.y * m_Size * 0.33f;
                }

                //  Store original Camera matrices - not needed
                //  var worldToCameraMatrixOrig = camera.worldToCameraMatrix;
                //  var projectionMatrixOrig = camera.projectionMatrix;

                //  Quantize movement to fit texel size of RT – this stabilzes the final visual result
                Vector2 positionRT;
                positionRT.x = Mathf.Floor(cameraPos.x * oneOverStepSize) * stepSize;
                positionRT.y = Mathf.Floor(cameraPos.z * oneOverStepSize) * stepSize;

                //  Update the custom worldToCameraMatrix – we only have to update the translation/position
                worldToCameraMatrix.SetColumn(3, new Vector4(-positionRT.x, -positionRT.y, -cameraPos.y - 40.0f, 1));
                context.cmd.SetViewProjectionMatrices(worldToCameraMatrix, projectionMatrix);
                
                context.cmd.ClearRenderTarget(RTClearFlags.Color, m_ClearColor, 1,0);
                context.cmd.DrawRendererList(data.rendererListHandle);

                //  Calc and set grass shader params
                Vector3 posSize;
                posSize.x = positionRT.x - m_Size * 0.5f;
                posSize.y = positionRT.y - m_Size * 0.5f;
                posSize.z = 1.0f / m_Size;

                //  Set grass shader params - needs: builder.AllowGlobalStateModification(true);
                context.cmd.SetGlobalVector(DisplacementTexPosSizePID, posSize);

    #if ENABLE_VR && ENABLE_XR_MODULE
                if (isStereoEnabled) {
                    context.cmd.SetSinglePassStereo(stereoRenderingMode);
                }
    #endif

            }

            // This is where the renderGraph handle can be accessed.
            // Each ScriptableRenderPass can use the RenderGraph handle to add multiple render passes to the render graph
            public override void RecordRenderGraph(UnityEngine.Rendering.RenderGraphModule.RenderGraph renderGraph, ContextContainer frameData)
            {
                // Add a raster render pass to the render graph, specifying the name and the data type that will be passed to the ExecutePass function
                using (var builder = renderGraph.AddRasterRenderPass<PassData>(m_PassName, out var passData))
                {
                    // UniversalResourceData contains all the texture handles used by the renderer, including the active color and depth textures
                    // The active color and depth textures are the main color and depth buffers that the camera renders into
                    // UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

                    // Fill up the passData with the data needed by the pass
                    InitRendererLists(frameData, ref passData, renderGraph);
                   
                    // Make sure the renderer list is valid
                    if (!passData.rendererListHandle.IsValid())
                    {
                        return;
                    }
                   
                    // We declare the RendererList we just created as an input dependency to this pass, via UseRendererList()
                    builder.UseRendererList(passData.rendererListHandle);

                    // Setup the render target via SetRenderAttachment and SetRenderAttachmentDepth, which are the equivalent of using the old cmd.SetRenderTarget(color,depth)
                    TextureHandle customTarget = renderGraph.ImportTexture(m_GrassDisplacementFX);
                    builder.SetRenderAttachment(customTarget, 0);

                    // Lux: This is said to be bad - but it is needed due to SetGlobalVector. This also calls: builder.AllowPassCulling(false);
                    builder.AllowGlobalStateModification(true);

                    // Assign the ExecutePass function to the render pass delegate, which will be called by the render graph when executing the pass
                    builder.SetRenderFunc(
                        (PassData data, UnityEngine.Rendering.RenderGraphModule.RasterGraphContext context) => ExecutePass(data, context)
                    );

                    // Lux: We have to do this after calling builder.SetRenderFunc()
                    builder.SetGlobalTextureAfterPass(customTarget, _Lux_DisplacementRT);
                }
            }
        }
     
        // Here you can inject one or multiple render passes in the renderer.
        // This method is called when setting up the renderer once per-camera.
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }

}