using System.Collections;
using UnityEngine;

public class Damage : MonoBehaviour
{
    public MeshRenderer meshRenderer;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        // Find the MeshRenderer component in the player object
        meshRenderer = GetComponent<MeshRenderer>();
        if (meshRenderer == null)
        {
            Debug.LogError("MeshRenderer component not found on this GameObject.");
        }
        //create a instnce of material
        Material material = new Material(meshRenderer.material);
        // Set the material to the meshRenderer
        meshRenderer.material = material;

    }

    // Update is called once per frame
    void Update()
    {
        
    }
    // Function to get damage from a weapon
    public void GetDamage(int damage)
    {
        // Apply damage to the player or enemy
        Debug.Log("Damage taken: " + damage);
    }

    private IEnumerator OnCollisionEnter(Collision collision)
    {
        float velocityMagnitude = collision.relativeVelocity.magnitude;
        // Check if the object collided with is a weapon
        if (collision.gameObject.CompareTag("Weapon") && velocityMagnitude > 5)
        {
            if (meshRenderer)
            {
                // Change the color of the meshRenderer to red
                meshRenderer.material.color = Color.red;
            }
            
            // Get the damage from the weapon
            int damage = (int)velocityMagnitude + 1; //collision.gameObject.GetComponent<Weapon>().damage;
            // Call the GetDamage function
            GetDamage(damage);
            // Wait for 0.5 seconds
            yield return new WaitForSeconds(0.1f);
            // Reset the color of the meshRenderer to white
            if (meshRenderer)
            {
                meshRenderer.material.color = Color.white;
            }
        }
    }

}
