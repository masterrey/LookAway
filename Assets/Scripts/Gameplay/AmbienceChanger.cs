using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AmbienceChanger : MonoBehaviour
{
  
    public AudioSource sourceday;
    public AudioSource sourcenight;
    // Start is called before the first frame update
    void Start()
    {
        DayTime.instance.DuskCall += morning;
        DayTime.instance.DawnCall += afternoon;
       
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    void morning()
    {
        StartCoroutine("Ajusttoday");
        
    }

    IEnumerator Ajusttoday()
    {
        while (sourceday.volume < 1)
        {
            sourceday.volume += DayTime.instance.daySpeed/(86400/4)*Time.deltaTime;
            sourcenight.volume -= DayTime.instance.daySpeed/(86400/4) * Time.deltaTime;
            yield return new WaitForEndOfFrame();
          
        }
    }
    IEnumerator Ajusttonight()
    {
        while (sourcenight.volume < 1)
        {
            sourceday.volume -= DayTime.instance.daySpeed / (86400 / 2) * Time.deltaTime;
            sourcenight.volume += DayTime.instance.daySpeed / (86400 / 2) * Time.deltaTime;
            yield return new WaitForEndOfFrame();
           
        }
    }
    void afternoon()
    {
        StartCoroutine("Ajusttonight");
       
    }
}
