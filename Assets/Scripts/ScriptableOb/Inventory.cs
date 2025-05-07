using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New Inventory", menuName = "Inventory/Inventory")]
public class Inventory : ScriptableObject
{
    public List<InventorySlot> items = new List<InventorySlot>();

    public void AddItem(Item item, int quantity)
    {
        // Se o item já está no inventário, incrementa a quantidade
        InventorySlot slot = items.Find(i => i.item == item);

        if (slot != null && item.isStackable)
        {
            slot.quantity = Mathf.Min(slot.quantity + quantity, item.maxStack);
        }
        else
        {
            items.Add(new InventorySlot(item, quantity));
        }
    }

    public void RemoveItem(Item item, int quantity)
    {
        InventorySlot slot = items.Find(i => i.item == item);

        if (slot != null)
        {
            slot.quantity -= quantity;
            if (slot.quantity <= 0)
            {
                items.Remove(slot);
            }
        }
    }
}
