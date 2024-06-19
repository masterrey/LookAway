using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;


public class StateController : MonoBehaviour
{

    public State[] states;

    public State currentState;
    State remainState;
    // Start is called before the first frame update
    void Start()
    {
        currentState.EnterState();
        remainState = currentState;
    }

    // Update is called once per frame
    void Update()
    {
        if(remainState!= currentState)
        {
            remainState.ExitState();
            currentState.EnterState();
            remainState = currentState;
        }
    }

    public void OnTriggerEnter(Collider other)
    {
        if (other.gameObject.CompareTag("Player"))
        {
           currentState = states[1];
           AIBerserk berserk = (AIBerserk)currentState;
           berserk.target = other.transform;
        }
    }

    public void OnTriggerExit(Collider other)
    {
        if (other.gameObject.CompareTag("Player"))
        {
            currentState = states[0];
        }
    }


}

