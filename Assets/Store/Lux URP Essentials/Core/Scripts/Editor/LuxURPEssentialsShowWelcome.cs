using UnityEditor;
using UnityEngine;
using System;
using System.Collections;


namespace LuxURPEssentials
{
	[InitializeOnLoad]
	public class LuxURPEssentialsShowWelcome : MonoBehaviour
	{
	    
		static LuxURPEssentialsShowWelcome()
		{
		//	To show it at start up
			EditorApplication.update += Update;
		}


	    static void Update()
		{
			EditorApplication.update -= Update;

			if( !EditorApplication.isPlayingOrWillChangePlaymode )
			{
				var hide = EditorPrefs.GetBool("LuxURPEssentialsDoNotShowWelcome");
				if(!hide)
				{
					LuxURPEssentialsWelcome.Init();
				}
			}
		}
	}
}