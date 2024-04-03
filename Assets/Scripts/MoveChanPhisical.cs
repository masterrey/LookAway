// Importando bibliotecas necessárias
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

// Classe MoveChanPhisical herda de MonoBehaviour
public class MoveChanPhisical : MonoBehaviour
{
    public int AlturaAgua = 31;

    // Variáveis públicas
    public Rigidbody rdb;
    public Animator anim;
    Vector3 movaxis;
    public GameObject currentCamera;
    public float jumpspeed = 8;
    public float gravity = 20;


    // Variáveis privadas
    float jumptime;
    float flyvelocity = 3;
    public GameObject wing;
    public Transform rightHandObj, leftHandObj;
    bool jumpbtn = false;
    bool grounded = false;
    bool jumpbtndown = false;
    GameObject closeThing;
    float weight;
    FixedJoint joint;

    // Método Start é chamado antes do primeiro frame
    void Start()
    {
        
        // Verifica se o nome da cena ativa é "Land"
        if (SceneManager.GetActiveScene().name.Equals("Land"))
        {
            // Verifica se há uma posição antiga do jogador
            if (PlayerPrefs.HasKey("OldPlayerPosition"))
            {
                // Move o jogador para a posição antiga
                print("movendo " + PlayerPrefsX.GetVector3("OldPlayerPosition"));
                transform.position = PlayerPrefsX.GetVector3("OldPlayerPosition");
            }
        }
        // Define a câmera principal como a câmera atual
        currentCamera = Camera.main.gameObject;
    }

    // Método Update é chamado a cada frame
    private void Update()
    {
        // Lida com o botão de pular
        if (Input.GetButtonDown("Jump"))
        {
            jumpbtn = true;
            jumpbtndown = true;
        }
        if (Input.GetButtonUp("Jump"))
        {
            jumpbtn = false;
            jumptime = 0;
        }

       
    }

    // Método FixedUpdate é chamado a cada frame em intervalos fixos
    void FixedUpdate()
    {

        // Atualiza o eixo de movimento com base no input do usuário
        movaxis = new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical"));

        // Define a animação de velocidade
        anim.SetFloat("Speed", rdb.velocity.magnitude);

        // Verifica se as asas estão ativas
        if (wing.activeSelf)
        {
            // Código para controlar o voo do personagem
            FlyControl();
        }
        else
        {
            // Código para controlar o movimento do personagem no chão
            GroundControl();
        }

        // Lida com o botão de ataque
        if (Input.GetButtonDown("Fire1"))
        {
            anim.SetTrigger("PunchA");
        }

        // Código para controlar o personagem enquanto ataca
        if (Input.GetButton("Fire1"))
        {
            // Código para controlar o personagem enquanto ataca e está voando
            if (wing.activeSelf)
            {
                rdb.AddRelativeForce(Vector3.forward * 10000);
            }
        }
        grounded = false;
        // Raycast para verificar a distância do personagem ao chão
        RaycastHit hit;
        if (Physics.Raycast(transform.position - (transform.forward * 0.1f) + transform.up * 0.3f, Vector3.down, out hit, 1000))
        {
            anim.SetFloat("JumpHeight", hit.distance);

            if (hit.distance < 0.5f )
            {
               
                grounded = true;
            }
            // Verifica se o personagem está no chão e o botão de pular está pressionado
            if (grounded && jumpbtn)
            {
                jumptime = 0.25f;
               
            }

            // Lida com a ativação e desativação das asas
            if (!grounded && jumpbtndown && !wing.activeSelf)
            {
                wing.SetActive(true);
                jumpbtndown = false;
                return;
            }
            if (!grounded && jumpbtndown && wing.activeSelf)
            {
                wing.SetActive(false);
            }
        }

        // Controla o impulso do pulo
        if (jumpbtn)
        {
            jumptime -= Time.fixedDeltaTime;
            jumptime = Mathf.Clamp01(jumptime);
            rdb.AddForce(jumpspeed * jumptime * Vector3.up);
        }

        jumpbtndown = false;
    }

    private void GroundControl()
    {
        // Calcula a direção relativa de movimento com base na câmera
        Vector3 relativedirection = currentCamera.transform.TransformVector(movaxis).normalized;
        relativedirection = new Vector3(relativedirection.x, jumptime, relativedirection.z);
        Vector3 relativeDirectionWOy = new Vector3(relativedirection.x, 0, relativedirection.z); 
        if (grounded)
        {
            rdb.velocity = new Vector3(relativedirection.x * 5, rdb.velocity.y, relativedirection.z * 5);
        }
        else
        {
            rdb.AddForce(new Vector3(relativedirection.x * 500, 0, relativedirection.z * 500));
        }


        if (!joint)
        {
            Quaternion rottogo = Quaternion.LookRotation(relativeDirectionWOy * 2 + transform.forward);
            transform.rotation = Quaternion.Lerp(transform.rotation, rottogo, Time.fixedDeltaTime * 50);
        }
        //boiar
        if (transform.position.y < AlturaAgua)
        {
            rdb.AddForce(Vector3.up* 1200);
            rdb.drag = 4;
        }
        else
        {
            rdb.drag = 1;
        }

    }
      
           

    // Método OnAnimatorIK é chamado para calcular a cinemática inversa (IK)
    void OnAnimatorIK()
    {
        // Código para controlar as mãos do personagem enquanto voa
        if (wing.activeSelf)
        {
            // Código para controlar a posição e rotação das mãos do personagem
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

        // Lida com a interação do personagem com objetos próximos
        if (closeThing)
        {
            // Código para calcular a direção e peso das mãos do personagem ao interagir com objetos próximos

            //calcula a direcao do ponto de toque para a personagem
            Vector3 handDirection = closeThing.transform.position - transform.position;
            //verifica se o objeto ta na frente do personagem >0
            float lookto = Vector3.Dot(handDirection.normalized, transform.forward);
            //calcula e interpola o peso pela formula (l*3)/distancia^3
            weight = Mathf.Lerp(weight, (lookto * 3 / (Mathf.Pow(handDirection.magnitude, 3))), Time.fixedDeltaTime * 2);

            anim.SetIKPositionWeight(AvatarIKGoal.RightHand, weight);
            anim.SetIKRotationWeight(AvatarIKGoal.RightHand, weight);
            anim.SetIKPosition(AvatarIKGoal.RightHand, closeThing.transform.position + transform.right * 0.1f);
            anim.SetIKRotation(AvatarIKGoal.RightHand, Quaternion.identity);

            anim.SetIKPositionWeight(AvatarIKGoal.LeftHand, weight);
            anim.SetIKRotationWeight(AvatarIKGoal.LeftHand, weight);
            anim.SetIKPosition(AvatarIKGoal.LeftHand, closeThing.transform.position - transform.right * 0.1f);
            anim.SetIKRotation(AvatarIKGoal.LeftHand, Quaternion.identity);

            // Verifica se o botão de ataque foi pressionado
            if (Input.GetButtonDown("Fire1"))
            {
                // Código para criar ou destruir o FixedJoint para segurar objetos
            }

            // Verifica se a inportancia é menor ou igual a zero
            if (weight <= 0)
            {
                Destroy(closeThing);
                if (joint)
                {
                    Destroy(joint);
                    return;
                }
            }
        }
    }

    // Método OnCollisionEnter é chamado quando o personagem colide com outro objeto
    private void OnCollisionEnter(Collision collision)
    {
        wing.SetActive(false);

        if (collision.transform.position.y > transform.position.y + .05f)
        {
            if (!closeThing)
                closeThing = new GameObject("Handpos");

            weight = 0;
            closeThing.transform.parent = collision.gameObject.transform;
            closeThing.transform.position = collision.GetContact(0).point;
        }
    }

    // Método OnCollisionExit é chamado quando o personagem deixa de colidir com outro objeto
    private void OnCollisionExit(Collision collision)
    {
        // Não há código adicional necessário aqui
    }

    void FlyControl()
    {
        rdb.drag = 0.4f;
        float velocity = Mathf.Abs(rdb.velocity.x) + Mathf.Abs(rdb.velocity.z);
        velocity = Mathf.Clamp(velocity, 0, 10);

        rdb.AddRelativeForce(new Vector3(0, velocity * 50, 500));

        Vector3 movfly = new Vector3(Vector3.forward.x * flyvelocity, 0, Vector3.forward.z * flyvelocity);

        float angz = Vector3.Dot(transform.right, Vector3.up);
        float angx = Vector3.Dot(transform.forward, Vector3.up);
        movfly = new Vector3(movaxis.z + angx * 2, -angz, -movaxis.x - angz);

        transform.Rotate(movfly);

        wing.transform.localRotation = Quaternion.Euler(0, 0, angz * 50);


        flyvelocity -= angx * 0.01f;
        flyvelocity = Mathf.Lerp(flyvelocity, 3, Time.fixedDeltaTime);
        flyvelocity = Mathf.Clamp(flyvelocity, 0, 5);
    }
}
