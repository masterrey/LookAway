using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class IADamage : MonoBehaviour
{
    public int lives = 10;
    public IAStarFPS iastar;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (lives < 0)
        {
            iastar.Dead();
            Destroy(gameObject,4);
        }

    }

    private void OnCollisionEnter(Collision collision)
    {
       
    }

    public void ExplosionDamage()
    {
        lives =-1;
    }
}
