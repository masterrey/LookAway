using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEngine.Experimental.Rendering;

public class LuxURPTerrainShaderGUI : ShaderGUI, ITerrainLayerCustomUI
{
    public override void OnGUI (MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        base.OnGUI (materialEditor, properties);
    }


//  ///////////////////////////////

    private class StylesLayer
    {
        public readonly GUIContent warningHeightBasedBlending = new GUIContent("Height-based blending is disabled if you have more than four TerrainLayer materials!");

        public readonly GUIContent enableHeightBlend = new GUIContent("Enable Height-based Blend", "Blend terrain layers based on height values.");
        public readonly GUIContent heightTransition = new GUIContent("Height Transition", "Size in world units of the smooth transition between layers.");
        public readonly GUIContent enableInstancedPerPixelNormal = new GUIContent("Enable Per-pixel Normal", "Enable per-pixel normal when the terrain uses instanced rendering.");

        public readonly GUIContent diffuseTexture = new GUIContent("Diffuse");
        public readonly GUIContent colorTint = new GUIContent("Color Tint");
        public readonly GUIContent opacityAsDensity = new GUIContent("Opacity as Density", "Enable Density Blend (if unchecked, opacity is used as Smoothness)");
        public readonly GUIContent normalMapTexture = new GUIContent("Normal Map");
        public readonly GUIContent normalScale = new GUIContent("Normal Scale");
        public readonly GUIContent maskMapTexture = new GUIContent("Mask", "R: Metallic\nG: AO\nB: Height\nA: Smoothness");
        public readonly GUIContent maskMapTextureWithoutHeight = new GUIContent("Mask Map", "R: Metallic\nG: AO\nA: Smoothness");
        public readonly GUIContent channelRemapping = new GUIContent("Channel Remapping");
        public readonly GUIContent defaultValues = new GUIContent("Channel Default Values");
        public readonly GUIContent metallic = new GUIContent("R: Metallic");
        public readonly GUIContent ao = new GUIContent("G: AO");
        public readonly GUIContent height = new GUIContent("B: Height");
        public readonly GUIContent heightParametrization = new GUIContent("Parametrization");
        public readonly GUIContent heightAmplitude = new GUIContent("Amplitude (cm)");
        public readonly GUIContent heightBase = new GUIContent("Base (cm)");
        public readonly GUIContent heightMin = new GUIContent("Min (cm)");
        public readonly GUIContent heightMax = new GUIContent("Max (cm)");
        public readonly GUIContent heightCm = new GUIContent("B: Height (cm)");
        public readonly GUIContent smoothness = new GUIContent("A: Smoothness");
    }

    static StylesLayer s_Styles = null;
    private static StylesLayer styles { get { if (s_Styles == null) s_Styles = new StylesLayer(); return s_Styles; } }


    bool ITerrainLayerCustomUI.OnTerrainLayerGUI(TerrainLayer terrainLayer, Terrain terrain)
    {
        var terrainLayers = terrain.terrainData.terrainLayers;

        terrainLayer.diffuseTexture = EditorGUILayout.ObjectField(styles.diffuseTexture, terrainLayer.diffuseTexture, typeof(Texture2D), false) as Texture2D;
        TerrainLayerUtility.ValidateDiffuseTextureUI(terrainLayer.diffuseTexture);

        var diffuseRemapMin = terrainLayer.diffuseRemapMin;
        var diffuseRemapMax = terrainLayer.diffuseRemapMax;
        EditorGUI.BeginChangeCheck();

        bool enableDensity = false;
        if (terrainLayer.diffuseTexture != null)
        {
            var rect = GUILayoutUtility.GetLastRect();
            rect.y += 16 + 4;
            rect.width = EditorGUIUtility.labelWidth + 64;
            rect.height = 16;

            ++ EditorGUI.indentLevel;
                var diffuseTint = new Color(diffuseRemapMax.x, diffuseRemapMax.y, diffuseRemapMax.z);
                diffuseTint = EditorGUI.ColorField(rect, styles.colorTint, diffuseTint, true, false, false);
                diffuseRemapMax.x = diffuseTint.r;
                diffuseRemapMax.y = diffuseTint.g;
                diffuseRemapMax.z = diffuseTint.b;
                diffuseRemapMin.x = diffuseRemapMin.y = diffuseRemapMin.z = 0;
            -- EditorGUI.indentLevel;
        }

        diffuseRemapMax.w = 1;
        diffuseRemapMin.w = enableDensity ? 1 : 0;

        if (EditorGUI.EndChangeCheck())
        {
            terrainLayer.diffuseRemapMin = diffuseRemapMin;
            terrainLayer.diffuseRemapMax = diffuseRemapMax;
        }

        // Display normal map UI
        terrainLayer.normalMapTexture = EditorGUILayout.ObjectField(styles.normalMapTexture, terrainLayer.normalMapTexture, typeof(Texture2D), false) as Texture2D;
        TerrainLayerUtility.ValidateNormalMapTextureUI(terrainLayer.normalMapTexture, TerrainLayerUtility.CheckNormalMapTextureType(terrainLayer.normalMapTexture));

        if (terrainLayer.normalMapTexture != null)
        {
            var rect = GUILayoutUtility.GetLastRect();
            rect.y += 16 + 4;
            rect.width = EditorGUIUtility.labelWidth + 64;
            rect.height = 16;

            ++ EditorGUI.indentLevel;
                terrainLayer.normalScale = EditorGUI.FloatField(rect, styles.normalScale, terrainLayer.normalScale);
            -- EditorGUI.indentLevel;
        }

        EditorGUILayout.Space();
        TerrainLayerUtility.TilingSettingsUI(terrainLayer);

        return true;
    }

}