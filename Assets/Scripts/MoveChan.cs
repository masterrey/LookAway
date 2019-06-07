using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MoveChan : MonoBehaviour
{
    public CharacterController charctrl;
    public Animator anim;
    Vector3 movaxis, turnaxis;
    public GameObject currentCamera;
    public float jumpspeed = 8;
    public float gravity = 20;
    float yresult;
    // Start is called before the first frame update
    void Start()
    {
        currentCamera = Camera.main.gameObject;
    }

    void FixedUpdate()
    {

        movaxis = new Vector3(Input.GetAxis("Horizontal")*0.3f, 0, Input.GetAxis("Vertical"));

        Vector3 relativedirection = currentCamera.transform.TransformVector(movaxis).normalized;
        relativedirection = new Vector3(relativedirection.x, yresult, relativedirection.z);
        Vector3 relativeDirectionWOy = relativedirection;
        relativeDirectionWOy = new Vector3(relativedirection.x, 0, relativedirection.z);
        charctrl.Move(relativedirection * 0.1f);

        anim.SetFloat("Speed", charctrl.velocity.magnitude);
 
        Quaternion rottogo = Quaternion.LookRotation(relativeDirectionWOy*2 + transform.forward);
        transform.rotation = Quaternion.Lerp(transform.rotation,rottogo,Time.fixedDeltaTime*50);

        if (Input.GetButtonDown("Fire1"))
        {
            anim.SetTrigger("PunchA");
        }

        if (charctrl.isGrounded && Input.GetButton("Jump"))
        {
            anim.SetTrigger("Jump");
            yresult = jumpspeed;

        }
        yresult -= gravity * Time.fixedDeltaTime;

        RaycastHit hit;
        if (Physics.Raycast(transform.position, Vector3.down,out hit, 100))
        {
            anim.SetFloat("JumpHeight", hit.distance);
        }
    }
}
