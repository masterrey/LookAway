using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

public class AIBerserk : State
{
    NavMeshAgent agent;
    public Transform target;

    private void Awake()
    {
        agent = GetComponent<NavMeshAgent>();

    }
    public override void FixedUpdateState()
    {
        Debug.Log("Berserk");

        float speed = agent.velocity.magnitude;
        animator.SetFloat("Speed", speed);
        animator.SetFloat("Turn", Vector3.Dot(agent.velocity.normalized, transform.forward));
        agent.SetDestination(target.position);
    }
}
