using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AIIDLE : State
{
    
    public override void EnterState()
    {
        base.EnterState();
        Debug.Log("EnterState AIIDLE");
        animator.SetFloat("Speed", 0);
    }
}
