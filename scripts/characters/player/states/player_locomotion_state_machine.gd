class_name PlayerLocomotionStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const STATE_DISABLED: StringName = &"disabled"
const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_SPRINT: StringName = &"sprint"
const STATE_SLIDE: StringName = &"slide"
const STATE_JUMP: StringName = &"jump"
const STATE_FALL: StringName = &"fall"

@export var movement_definition: PlayerMovementDefinition
@export var motor_path: NodePath = ^"../../MovementMotor"
@export var stamina_path: NodePath = ^"../../Components/StaminaComponent"

@onready var motor: PlayerMovementMotor = get_node(motor_path)
@onready var stamina: StaminaComponent = get_node(stamina_path)

var current_state: StringName = STATE_IDLE


func physics_update(body: CharacterBody3D, input_reader: PlayerInputReader, constraints: Dictionary, delta: float) -> void:
	if constraints.get("movement_disabled", false):
		_transition_to(STATE_DISABLED)
		body.velocity.x = move_toward(body.velocity.x, 0.0, _movement().deceleration * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, _movement().deceleration * delta)
		return

	var input_vector: Vector2 = input_reader.move_vector
	var can_use_mobility: bool = not constraints.get("mobility_blocked", false)
	var watch_active: bool = constraints.get("watch_active", false)
	var jumped: bool = false

	if input_reader.consume_jump() and can_use_mobility and not watch_active:
		motor.buffer_jump()

	if can_use_mobility and not watch_active:
		jumped = motor.consume_jump_if_allowed(body)

	if jumped:
		_transition_to(STATE_JUMP)
	elif not body.is_on_floor() and body.velocity.y < 0.0:
		_transition_to(STATE_FALL)

	if input_reader.consume_slide() and can_use_mobility and not watch_active and body.is_on_floor():
		if stamina == null or stamina.consume(_movement().slide_stamina_cost):
			if motor.start_slide(body, input_vector):
				_transition_to(STATE_SLIDE)

	if motor.is_sliding() and can_use_mobility and not watch_active:
		motor.apply_slide(body)
		_transition_to(STATE_SLIDE)
		return

	var target_speed: float = _movement().walk_speed
	var can_sprint: bool = input_reader.wants_sprint and input_vector != Vector2.ZERO and body.is_on_floor() and can_use_mobility and not watch_active
	if watch_active:
		target_speed = _movement().watch_walk_speed
	elif can_sprint and _consume_sprint_stamina(delta):
		target_speed = _movement().sprint_speed

	var control_multiplier: float = 1.0 if body.is_on_floor() else _movement().air_control_multiplier
	motor.apply_ground_motion(body, input_vector, target_speed, delta, control_multiplier)

	if not body.is_on_floor():
		if body.velocity.y >= 0.0:
			_transition_to(STATE_JUMP)
		else:
			_transition_to(STATE_FALL)
	elif input_vector == Vector2.ZERO:
		_transition_to(STATE_IDLE)
	elif is_equal_approx(target_speed, _movement().sprint_speed):
		_transition_to(STATE_SPRINT)
	else:
		_transition_to(STATE_WALK)


func _consume_sprint_stamina(delta: float) -> bool:
	var cost: float = _movement().sprint_stamina_per_second * delta
	return stamina == null or stamina.consume(cost)


func _transition_to(next_state: StringName) -> void:
	if next_state == current_state:
		return

	var previous_state: StringName = current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)


func _movement() -> PlayerMovementDefinition:
	if movement_definition != null:
		return movement_definition
	if motor != null and motor.movement_definition != null:
		return motor.movement_definition

	var fallback: PlayerMovementDefinition = PlayerMovementDefinition.new()
	movement_definition = fallback
	return fallback
