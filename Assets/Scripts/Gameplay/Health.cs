using UnityEngine;

public class Health : MonoBehaviour
{
    public int maxHealth = 3;
    public int currentHealth;
    public bool isDead = false;
    public GameObject deathEffect;
    public GameObject respawnEffect;
    public GameObject healEffect;
    public Vector3 respawnPoint;
    public float respawnTime = 5f;
    public Animator animator;
    public MoveChanPhisical moveChanPhisical;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        currentHealth = maxHealth;
        respawnPoint = transform.position;

        // Check if the player has a MoveChanPhisical component
        moveChanPhisical = GetComponent<MoveChanPhisical>();
        if (moveChanPhisical != null)
        {
            animator = moveChanPhisical.GetComponent<Animator>();

        }

    }

    //save the player position in the respawn point
    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("RespawnPoint"))
        {
            respawnPoint = other.transform.position;
        }
    }

    public void TakeDamage(int damage)
    {
        animator.SetTrigger("Hit");
        currentHealth -= damage;
        if (currentHealth <= 0)
        {
            Die();
        }
    }

    public void Heal(int healAmount)
    {
        animator.SetTrigger("Heal");
        //healEffect.SetActive(true);

        currentHealth += healAmount;

        if (currentHealth > maxHealth)
        {
            currentHealth = maxHealth;
        }
    }

    public void Die()
    {
        animator.SetBool("Die", true);
        isDead = true;
        //Instantiate(deathEffect, transform.position, Quaternion.identity);
        gameObject.SetActive(false);
        Invoke("Respawn", respawnTime);
    }

    public void Respawn()
    {
        animator.SetBool("Die", false);
        isDead = false;
        currentHealth = maxHealth;
        transform.position = respawnPoint;
        //Instantiate(respawnEffect, transform.position, Quaternion.identity);
        gameObject.SetActive(true);
    }

}
