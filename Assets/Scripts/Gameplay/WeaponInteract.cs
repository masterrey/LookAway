using UnityEngine;

public class WeaponInteract : MonoBehaviour
{
    public Transform rightHand;
    public Transform leftHand;
    public GameObject itemReference;
    GameObject weaponInstance;
    public MenuGame menuGame;

    public MoveChanPhisical moveChanPhisical;

    public Animator animator;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        // Find the MenuGame script in the scene
        menuGame = FindObjectOfType<MenuGame>();
        moveChanPhisical = GetComponent<MoveChanPhisical>();
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
        if (itemReference != null) {
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
        if (itemReference == null)
        {
            Debug.LogError("Weapon prefab is not assigned.");
            return;
        }
        if (!fromInventory)
        menuGame.AddItemToInventory(itemReference.GetComponent<ItemRef>().item, 1);

        if (weaponInstance == null)
        {
            weaponInstance = itemReference;
            weaponInstance.transform.SetParent(rightHand);
            weaponInstance.transform.localPosition = Vector3.zero;
            weaponInstance.transform.localRotation = Quaternion.identity;
            weaponInstance.layer = LayerMask.NameToLayer("Player"); // Set the layer to "Weapon"
            //weaponInstance.GetComponent<Rigidbody>().isKinematic = true; // Make the weapon kinematic
            //weaponInstance.GetComponent<Collider>().enabled = false; // Disable the collider
            //attach the weapon to the right hand rigbody using fixed joint
            FixedJoint fixedJoint = weaponInstance.AddComponent<FixedJoint>();
            fixedJoint.connectedBody = rightHand.GetComponent<Rigidbody>();
            fixedJoint.connectedBody.collisionDetectionMode = CollisionDetectionMode.Continuous;
            // Set the weapon to be a child of the right hand
            animator.SetLayerWeight(animator.GetLayerIndex("Sword"), 1); // Set the weapon layer to be active
            animator.SetBool("Weapon", true); // Set the equipped state to true
            moveChanPhisical.haveWeapons = true; // Set the haveWeapons state to true
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
            itemReference = Instantiate(item.prefab);
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
            //remove the fixed joint if it exists
            FixedJoint fixedJoint = weaponInstance.GetComponent<FixedJoint>();
            fixedJoint.connectedBody = weaponInstance.GetComponent<Rigidbody>();
            if (fixedJoint != null)
            {
                Destroy(fixedJoint);
            }
            animator.SetLayerWeight(animator.GetLayerIndex("Sword"), 0); // Set the weapon layer to be inactive
            animator.SetBool("Weapon", false); // Set the equipped state to false
            menuGame.RemoveItemFromInventory(weaponInstance.GetComponent<ItemRef>().item, 1);
            moveChanPhisical.haveWeapons = false; // Set the haveWeapons state to false
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
            moveChanPhisical.haveWeapons = false; // Set the haveWeapons state to false
        }
    }

    public void StoreItem(Item item)
    {
        if (item == null)
        {
            Debug.LogError("Item is not assigned.");
            return;
        }
        menuGame.AddItemToInventory(itemReference.GetComponent<ItemRef>().item, 1);
        Destroy(itemReference);

    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Weapon"))
        {
            itemReference = other.gameObject;
            EquipWeapon();
        }
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.CompareTag("Weapon"))
        {
            itemReference = collision.gameObject;
            EquipWeapon();
        }
    
        if (collision.gameObject.CompareTag("Item"))
        {
            itemReference = collision.gameObject;
            StoreItem(itemReference.GetComponent<ItemRef>().item);
        }
    }
}


