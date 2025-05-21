using UnityEngine;

public class WeaponAnimationInterruption : MonoBehaviour
{
  public Animator animator;

    private void OnCollisionEnter(Collision collision)
    {
        Debug.Log("Collision detected with: " + collision.gameObject.name);
        animator.SetTrigger("WeaponHit");
        //stop the animation
        animator.playbackTime = 0;
    }


}
