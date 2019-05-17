using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Lamp : MonoBehaviour
{
    public Light mylight;
    // Start is called before the first frame update
    void Start()
    {
        DayTime.instance.DuskCall += TurnOff;
        DayTime.instance.DawnCall += TurnOn;
    }

  void TurnOn()
    {
        mylight.enabled = true;
    }

    void TurnOff()
    {
        mylight.enabled = false;
    }
}
