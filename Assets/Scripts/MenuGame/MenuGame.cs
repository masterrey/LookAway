using System.Collections.Generic;
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class MenuGame : MonoBehaviour
{
    [SerializeField]
    private GameObject menuGame;
    [SerializeField]
    private GameObject menuGamePause;
    [SerializeField]
    private GameObject menuGameInventory;
    [SerializeField]
    private GameObject menuGameSettings;
    // invantario em scriptable object
    public Inventory inventory;
    // Referência ao TextMeshProUGUI para exibir o debug do inventário
    public TextMeshProUGUI inventoryText;
    // Variável para controlar o estado de pausa do jogo
    bool paused = false;
    // Prefab do slot de inventário
    public GameObject inventorySlotPrefab;
    // Referência ao painel do inventário
    public Transform inventoryPanel;

    public GameObject lifePanel;
    public Transform[] lifeContaines;

    public Health health;

    // Lista para armazenar os slots de inventário
    private List<GameObject> slots = new List<GameObject>();

    // Referência ao WeaponInteract do jogador
    [SerializeField]
    WeaponInteract weaponInteract;


    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        menuGame.SetActive(true);
        menuGamePause.SetActive(false);

        inventoryText.text = "Inventário:\n";
        foreach (var slot in inventory.items)
        {
            inventoryText.text += $"{slot.item.itemName} x{slot.quantity}\n";
        }
        // Verifica se o WeaponInteract já foi atribuído
        if (weaponInteract == null)
        {
            //busca o player e pega o weaponInteract
            GameObject player = GameObject.FindGameObjectWithTag("Player");
            if (player != null)
            {
                health = player.GetComponent<Health>();
                weaponInteract = player.GetComponent<WeaponInteract>();
                if (weaponInteract == null)
                {
                    Debug.LogError("WeaponInteract component not found on the player.");
                }
                // Verifica se o Health já foi atribuído
                if (health == null)
                {
                    Debug.LogError("Health component not found on the player.");
                }
            }
            else
            {
                Debug.LogError("Player object not found in the scene.");
            }
        }

        // Verifica se o life já foi atribuído
        // Atualiza a barra de vida
        if (lifePanel != null )
        {
            lifePanel.SetActive(true);
            lifeContaines = lifePanel.GetComponentsInChildren<Transform>(true).Skip(1).ToArray();

            for (int i = 0; i < lifeContaines.Length; i++)
            {
                lifeContaines[i].gameObject.SetActive(false);
            }
        }

        // Atualiza a barra de vida
        Invoke("LiveUpdate", 2f);
    }

    // Update is called once per frame
    void Update()
    {

        if (Input.GetKeyDown(KeyCode.Escape))
        {
            if (menuGamePause.activeSelf)
            {
                menuGamePause.SetActive(false);
                menuGame.SetActive(true);
                Time.timeScale = 1f;
                paused = false;
            }
            else
            {
                menuGame.SetActive(false);
                menuGamePause.SetActive(true);
                Time.timeScale = 0f;
                paused = true;
            }
        }

        if (paused)
        {
            // Apenas para testes
            if (Input.GetKeyDown(KeyCode.E))
            {
                // Adicionar item para teste

                AddItemToInventory(inventory.items[0].item, 1);
            }

            if (Input.GetKeyDown(KeyCode.R))
            {
                // Remover item para teste
                RemoveItemFromInventory(inventory.items[0].item, 1);
            }

            inventoryText.text = "Inventário:\n";
            foreach (var slot in inventory.items)
            {
                inventoryText.text += $"{slot.item.itemName} x{slot.quantity}\n";
            }
        }
    }

    public void LiveUpdate()
    {
        // Atualiza a barra de vida
        if (lifePanel != null)
        {
            // Verifica se o Health já foi atribuído
            if (health == null)
            {
                Debug.LogError("Health component not found on the player.");
                return;
            }
            lifePanel.SetActive(true);
            Debug.Log($"Vida Atual: {health.currentHealth}");
            for (int i = 0; i < lifeContaines.Length; i++)
            {

                if (i < health.currentHealth)
                {
                    lifeContaines[i].gameObject.SetActive(true);
                }
                else
                {
                    lifeContaines[i].gameObject.SetActive(false);
                }
            }
        }



    }



    public void AddItemToInventory(Item item, int quantity)
    {
        inventory.AddItem(item, quantity);
        RefreshInventory();
        Debug.Log($"Adicionado: {item.itemName} x{quantity}");
    }

    public void RemoveItemFromInventory(Item item, int quantity)
    {
        inventory.RemoveItem(item, quantity);
        RefreshInventory();
        Debug.Log($"Removido: {item.itemName} x{quantity}");
    }

    private void OnEnable()
    {
        RefreshInventory();
    }


    public void RefreshInventory()
    {
        // Limpa os slots anteriores
        foreach (var slot in slots)
        {
            Destroy(slot);
        }
        slots.Clear();

        // Cria novos slots
        foreach (var inventorySlot in inventory.items)
        {
            GameObject slot = Instantiate(inventorySlotPrefab, inventoryPanel);
            Image icon = slot.transform.Find("Icon").GetComponent<Image>();
            TextMeshProUGUI quantityText = slot.transform.GetComponentInChildren<TextMeshProUGUI>();
      
            icon.sprite = inventorySlot.item.icon;
            quantityText.text = inventorySlot.quantity > 1 ? inventorySlot.quantity.ToString() : "";
            Button button = slot.GetComponent<Button>();
            button.onClick.AddListener(() => ItemPressed(inventorySlot.item));

            slots.Add(slot);
        }

    }

    public void ItemPressed(Item item)
    {
        weaponInteract.EquipWeaponFromInventory(item);
        Debug.Log($"Item pressionado: {item.itemName}");
    }
    
}
