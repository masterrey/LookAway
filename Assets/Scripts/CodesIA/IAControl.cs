using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

public class IAControl : MonoBehaviour
{
    NavMeshAgent agent;
    public Transform target;
    Animator anim;

    enum State
    {
        IDLE,
        PATROL,
        BERSERK
    }
    [SerializeField]
    State state = State.IDLE;
    State oldState;

    // Start is called before the first frame update
    void Start()
    {
        agent = GetComponent<NavMeshAgent>();
        StartCoroutine(IDLE());
        anim = GetComponent<Animator>();
        state = State.IDLE;
    }

    // Update is called once per frame
    void Update()
    {
        if (oldState != state)
        {
            oldState = state;
            switch (state)
            {
                case State.IDLE:
                    StartCoroutine(IDLE());
                    break;
                case State.PATROL:
                    StartCoroutine(Patrol());
                    break;
                case State.BERSERK:
                    StartCoroutine(Berserk());
                    break;
            }
        }
    }


    IEnumerator Berserk()
    {
        Debug.Log("Berserk");
        while (target && state == State.BERSERK)
        {
            anim.SetFloat("Speed", agent.velocity.magnitude);
            anim.SetFloat("Turn", Vector3.Dot(agent.velocity.normalized, transform.forward));
            agent.SetDestination(target.position);
            yield return new WaitForSeconds(1);
        }
        state= State.IDLE;
    }

    IEnumerator IDLE()
    {
        Debug.Log("IDLE");
        while (!target && state == State.IDLE)
        {
            
            yield return new WaitForSeconds(5);
            state = State.PATROL;
        }
    }

    IEnumerator Patrol()
    {
        Debug.Log("Patrol");
        while (!target && state == State.PATROL)
        {
            yield return new WaitForSeconds(1);
            RandomPlacesToGO();
            yield return new WaitForSeconds(5);
        }
      
    }


    void RandomPlacesToGO()
    {
        Vector3 randomDirection = Random.insideUnitSphere * 10;
        randomDirection += transform.position;
        NavMeshHit hit;
        NavMesh.SamplePosition(randomDirection, out hit, 10, 1);
        Vector3 finalPosition = hit.position;
        agent.SetDestination(finalPosition);
    }


    public void OnTriggerEnter(Collider other)
    {
        if (other.gameObject.CompareTag("Player"))
        {
            target=other.transform;
            StopAllCoroutines();
            state = State.BERSERK;
        }
    }
    

    public void OnTriggerExit(Collider other)
    {
        if (other.gameObject.CompareTag("Player"))
        {
            target = null;
            
        }
    }
}
