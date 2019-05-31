using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MoveChan : MonoBehaviour
{
    public CharacterController charctrl;
    public Animator anim;
    Vector3 movaxis, turnaxis;
    public GameObject currentCamera;
    // Start is called before the first frame update
    void Start()
    {
        currentCamera = Camera.main.gameObject;
    }

    void FixedUpdate()
    {

        movaxis = new Vector3(Input.GetAxis("Horizontal")*0.3f, 0, Input.GetAxis("Vertical"));
       

        charctrl.SimpleMove(transform.TransformVector(movaxis)*3);

        anim.SetFloat("Speed", charctrl.velocity.magnitude);
        

        Vector3 dirtogo = new Vector3(currentCamera.transform.forward.x, 0
            , currentCamera.transform.forward.z);

        Quaternion rottogo = Quaternion.LookRotation( (movaxis.magnitude*dirtogo*2 + transform.forward));

        transform.rotation = Quaternion.Lerp(transform.rotation,rottogo,Time.fixedDeltaTime*3);

        if (Input.GetButtonDown("Fire1"))
        {
            anim.SetTrigger("PunchA");
        }

    }
}
