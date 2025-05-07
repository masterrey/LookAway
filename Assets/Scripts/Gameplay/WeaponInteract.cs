using UnityEngine;

public class WeaponInteract : MonoBehaviour
{
    public Transform rightHand;
    public Transform leftHand;
    public GameObject weaponPrefab;
    GameObject weaponInstance;
    public MenuGame menuGame;


    public Animator animator;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        // Find the MenuGame script in the scene
        menuGame = FindObjectOfType<MenuGame>();
        if (menuGame == null)
        {
            Debug.LogError("MenuGame script not found in the scene.");
        }
        // Find the Animator component in the player object
        animator = GetComponent<Animator>();
        if (animator == null)
        {
            Debug.LogError("Animator component not found on this GameObject.");
        }

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
    public void EquipWeapon(bool fromInventory = false)
    {
        // Check if the weaponPrefab is not null and if the weaponInstance is null
        if (weaponPrefab == null)
        {
            Debug.LogError("Weapon prefab is not assigned.");
            return;
        }
        if (!fromInventory)
        menuGame.AddItemToInventory(weaponPrefab.GetComponent<ItemRef>().item, 1);


        if (weaponInstance == null)
        {
            weaponInstance = weaponPrefab;
            weaponInstance.transform.SetParent(rightHand);
            weaponInstance.transform.localPosition = Vector3.zero;
            weaponInstance.transform.localRotation = Quaternion.identity;
            weaponInstance.GetComponent<Rigidbody>().isKinematic = true; // Make the weapon kinematic
            weaponInstance.GetComponent<Collider>().enabled = false; // Disable the collider
            animator.SetLayerWeight(animator.GetLayerIndex("Sword"), 1); // Set the weapon layer to be active
            animator.SetBool("Weapon", true); // Set the equipped state to true
        }
    }

    public void EquipWeaponFromInventory(Item item)
    {
        // Check if the weaponPrefab is not null and if the weaponInstance is null
        if (item == null)
        {
            Debug.LogError("Item is not assigned.");
            return;
        }
        if (weaponInstance == null)
        {
            weaponPrefab = Instantiate(item.prefab);
            EquipWeapon(true);
        }
    }

    // This method is called when the player presses the "Unequip" button
    public void DropWeapon()
    {
        if (weaponInstance != null)
        {
            //drop the weapon
            weaponInstance.transform.SetParent(null);
            weaponInstance.GetComponent<Rigidbody>().isKinematic = false;
            weaponInstance.GetComponent<Collider>().enabled = true; // Enable the collider
            animator.SetLayerWeight(animator.GetLayerIndex("Sword"), 0); // Set the weapon layer to be inactive
            animator.SetBool("Weapon", false); // Set the equipped state to false
            menuGame.RemoveItemFromInventory(weaponInstance.GetComponent<ItemRef>().item, 1);
        }
    }
    public void UnequipWeapon()
    {
        if (weaponInstance != null)
        {
            //unequip the weapon
            Destroy(weaponInstance);
            animator.SetLayerWeight(animator.GetLayerIndex("Sword"), 0); // Set the weapon layer to be inactive
            animator.SetBool("Weapon", false); // Set the equipped state to false
            weaponInstance = null;
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


