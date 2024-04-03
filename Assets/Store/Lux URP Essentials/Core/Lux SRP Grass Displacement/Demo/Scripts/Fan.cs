using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Fan : MonoBehaviour
{
    
    public float _speed = 10.0f;
    Transform trans;

    void OnEnable() {
       trans = this.GetComponent<Transform>();
    }

    void Update()
    {
       trans.Rotate(0, 0, _speed * Time.deltaTime, Space.Self); 
    }
}
