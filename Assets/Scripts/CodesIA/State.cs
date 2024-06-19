using System.Collections;
using System.Collections.Generic;
using System.Threading;
using UnityEngine;

public class State : MonoBehaviour
{
    public Animator animator;

    private void Start()
    {
        animator = GetComponent<Animator>();
    }

    IEnumerator UpdateState()
    {
        while (true)
        {
            FixedUpdateState();

            yield return new WaitForFixedUpdate();
        }
    }

    public virtual void FixedUpdateState()
    {
        
    }

    public virtual void EnterState()
    {
        Debug.Log("EnterState");
        StartCoroutine(UpdateState());
    }

    public virtual void ExitState()
    {
        StopCoroutine(UpdateState());
        Debug.Log("ExitState");
    }
   
}
