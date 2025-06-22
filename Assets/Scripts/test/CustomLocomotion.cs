using UnityEngine;
using UnityEngine.XR;

[RequireComponent(typeof(CharacterController))]
public class AdvancedLocomotion : MonoBehaviour
{
    [Header("移动参数")]
    public float moveSpeed = 3f;
    public float gravity = -9.81f;
    public LayerMask groundLayer;

    [Header("控制器参数")]
    [Range(0.1f, 0.5f)] public float controllerRadius = 0.3f;
    [Range(1f, 2f)] public float controllerHeight = 1.8f;

    private CharacterController _controller;
    private Vector3 _velocity;
    private Transform _mainCamera;

    void Start()
    {
        InitializeController();
        _mainCamera = Camera.main.transform;
        
        
    }

    void InitializeController()
    {
        _controller = GetComponent<CharacterController>();
        _controller.radius = controllerRadius;
        _controller.height = controllerHeight;
        _controller.center = new Vector3(0, controllerHeight/2, 0);
        _controller.minMoveDistance = 0.001f;
        _controller.skinWidth = 0.02f;
        _controller.detectCollisions = true;
    }

    void Update()
    {
        HandleMovement();
        ApplyAdvancedGravity();
        Debug.Log($"接地状态: {Physics.CheckSphere(transform.position, 0.1f, groundLayer)}");
    }

    void HandleMovement()
    {
        Vector2 input = GetInput();
        Vector3 moveDirection = _mainCamera.forward * input.y + 
                               _mainCamera.right * input.x;
        moveDirection.y = 0;
        _controller.Move(moveDirection.normalized * (moveSpeed * Time.deltaTime));
    }

    Vector2 GetInput()
    {
        Vector2 input = Vector2.zero;
        InputDevices.GetDeviceAtXRNode(XRNode.LeftHand)
            .TryGetFeatureValue(CommonUsages.primary2DAxis, out Vector2 leftInput);
        InputDevices.GetDeviceAtXRNode(XRNode.RightHand)
            .TryGetFeatureValue(CommonUsages.primary2DAxis, out Vector2 rightInput);
        return Vector2.ClampMagnitude(leftInput + rightInput, 1f);
    }

    void ApplyAdvancedGravity()
    {
        float detectionRadius = controllerRadius * 0.95f;
        Vector3 detectionCenter = transform.position + _controller.center;
        float detectionDistance = (controllerHeight / 2) - controllerRadius + 0.1f;

        bool isGrounded = Physics.SphereCast(
            detectionCenter,
            detectionRadius,
            Vector3.down,
            out RaycastHit hit,
            detectionDistance,
            groundLayer
        );

        if (isGrounded)
        {
            _velocity.y = -2f;
            SnapToGround(hit.point.y);
        }
        else
        {
            _velocity.y += gravity * Time.deltaTime;
        }

        _controller.Move(_velocity * Time.deltaTime);
    }

    void SnapToGround(float groundHeight)
    {
        float targetY = groundHeight + _controller.skinWidth;
        transform.position = new Vector3(
            transform.position.x, 
            targetY + controllerHeight/2, 
            transform.position.z
        );
    }

    #if UNITY_EDITOR
    void OnDrawGizmos()
    {
        if (_controller != null)
        {
            Gizmos.color = Color.cyan;
            Vector3 center = transform.position + _controller.center;
            float distance = (_controller.height / 2) - _controller.radius + 0.1f;
            Gizmos.DrawWireSphere(center, _controller.radius);
            Gizmos.DrawLine(center, center + Vector3.down * distance);
        }
    }
    #endif
}