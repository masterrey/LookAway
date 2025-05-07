using UnityEngine;

[CreateAssetMenu(fileName = "Item", menuName = "Inventory/Item")]
public class Item : ScriptableObject
{
    public string itemName;
    public Sprite icon;
    public string description;
    public GameObject prefab;
    public bool isStackable = true;
    public int maxStack = 99;

    //check if prefab exist and if they have a script ItemRef with this reference
    public bool HasItemRef()
    {
        if (prefab != null)
        {
            ItemRef itemRef = prefab.GetComponent<ItemRef>();
            if (itemRef != null && itemRef.item == this)
            {
                return true;
            }
        }
        return false;
    }
}