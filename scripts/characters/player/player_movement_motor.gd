class_name PlayerMovementMotor
extends Node

@export var movement_definition: PlayerMovementDefinition

var slide_direction: Vector3 = Vector3.ZERO
var slide_time_remaining: float = 0.0
var slide_cooldown_remaining: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_time_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0


func tick_timers(delta: float, is_on_floor: bool) -> void:
	slide_cooldown_remaining = maxf(0.0, slide_cooldown_remaining - delta)
	if slide_time_remaining > 0.0:
		slide_time_remaining = maxf(0.0, slide_time_remaining - delta)

	if is_on_floor:
		_coyote_time_remaining = _movement().coyote_time
	else:
		_coyote_time_remaining = maxf(0.0, _coyote_time_remaining - delta)

	if _jump_buffer_remaining > 0.0:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)


func buffer_jump() -> void:
	_jump_buffer_remaining = _movement().jump_buffer_time


func consume_jump_if_allowed(body: CharacterBody3D) -> bool:
	if _jump_buffer_remaining <= 0.0 or _coyote_time_remaining <= 0.0:
		return false

	body.velocity.y = _movement().jump_velocity
	_jump_buffer_remaining = 0.0
	_coyote_time_remaining = 0.0
	return true


func apply_gravity(body: CharacterBody3D, delta: float) -> void:
	if body.is_on_floor() and body.velocity.y <= 0.0:
		body.velocity.y = 0.0
		return

	body.velocity.y -= _gravity * _movement().gravity_multiplier * delta


func apply_ground_motion(
	body: CharacterBody3D,
	input_vector: Vector2,
	target_speed: float,
	delta: float,
	control_multiplier: float = 1.0
) -> void:
	var direction: Vector3 = direction_from_input(body, input_vector)
	var target_velocity: Vector3 = direction * target_speed
	var current_horizontal: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	var rate: float = _movement().acceleration if direction != Vector3.ZERO else _movement().deceleration
	var next_horizontal: Vector3 = current_horizontal.move_toward(target_velocity, rate * control_multiplier * delta)

	body.velocity.x = next_horizontal.x
	body.velocity.z = next_horizontal.z


func start_slide(body: CharacterBody3D, input_vector: Vector2) -> bool:
	if slide_cooldown_remaining > 0.0 or slide_time_remaining > 0.0:
		return false

	slide_direction = direction_from_input(body, input_vector)
	if slide_direction == Vector3.ZERO:
		slide_direction = -body.global_transform.basis.z.normalized()

	slide_time_remaining = _movement().slide_duration
	slide_cooldown_remaining = _movement().slide_cooldown
	return true


func apply_slide(body: CharacterBody3D, speed_multiplier: float = 1.0) -> void:
	var horizontal: Vector3 = slide_direction * _movement().slide_speed * maxf(0.0, speed_multiplier)
	body.velocity.x = horizontal.x
	body.velocity.z = horizontal.z


func is_sliding() -> bool:
	return slide_time_remaining > 0.0


func direction_from_input(body: CharacterBody3D, input_vector: Vector2) -> Vector3:
	if input_vector == Vector2.ZERO:
		return Vector3.ZERO

	var basis: Basis = body.global_transform.basis
	var direction: Vector3 = (basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	direction.y = 0.0
	return direction.normalized()


func _movement() -> PlayerMovementDefinition:
	if movement_definition != null:
		return movement_definition

	var fallback: PlayerMovementDefinition = PlayerMovementDefinition.new()
	movement_definition = fallback
	return fallback
