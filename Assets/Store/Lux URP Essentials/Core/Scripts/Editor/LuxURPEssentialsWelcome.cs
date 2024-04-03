using UnityEngine;
using UnityEditor;
using System;
using System.Collections;

namespace LuxURPEssentials
{
	public class LuxURPEssentialsWelcome : EditorWindow
	{
		
		static LuxURPEssentialsWelcome window;

		[MenuItem( "Window/Lux URP Essentials/Welcome", false, 1000 )]
		public static void Init()
		{
			window = GetWindow<LuxURPEssentialsWelcome>(false, "Lux URP Essentials", true);
			window.minSize = new Vector2(480, 270);
		}

		public void OnGUI()
		{
			
			var _style_bodytxt = new GUIStyle(EditorStyles.label);
			_style_bodytxt.wordWrap = true;
			_style_bodytxt.fontSize = 12;

			GUILayout.Space(16);

			EditorGUILayout.BeginVertical();

			GUILayout.BeginHorizontal();
				GUILayout.Space(16);
				EditorGUILayout.LabelField("Welcome to Lux URP Essentials!", EditorStyles.boldLabel);
				GUILayout.Space(16);
			GUILayout.EndHorizontal();

			GUILayout.Space(8);

			GUILayout.BeginHorizontal();
				GUILayout.Space(16);
				EditorGUILayout.LabelField(
					"Currently installed: Version 1.98 for Unity 2022.3 LTS and URP 14.0.7", _style_bodytxt);
				GUILayout.Space(16);
			GUILayout.EndHorizontal();

			GUILayout.Space(16);

			GUILayout.BeginHorizontal();
				GUILayout.Space(16);
				EditorGUILayout.LabelField("Compatibility Notes", EditorStyles.boldLabel);
				GUILayout.Space(16);
			GUILayout.EndHorizontal();

			GUILayout.Space(8);

			GUILayout.BeginHorizontal();
				GUILayout.Space(16);
				EditorGUILayout.LabelField(
					"The package you have downloaded from the asset store installed shaders compatible with URP 14.0.7. " + 
					"In case you got any compilation errors this most likely is caused by the fact that you are using a different version of URP.\n" + 
					"If so please have a look at the included sub packages and install the one you need.", _style_bodytxt);
				GUILayout.Space(16);
			GUILayout.EndHorizontal();

			GUILayout.Space(16);

			GUILayout.BeginHorizontal();
				GUILayout.Space(16);
				EditorGUILayout.LabelField("Pipeline Settings", EditorStyles.boldLabel);
				GUILayout.Space(16);
			GUILayout.EndHorizontal();

			GUILayout.Space(8);

			GUILayout.BeginHorizontal();
				GUILayout.Space(16);
				EditorGUILayout.LabelField(
					"Some shaders like Water or Glass rely on the Depth and Opaque Texture.\n" + 
					"Please make sure that both are enabled in your Pipeline Asset and on your camera. " + 
					"Otherwise these materials may just be gray.", _style_bodytxt);
				GUILayout.Space(16);
			GUILayout.EndHorizontal();

			GUILayout.Space(16);

			GUILayout.BeginHorizontal();
				GUILayout.Space(16);
				EditorGUILayout.LabelField("Useful Resources", EditorStyles.boldLabel);
				GUILayout.Space(16);
			GUILayout.EndHorizontal();

			GUILayout.Space(8);

			GUILayout.BeginHorizontal();
				GUILayout.Space(16);
				if (GUILayout.Button("Documentation"))
				{
					Application.OpenURL("https://docs.google.com/document/d/1ck3hmPzKUdewHfwsvmPYwSPCP8azwtpzN7aOLJHvMqE/edit");
				}
				if (GUILayout.Button("URP 12 and above"))
				{
					Application.OpenURL("https://docs.google.com/document/d/1ZtPZTo2KP7truLyMh-e0wEYI7AYUW9OsGL0niCL0MlY");
				}
				if (GUILayout.Button("What's new"))
				{
					Application.OpenURL("https://docs.google.com/document/d/10OYubrLPxG5EYBknbxTsJRZoA_4TzZGFFzmZtGsDcQ8/edit");
				}
				if (GUILayout.Button("Forum Thread"))
				{
					Application.OpenURL("https://forum.unity.com/threads/released-lux-urp-essentials.712619/");
				}
				GUILayout.Space(16);
			GUILayout.EndHorizontal();

			GUILayout.EndVertical();

			GUILayout.FlexibleSpace();

			EditorGUILayout.BeginVertical(GUILayout.Height(24));

				GUILayout.BeginHorizontal();
					GUILayout.Space(16);
					EditorGUI.BeginChangeCheck();
					var show = EditorPrefs.GetBool("LuxURPEssentialsDoNotShowWelcome");
					show = EditorGUILayout.Toggle("Do not show again", show);
					if( EditorGUI.EndChangeCheck() )
					{
						EditorPrefs.SetBool("LuxURPEssentialsDoNotShowWelcome", show);
					}
					GUILayout.Space(16);
				GUILayout.EndHorizontal();

			GUILayout.EndVertical();
		}
	}
}


































