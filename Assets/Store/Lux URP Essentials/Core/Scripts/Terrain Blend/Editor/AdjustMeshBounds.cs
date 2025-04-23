using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;
using LuxURPEssentials;

public class AdjustMeshBounds : EditorWindow
{
    static AdjustMeshBounds window;

    [MenuItem("Window/Lux URP Essentials/Scale Mesh Bounds", false, 1000)]
    public static void Init()
    {
        window = GetWindow<AdjustMeshBounds>(false, "Scale Mesh Bounds", true);
        window.minSize = new Vector2(480, 380);
    }


    public Mesh[] _meshes;
    public Vector3 _extentBounds = new Vector3(0.0f, 1.0f, 0.0f);
    public Vector3 _currentBounds;

    void ScaleMeshBounds()
    {
        for (int i = 0; i < _meshes.Length; i++)
        {
            string filePath = AssetDatabase.GetAssetPath(_meshes[i]);
            var directory = Path.GetDirectoryName(filePath);
            var file = _meshes[i].name + "_ScaledBounds.asset";
            filePath = Path.Combine(directory, file);
            if (!string.IsNullOrEmpty(filePath))
            {
                var t_mesh = new Mesh();
                t_mesh.vertices = _meshes[i].vertices;
                t_mesh.normals = _meshes[i].normals;
                t_mesh.tangents = _meshes[i].tangents;
                t_mesh.uv = _meshes[i].uv;
                if (_meshes[i].uv2 != null)
                {
                    t_mesh.uv2 = _meshes[i].uv2;
                }
                t_mesh.triangles = _meshes[i].triangles;

                var bounds = _meshes[i].bounds;
                bounds.extents = bounds.extents + _extentBounds;
                t_mesh.bounds = bounds;

            //  Mark mesh as none readable!
                t_mesh.UploadMeshData(true);

                //var curPath = directory.
                var name = _meshes[i].name;

                var testMesh = (Mesh)AssetDatabase.LoadAssetAtPath(filePath, typeof(Mesh));
                if (testMesh != null)
                {
                    t_mesh.name = testMesh.name;
                    EditorUtility.CopySerialized(t_mesh, testMesh);
                    AssetDatabase.SaveAssets();
                }
                else
                {
                    AssetDatabase.CreateAsset(t_mesh, filePath);
                }
            }
        }
        AssetDatabase.Refresh();
    }


    void OnGUI()
    {
        ScriptableObject target = this;
        SerializedObject so = new SerializedObject(target);
        SerializedProperty extentBounds = so.FindProperty("_extentBounds");
        SerializedProperty currentBounds = so.FindProperty("_currentBounds");
        SerializedProperty meshes = so.FindProperty("_meshes");

        if (meshes.arraySize > 0 && meshes.GetArrayElementAtIndex(0).objectReferenceValue != null)
        {
            var mesh = (Mesh)meshes.GetArrayElementAtIndex(0).objectReferenceValue;
            currentBounds.vector3Value = mesh.bounds.extents;
        }
        GUI.enabled = false;
            EditorGUILayout.PropertyField(currentBounds, true);
        GUI.enabled = true;

        EditorGUILayout.PropertyField(extentBounds, true);

        EditorGUILayout.PropertyField(meshes, true);
        so.ApplyModifiedProperties();

        GUILayout.Space(16);
        if (GUILayout.Button("Adjust Bounds"))
        {
            if (_meshes.Length > 0 && _meshes[0] != null)
            {
                ScaleMeshBounds();
            }
        }
    }
}
