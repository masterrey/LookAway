using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MoveChan : MonoBehaviour
{
    public CharacterController charctrl;
    public Animator anim;
    Vector3 movaxis, turnaxis;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    void FixedUpdate()
    {

        movaxis = new Vector3(0, 0, Input.GetAxis("Vertical"));
        turnaxis = new Vector3(0, Input.GetAxis("Horizontal"), 0);

        charctrl.SimpleMove(transform.TransformVector(movaxis)*3);

        anim.SetFloat("Speed", charctrl.velocity.magnitude);
        transform.Rotate(turnaxis);

        if (Input.GetButtonDown("Fire1"))
        {
            anim.SetTrigger("PunchA");
        }

    }
}
