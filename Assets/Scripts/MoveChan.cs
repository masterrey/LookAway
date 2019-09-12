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
        charctrl.enabled = false; //desabilita o character controle para o save funcionar
        if (SceneManager.GetActiveScene().name.Equals("Land"))  //se a cena for a principal busca o save de posicao
        {
            if (PlayerPrefs.HasKey("OldPlayerPosition")) //checa se existe a chave do save
            {
                print("movendo "+ PlayerPrefsX.GetVector3("OldPlayerPosition")); 
                transform.position = PlayerPrefsX.GetVector3("OldPlayerPosition");  //coloca o player no ultimo lugar salvo
               // Debug.Break();
            }
        }
        currentCamera = Camera.main.gameObject;     //busca a camera do jogador
        charctrl.enabled = true;        //liga o character controler de volta
    }
    private void Update()
    {
        if(Input.GetButtonDown("Jump"))     //se apertar pulo
        {
            if (!charctrl.enabled) //codigo de saida da vagoneta
            {
                charctrl.enabled = true;        //desliga o character control pra ele acompanhar o rigidbody
                yresult = jumpspeed;    //forca o pulo
                transform.parent = null;     //desparenta forcado
            }
            jumpbtn = true; //habilita abooleana de pulo
        }
    }

    void FixedUpdate()
    {

        movaxis = new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical")); //captura o joystick e teclado

        if (wing.activeSelf)        //se a asa tiver ligada
        {
            yresult = -1;   //gravidade fica leve
        }
        else
        {
            yresult -= gravity * Time.fixedDeltaTime;   //gravidade fica pesada

        }
        //calcula a direcao relativa do personagem em relacao ao mundo
        Vector3 relativedirection = currentCamera.transform.TransformVector(movaxis);
        relativedirection = new Vector3(relativedirection.x, yresult, relativedirection.z);
        //remove o y da altura do vetor
        Vector3 relativeDirectionWOy = relativedirection;
        relativeDirectionWOy = new Vector3(relativedirection.x, 0, relativedirection.z);

        //se o character controler esta ativo
        if (charctrl)
        {
            anim.SetFloat("Speed", charctrl.velocity.magnitude);//seta a animacao de velocidade
        }
        else
        {
            anim.SetFloat("Speed", 0); //zera a velocidade na animacao
        }
        //se a asa estiver ativa
        if (wing.activeSelf)
        {
           //troca o movimento para o movimento de planeio
            Vector3 movfly = new Vector3(Vector3.forward.x* flyvelocity, yresult- (flyvelocity-3), Vector3.forward.z* flyvelocity);
            charctrl.Move(transform.TransformVector(movfly) * 0.1f);

            //calcula os angulos normais pra retorno da asa papa posicao estavel
            float angz = Vector3.Dot(transform.right, Vector3.up);
            float angx = Vector3.Dot(transform.forward, Vector3.up);
            movfly = new Vector3(movaxis.z+ angx*2, -angz, -movaxis.x- angz);
            //aplica a rotacao para a estabilidade
            transform.Rotate(movfly);
            //modifica a rotacao somente da asa para efeito visual
            wing.transform.localRotation = Quaternion.Euler(0, 0, angz*50);

            //calcula as velocidades de voo
            flyvelocity -= angx*0.01f;
            flyvelocity = Mathf.Lerp(flyvelocity, 3, Time.fixedDeltaTime);
            flyvelocity = Mathf.Clamp(flyvelocity,0,5);
        }
        else //personagem esta no chao 
        {
            //movimenta por character control
            charctrl.Move(relativedirection * 0.1f);
            //aplica a rotacao relativa
            Quaternion rottogo = Quaternion.LookRotation(relativeDirectionWOy * 2 + transform.forward);
            transform.rotation = Quaternion.Lerp(transform.rotation, rottogo, Time.fixedDeltaTime * 50);
        }
        //se apertar o soco
        if (Input.GetButtonDown("Fire1"))
        {
            anim.SetTrigger("PunchA"); //chama a animacao de soco
        }
        //se personagem está no chao
        if (charctrl.isGrounded)
        {
            wing.SetActive(false); //desliga a asa
            yresult = 0;    //zera a gravidade (evita bug de quada muito rapida) 
        }
        //se ele está no chao e apertou pulo
        if (charctrl.isGrounded && jumpbtn)
        {
            anim.SetTrigger("Jump"); //chama animacao de pulo
            yresult = jumpspeed;  //aplica a forca de pulo

        }


        //raycast pra detectar o chao e fazer o pulo proporcional
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
    //serve pra habilitar os ik da unity para colocar a mao da personagem na asa ao voar 
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
    //se bater qm qualquer coisa perde a asa
    private void OnCollisionEnter(Collision collision)
    {
        wing.SetActive(false);
    }
}
