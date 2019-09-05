using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class MoveChan : MonoBehaviour
{
    public CharacterController charctrl;
    public Animator anim;
    Vector3 movaxis, turnaxis;
    public GameObject currentCamera;
    public float jumpspeed = 8;
    public float gravity = 20;

    float yresult;
    float flyvelocity = 3;
    public GameObject wing;
    public Transform rightHandObj, leftHandObj;
    bool jumpbtn = false;
    bool jumpbtnrelease = false;
    // Start is called before the first frame update
    void Start()
    {
        charctrl.enabled = false;
        if (SceneManager.GetActiveScene().name.Equals("Land"))
        {
            if (PlayerPrefs.HasKey("OldPlayerPosition"))
            {
                print("movendo "+ PlayerPrefsX.GetVector3("OldPlayerPosition"));
                transform.position = PlayerPrefsX.GetVector3("OldPlayerPosition");
               // Debug.Break();
            }
        }
        currentCamera = Camera.main.gameObject;
        charctrl.enabled = true;
    }
    private void Update()
    {
        if(Input.GetButtonDown("Jump"))
        {
            jumpbtn = true;
        }
    }

    void FixedUpdate()
    {

        movaxis = new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical"));

        if (wing.activeSelf)
        {
            yresult = -1;
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
           
            Vector3 movfly = new Vector3(Vector3.forward.x* flyvelocity, yresult- (flyvelocity-3), Vector3.forward.z* flyvelocity);
            charctrl.Move(transform.TransformVector(movfly) * 0.1f);


            float angz = Vector3.Dot(transform.right, Vector3.up);
            float angx = Vector3.Dot(transform.forward, Vector3.up);
            movfly = new Vector3(movaxis.z+ angx*2, -angz, -movaxis.x- angz);

            transform.Rotate(movfly);

            wing.transform.localRotation = Quaternion.Euler(0, 0, angz*50);


            flyvelocity -= angx*0.01f;
            flyvelocity = Mathf.Lerp(flyvelocity, 3, Time.fixedDeltaTime);
            flyvelocity = Mathf.Clamp(flyvelocity,0,5);
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
        if (Physics.Raycast(transform.position-(transform.forward*0.1f)+transform.up*0.3f, Vector3.down,out hit, 1000))
        {
            anim.SetFloat("JumpHeight", hit.distance);
            if(hit.distance>0.5f && jumpbtn && !wing.activeSelf)
            {
                wing.SetActive(true);
                yresult = .1f;
                flyvelocity = 3;
                jumpbtn = false;
                return;
            }
            if (hit.distance > 0.5f && jumpbtn && wing.activeSelf)
            {
                wing.SetActive(false);
                jumpbtn = false;
            }

        }
        jumpbtn = false;



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
