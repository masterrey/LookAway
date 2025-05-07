using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Lamp : MonoBehaviour
{
    public Light mylight;
    public Renderer rend;
    // Start is called before the first frame update
    void Start()
    {
        DayTime.instance.DuskCall += TurnOff;
        DayTime.instance.DawnCall += TurnOn;
    }

  void TurnOn()
    {
        mylight.enabled = true;
        rend.materials[1].EnableKeyword("_EMISSION");
    }

    void TurnOff()
    {
        mylight.enabled = false;
        rend.materials[1].DisableKeyword("_EMISSION");
    }
}
