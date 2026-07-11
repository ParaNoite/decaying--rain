extends CharacterBody3D

@export var move_speed: float = 5.0
@export var mouse_sensitivity: float = 0.0025

@onready var head: Node3D = $Head

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_ensure_input_action("move_forward", KEY_W)
	_ensure_input_action("move_back", KEY_S)
	_ensure_input_action("move_left", KEY_A)
	_ensure_input_action("move_right", KEY_D)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	move_and_slide()


func _ensure_input_action(action_name: StringName, keycode: Key) -> void:
	if InputMap.has_action(action_name):
		return

	InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)
