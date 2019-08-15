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
    public GameObject wing;
    public Transform rightHandObj, leftHandObj;
    bool jumpbtn = false;
    // Start is called before the first frame update
    void Start()
    {
        currentCamera = Camera.main.gameObject;
    }
    private void Update()
    {
        jumpbtn = Input.GetButton("Jump");
    }

    void FixedUpdate()
    {

        movaxis = new Vector3(Input.GetAxis("Horizontal")*0.3f, 0, Input.GetAxis("Vertical"));

        if (wing.activeSelf)
        {
           
            yresult = -Time.fixedDeltaTime*10;
            movaxis = Vector3.forward * 3 ;
        }
        else
        {
            yresult -= gravity * Time.fixedDeltaTime;

        }

        Vector3 relativedirection = currentCamera.transform.TransformVector(movaxis);
        relativedirection = new Vector3(relativedirection.x, yresult, relativedirection.z);

        Vector3 relativeDirectionWOy = relativedirection;
        relativeDirectionWOy = new Vector3(relativedirection.x, 0, relativedirection.z);

       

        anim.SetFloat("Speed", charctrl.velocity.magnitude);
        if (wing.activeSelf)
        {
            Vector3 movfly = new Vector3(movaxis.x, yresult, movaxis.z);
            charctrl.Move(transform.TransformVector(movfly) * 0.1f);


          
        }
        else
        {
            charctrl.Move(relativedirection * 0.1f);
            Quaternion rottogo = Quaternion.LookRotation(relativeDirectionWOy * 2 + transform.forward);
            transform.rotation = Quaternion.Lerp(transform.rotation, rottogo, Time.fixedDeltaTime * 50);
        }
        if (Input.GetButtonDown("Fire1"))
        {
            anim.SetTrigger("PunchA");
        }

        if (charctrl.isGrounded && jumpbtn)
        {
            anim.SetTrigger("Jump");
            yresult = jumpspeed;

        }

        if (charctrl.isGrounded)
        {
            wing.SetActive(false);
            
        }
        



        RaycastHit hit;
        if (Physics.Raycast(transform.position, Vector3.down,out hit, 1000))
        {
            anim.SetFloat("JumpHeight", hit.distance);
            if(hit.distance>0.2f && jumpbtn && !wing.activeSelf)
            {
                wing.SetActive(true);
                yresult = .1f;
                return;
            }
            if (hit.distance > 0.2f && jumpbtn && wing.activeSelf)
            {
                wing.SetActive(false);
            }

        }

        
       

    }


    //a callback for calculating IK
    void OnAnimatorIK()
    {
        if (wing.activeSelf)
        {
            


            if (rightHandObj != null)
            {
                anim.SetIKPositionWeight(AvatarIKGoal.RightHand, 1);
                anim.SetIKRotationWeight(AvatarIKGoal.RightHand, 1);
                anim.SetIKPosition(AvatarIKGoal.RightHand, rightHandObj.position);
                anim.SetIKRotation(AvatarIKGoal.RightHand, rightHandObj.rotation);


                anim.SetIKPositionWeight(AvatarIKGoal.LeftHand, 1);
                anim.SetIKRotationWeight(AvatarIKGoal.LeftHand, 1);
                anim.SetIKPosition(AvatarIKGoal.LeftHand, leftHandObj.position);
                anim.SetIKRotation(AvatarIKGoal.LeftHand, leftHandObj.rotation);


            }
        }
    }

    private void OnCollisionEnter(Collision collision)
    {
        wing.SetActive(false);
    }
}
