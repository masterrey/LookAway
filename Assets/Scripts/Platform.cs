using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Platform : MonoBehaviour
{
    public float distance;
    public float velocity;
    Vector3 position;
    // Start is called before the first frame update
    void Start()
    {
        position = transform.position;
    }
    // Update is called once per frame
    void FixedUpdate()
    {
        transform.position= position+
            new Vector3(0,0,Mathf.Sin(Time.time* velocity) * distance); 
    }
    private void OnTriggerEnter(Collider col)
    {
       
        if (col.CompareTag("Player"))
        {
            col.transform.parent = transform;
        }
    }
    private void OnTriggerExit(Collider col)
    {
        if (col.CompareTag("Player"))
        {
            col.transform.parent = null;
        }
    }

}
