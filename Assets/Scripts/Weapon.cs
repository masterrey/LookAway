using UnityEngine;

public class Weapon : MonoBehaviour
{
    public Transform rightHand;
    public Transform leftHand;
    public GameObject weaponPrefab;
    GameObject weaponInstance;

    public Animator animator;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (weaponPrefab != null) {
            if (Input.GetKeyDown(KeyCode.Tab))
            {
                UnequipWeapon();
            }
        }

    }
    // This method is called when the player presses the "Equip" button
    public void EquipWeapon()
    {
        if (weaponInstance == null)
        {
            weaponInstance = weaponPrefab;
            weaponInstance.transform.SetParent(rightHand);
            weaponInstance.transform.localPosition = Vector3.zero;
            weaponInstance.transform.localRotation = Quaternion.identity;
            weaponInstance.GetComponent<Rigidbody>().isKinematic = true; // Make the weapon kinematic
            weaponInstance.GetComponent<Collider>().enabled = false; // Disable the collider
            animator.SetLayerWeight(animator.GetLayerIndex("Sword"), 1); // Set the weapon layer to be active
        }
    }
    // This method is called when the player presses the "Unequip" button
    public void UnequipWeapon()
    {
        if (weaponInstance != null)
        {
            //drop the weapon
            weaponInstance.transform.SetParent(null);
            weaponInstance.GetComponent<Rigidbody>().isKinematic = false;
            weaponInstance.GetComponent<Collider>().enabled = true; // Enable the collider
            animator.SetLayerWeight(animator.GetLayerIndex("Sword"), 0); // Set the weapon layer to be inactive
        }
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Weapon"))
        {
            weaponPrefab = other.gameObject;
            EquipWeapon();
        }
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.CompareTag("Weapon"))
        {
            weaponPrefab = collision.gameObject;
            EquipWeapon();
        }
    }
}


