using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MAterialChange : MonoBehaviour
{
    public Material material;
    public MeshRenderer meshRenderer;
    // Start is called before the first frame update
    void Start()
    {
        meshRenderer = GetComponent<MeshRenderer>();
        material= meshRenderer.materials[1];
        
    }

    // Update is called once per frame
    void Update()
    {
        //rainbow color
        Color color = new Color(Random.Range(0,1f), Random.Range(0,1f), Random.Range(0,1f));
        material.color = color;

        
    }
}
