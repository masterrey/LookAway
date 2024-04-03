using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class IAControl : MonoBehaviour
{
    public CharacterController chtr;
    Vector3 move;
    public GameObject player;
    float myrot;
    void Start()
    {
        if (!chtr)
            chtr = GetComponent<CharacterController>();
        Cursor.lockState = CursorLockMode.Locked;
    }


    // Update is called once per frame
    void Update()
    {

        move = Vector3.forward*0.5f;
        Vector3 l1 = player.transform.position - transform.position;
        myrot = Mathf.LerpAngle(myrot, Vector3.SignedAngle(transform.forward, l1, Vector3.up), Time.deltaTime * 10);
       

        if (Physics.Raycast(transform.position-new Vector3(0,0.3f,0), transform.forward+ transform.right, out RaycastHit hit,1))
        {
            myrot= Mathf.LerpAngle(myrot, Vector3.SignedAngle(transform.right, l1, Vector3.up), Time.deltaTime * 10);
        }
       

        if (Physics.Raycast(transform.position - new Vector3(0, 0.3f, 0), transform.forward -transform.right, out RaycastHit hit2, 1))
        {
            myrot = Mathf.LerpAngle(myrot, Vector3.SignedAngle(-transform.right, l1, Vector3.up), Time.deltaTime * 10);
        }
       


        //conversao de direcao local pra global 
        Vector3 globalmove = transform.TransformDirection(move);
        chtr.SimpleMove(globalmove * 5);
        transform.Rotate(new Vector3(0,myrot,0));
       
    }
}
