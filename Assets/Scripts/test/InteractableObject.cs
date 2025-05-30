using UnityEngine;

public class InteractableObject : MonoBehaviour
{
    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Hand") && other.attachedRigidbody != null)
        {
            Debug.Log($"精确触碰：{name}");
            // 可视化调试
            Debug.DrawLine(transform.position, other.transform.position, Color.green, 1f);
        }
    }

    private void OnTriggerExit(Collider other)
    {   
        if (other.CompareTag("Hand"))
        {
            Debug.Log($"停止触碰物体：{name}");
        }
    }
}