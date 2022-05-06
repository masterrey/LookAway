using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlatformPhis : MonoBehaviour
{
    public float distance;
    public float velocity;
    public bool move = true;
    Vector3 position;
    Rigidbody rdb,player;
    Vector3 lastposition,lastmove;
   
    // Start is called before the first frame update
    void Start()
    {
        position = transform.position;
        rdb = GetComponent<Rigidbody>();
    }
    // Update is called once per frame
    void FixedUpdate()
    {
        
        if (move)
        {
           
            rdb.MovePosition(position +
                new Vector3(0, 0, Mathf.Sin(Time.time * velocity) * distance));
        }
       
      
    }
       
   


}
