using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EmitGravity : MonoBehaviour
{
    public ParticleSystem particleSystem;
    public bool hasCap = false;
    // Start is called before the first frame update
    void Start()
    {
        particleSystem = GetComponent<ParticleSystem>();
        particleSystem.Stop();

        
    }

    // Update is called once per frame
    void Update()
    {
        
         //check if the object are tumbled

        
            if(!hasCap)
            {
                particleSystem.Play();
            }
        
        else
        {
            particleSystem.Stop();
        }

        
        
    }
}
