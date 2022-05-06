using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
public class LoadAditiveScene : MonoBehaviour
{
    public string SceneName;
    AsyncOperation asyncOperation;
    bool sceneloaded = false;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if(asyncOperation != null)
        {
          
           LoadIcon.instance.LoadIconRun(asyncOperation.progress+0.1f);
            if (asyncOperation.isDone&&LoadIcon.instance)
            {
                LoadIcon.instance.LoadIconRun(0);
                asyncOperation = null;
            }
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.gameObject.CompareTag("Player")&& !sceneloaded)
        {
            sceneloaded = true;
            asyncOperation = SceneManager.LoadSceneAsync(SceneName, LoadSceneMode.Additive);
        }
    }

    private void OnTriggerExit(Collider other)
    {
        if (other.gameObject.CompareTag("Player"))
        {
            SceneManager.UnloadSceneAsync(SceneName);
            sceneloaded=false;
            
        }
    }
}
