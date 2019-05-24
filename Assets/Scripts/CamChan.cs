using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CamChan : MonoBehaviour
{
    public GameObject player;
    public float height, heightlook, distance, tolerance;

    // Start is called before the first frame update
    void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player");
    }

    // Update is called once per frame
    void LateUpdate()
    {
        transform.LookAt(player.transform.position+Vector3.up*heightlook);
        //posicao ideal
        Vector3 dir =  Vector3.up * height + player.transform.forward * distance;

        Vector3 postogo = player.transform.position +
            Vector3.up * height +player.transform.forward * distance;
        
        RaycastHit hit;
        if(Physics.Raycast(player.transform.position + Vector3.up * heightlook, dir, out hit,10))
        {
            postogo = hit.point- dir.normalized*tolerance;
        }
        
        transform.position = Vector3.Lerp(transform.position, postogo, Time.smoothDeltaTime);
    }
}
