using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class LoadIcon : MonoBehaviour
{
    public static LoadIcon instance;
    Image icon;
    public void LoadIconRun(float progress)
    {
        icon.fillAmount = progress;
    }
    // Start is called before the first frame update
    void Start()
    {
        if(instance == null)
            instance = this;

        icon=GetComponent<Image>();
    }

    // Update is called once per frame
    void Update()
    {
       
    }
}
