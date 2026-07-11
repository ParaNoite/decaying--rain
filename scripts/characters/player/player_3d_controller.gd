class_name Player3DController
extends CharacterBody3D

@export_range(0.1, 20.0, 0.1) var move_speed: float = 5.0
@export_range(0.1, 20.0, 0.1) var sprint_speed: float = 8.0
@export_range(0.001, 0.02, 0.0005) var mouse_sensitivity: float = 0.0025
@export_range(0.0, 100.0, 1.0) var sprint_stamina_per_second: float = 16.0
@export_range(0.0, 100.0, 1.0) var slide_stamina_cost: float = 25.0

@onready var head: Node3D = %Head
@onready var stamina: StaminaComponent = %StaminaComponent

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _slide_cooldown_remaining: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("slide"):
		_try_slide()


func _physics_process(delta: float) -> void:
	_slide_cooldown_remaining = maxf(0.0, _slide_cooldown_remaining - delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_speed: float = _get_target_speed(delta)

	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed

	move_and_slide()


func _rotate_camera(relative_motion: Vector2) -> void:
	rotate_y(-relative_motion.x * mouse_sensitivity)
	head.rotate_x(-relative_motion.y * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))


func _get_target_speed(delta: float) -> float:
	if Input.is_action_pressed("sprint") and stamina.consume(sprint_stamina_per_second * delta):
		return sprint_speed
	return move_speed


func _try_slide() -> void:
	if _slide_cooldown_remaining > 0.0:
		return
	if not stamina.consume(slide_stamina_cost):
		return

	_slide_cooldown_remaining = 1.0
	var forward: Vector3 = -transform.basis.z.normalized()
	velocity.x = forward.x * sprint_speed * 1.5
	velocity.z = forward.z * sprint_speed * 1.5


func apply_damage(amount: float) -> void:
	var health := %HealthComponent as HealthComponent
	if health != null:
		health.take_damage(amount)
