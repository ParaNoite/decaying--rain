class_name EnemyBase
extends CharacterBody3D

signal died(enemy_id: StringName, instance_id: int, wave_index: int)

enum State {
	CHASE,
	ATTACK,
	HURT,
	DEAD,
}

enum AttackKind {
	NORMAL,
	TRACKING,
	HEAVY,
}

@export var definition: EnemyDefinition
@export var target_group: StringName = &"player"
@export var wave_index: int = 0
@export_range(0.1, 100.0, 0.1) var fallback_move_speed: float = 3.5
@export_range(0.1, 20.0, 0.1) var attack_range: float = 1.5
@export_range(0.1, 100.0, 0.1) var attack_damage: float = 10.0
@export_range(0.1, 20.0, 0.1) var attack_cooldown_seconds: float = 1.5
@export_range(1.0, 60.0, 0.5) var knockback_deceleration: float = 18.0
@export_flags_3d_physics var attack_collision_mask: int = 3

@onready var health: HealthComponent = %HealthComponent
@onready var status_container: StatusContainer = %StatusContainer
@onready var visual_rig: EnemyVisualRig = %EnemyVisualRig
@onready var animation_controller: EnemyAnimationController = %EnemyAnimationController

var target: Node3D
var attack_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.45, 0.10, 0.04, 0.16)
var tracking_attack_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.45, 0.10, 0.04, 0.16)
var heavy_attack_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(1.0, 0.22, 0.10, 0.65)
var heavy_attack_pounce_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.22, 0.0, 0.32, 0.0)
var hurt_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.0, 0.08, 0.04, 0.26)
var death_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.0, 0.18, 0.12, 0.35)
var _state: State = State.CHASE
var _attack_cooldown_remaining: float = 0.0
var _heavy_attack_cooldown_remaining: float = 0.0
var _heavy_attack_decision_remaining: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_has_resolved: bool = false
var _heavy_attack_pounce_has_resolved: bool = false
var _active_attack_kind: AttackKind = AttackKind.NORMAL
var _heavy_attack_braking: bool = false
var _heavy_attack_brake_elapsed: float = 0.0
var _heavy_attack_brake_start_speed: float = 0.0
var _pending_attack_target: Node3D
var blood_hit_effect_count: int = 0
var last_blood_hit_position: Vector3 = Vector3.ZERO
var _knockback_velocity: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _buff_resolver: Node
var _damage_resolver: Node


func _ready() -> void:
	add_to_group("enemy")
	_buff_resolver = get_node_or_null("/root/BuffResolver")
	_damage_resolver = get_node_or_null("/root/DamageResolver")
	if _buff_resolver != null:
		_buff_resolver.call("bind_container", self, status_container)

	if definition != null:
		health.max_health = definition.max_health
		attack_damage = definition.attack_damage
		attack_range = definition.attack_range
		fallback_move_speed = definition.move_speed
		attack_cooldown_seconds = definition.attack_cooldown_seconds
		attack_timing = definition.attack_timing
		tracking_attack_timing = definition.tracking_attack_timing
		heavy_attack_timing = definition.heavy_attack_timing
		heavy_attack_pounce_timing = definition.heavy_attack_pounce_timing
		hurt_timing = definition.hurt_timing
		death_timing = definition.death_timing
		_reset_heavy_attack_decision_timer()
		_apply_target_tags()
		_apply_visual_definition()

	if health != null:
		health.set_health(health.max_health)
		if not health.died.is_connected(_on_health_died):
			health.died.connect(_on_health_died)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _attack_cooldown_remaining > 0.0:
		_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if _heavy_attack_cooldown_remaining > 0.0:
		_heavy_attack_cooldown_remaining = maxf(0.0, _heavy_attack_cooldown_remaining - delta)
	if _heavy_attack_decision_remaining > 0.0:
		_heavy_attack_decision_remaining = maxf(0.0, _heavy_attack_decision_remaining - delta)

	if _state == State.HURT:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, knockback_deceleration * delta)
		_sync_locomotion_animation()
		move_and_slide()
		if status_container == null or not status_container.has_status(&"staggered"):
			_knockback_velocity = Vector3.ZERO
			_transition_to(State.CHASE)
		return

	if _state == State.ATTACK:
		_update_attack(delta)
		_sync_locomotion_animation()
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		target = _find_target()

	if target == null:
		_transition_to(State.CHASE)
		velocity.x = 0.0
		velocity.z = 0.0
		_sync_locomotion_animation()
		move_and_slide()
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0

	var constraints: Dictionary = _buff_resolver.call("get_constraints", self) if _buff_resolver != null else {}
	if bool(constraints.get("movement_disabled", false)) or bool(constraints.get("combat_blocked", false)):
		velocity.x = 0.0
		velocity.z = 0.0
		_face_target(target)
		_sync_locomotion_animation()
		move_and_slide()
		return

	if _can_begin_heavy_attack(to_target.length()):
		velocity.x = 0.0
		velocity.z = 0.0
		_face_target(target)
		_begin_attack(target, AttackKind.HEAVY)
	elif to_target.length() <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_target(target)
		if _attack_cooldown_remaining <= 0.0:
			_begin_attack(target, _choose_close_attack_kind())
		else:
			_transition_to(State.CHASE)
	else:
		_transition_to(State.CHASE)
		var speed_multiplier: float = maxf(0.0, float(constraints.get("movement_speed_multiplier", 1.0)))
		var direction: Vector3 = to_target.normalized()
		velocity.x = direction.x * fallback_move_speed * speed_multiplier
		velocity.z = direction.z * fallback_move_speed * speed_multiplier
		_face_target(target)

	_sync_locomotion_animation()
	move_and_slide()


func receive_damage(data: DamageEventData) -> void:
	if _damage_resolver != null:
		_damage_resolver.call("resolve_damage", data, self)


func on_damage_resolved(result: DamageResolutionData) -> void:
	if not result.applied:
		return
	if _is_player_melee_damage(result):
		_spawn_blood_hit_effect(result.event)
	if _state == State.DEAD or result.event == null:
		return

	var stagger_duration: float = 0.0
	if result.event.stagger > 0.0:
		stagger_duration = maxf(0.35, result.event.stagger * 0.05)
	elif result.final_amount > 0.0:
		stagger_duration = hurt_timing.total_seconds()
	if stagger_duration <= 0.0:
		return

	var reaction: StringName = EnemyAnimationController.ACTION_HURT
	if result.event.source_tags.has(&"parry"):
		reaction = EnemyAnimationController.ACTION_PARRIED
	elif result.event.source_tags.has(&"shove"):
		reaction = EnemyAnimationController.ACTION_SHOVED

	_cancel_pending_attack()
	apply_status_by_id(&"staggered", stagger_duration, result.event.attacker_id)
	_apply_hit_knockback(result.event)
	_transition_to(State.HURT)
	if animation_controller != null:
		animation_controller.play_reaction(reaction, hurt_timing, stagger_duration)


func get_knockback_velocity() -> Vector3:
	return _knockback_velocity


func _apply_hit_knockback(data: DamageEventData) -> void:
	if data.knockback_force <= 0.0:
		_knockback_velocity = Vector3.ZERO
		return

	var direction: Vector3 = Vector3.ZERO
	var attacker: Object = instance_from_id(data.attacker_id) if data.attacker_id != 0 else null
	if attacker is Node3D:
		direction = global_position - (attacker as Node3D).global_position
	elif data.hit_position != Vector3.ZERO:
		direction = global_position - data.hit_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = global_basis.z
	_knockback_velocity = direction.normalized() * data.knockback_force


func _is_player_melee_damage(result: DamageResolutionData) -> bool:
	if result.event == null or result.final_amount <= 0.0:
		return false
	if not result.event.source_tags.has(&"melee"):
		return false
	var attacker: Object = instance_from_id(result.event.attacker_id)
	return attacker is Node and (attacker as Node).is_in_group("player")


func _spawn_blood_hit_effect(data: DamageEventData) -> void:
	var impact_position: Vector3 = data.hit_position if data.hit_position != Vector3.ZERO else global_position
	var spray_direction: Vector3 = global_position - impact_position
	var attacker: Object = instance_from_id(data.attacker_id)
	if attacker is Node3D:
		spray_direction = global_position - (attacker as Node3D).global_position
	MeleeImpactEffects.spawn_blood(get_tree().current_scene, impact_position, spray_direction)
	blood_hit_effect_count += 1
	last_blood_hit_position = impact_position


func get_health_component() -> HealthComponent:
	return health


func get_hit_zone_damage_multiplier(source_tags: Array[StringName]) -> float:
	if definition != null and source_tags.has(&"headshot"):
		return definition.headshot_damage_multiplier
	return 1.0


func get_status_container() -> StatusContainer:
	return status_container


func get_state() -> State:
	return _state


func get_active_attack_kind() -> AttackKind:
	return _active_attack_kind


func get_animation_controller() -> EnemyAnimationController:
	return animation_controller


func get_visual_rig() -> EnemyVisualRig:
	return visual_rig


func apply_status_by_id(status_id: StringName, duration_override: float = -1.0, source_id: int = 0) -> bool:
	return _buff_resolver != null and bool(
		_buff_resolver.call("apply_status_by_id", self, status_id, duration_override, source_id)
	)


func _find_target() -> Node3D:
	var tags: Array[StringName] = []
	if definition != null and not definition.preferred_target_tags.is_empty():
		tags = definition.preferred_target_tags
	else:
		tags = [target_group]

	for tag: StringName in tags:
		var chosen: Node3D = _nearest_target(get_tree().get_nodes_in_group(tag))
		if chosen != null:
			return chosen
	return null


func _nearest_target(nodes: Array[Node]) -> Node3D:
	var best_target: Node3D
	var best_distance: float = INF
	for node: Node in nodes:
		if not (node is Node3D):
			continue
		var candidate: Node3D = node as Node3D
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target


func _apply_target_tags() -> void:
	if definition == null:
		return

	if definition.can_attack_base:
		target_group = &"player"
	elif not definition.preferred_target_tags.is_empty():
		target_group = definition.preferred_target_tags[0]


func _apply_visual_definition() -> void:
	if definition == null or visual_rig == null:
		return
	visual_rig.build(definition)
	if animation_controller != null:
		animation_controller.configure(definition, visual_rig)


func _begin_attack(current_target: Node3D, attack_kind: AttackKind = AttackKind.NORMAL) -> void:
	_pending_attack_target = current_target
	_attack_elapsed = 0.0
	_attack_has_resolved = false
	_heavy_attack_pounce_has_resolved = false
	_active_attack_kind = attack_kind
	_heavy_attack_braking = false
	_heavy_attack_brake_elapsed = 0.0
	_heavy_attack_brake_start_speed = 0.0
	if attack_kind == AttackKind.HEAVY and definition != null:
		_heavy_attack_cooldown_remaining = definition.heavy_attack_cooldown_seconds
	_transition_to(State.ATTACK)
	if animation_controller != null:
		var is_ranged: bool = definition != null and definition.pressure_role == EnemyDefinition.PressureRole.RANGED_PRESSURE
		var style: StringName = EnemyAnimationController.ATTACK_STYLE_HEAVY if attack_kind == AttackKind.HEAVY else EnemyAnimationController.ATTACK_STYLE_DEFAULT
		animation_controller.play_attack(_current_attack_timing(), is_ranged, style, _current_attack_movement())


func _update_attack(delta: float) -> void:
	if _pending_attack_target != null and is_instance_valid(_pending_attack_target):
		_face_target(_pending_attack_target)

	var timing: ActionTimingDefinition = _current_attack_timing()
	# Retained with the disabled pounce-contact call below for quick restoration.
	# var previous_attack_elapsed: float = _attack_elapsed
	_attack_elapsed = minf(timing.total_seconds(), _attack_elapsed + maxf(0.0, delta))
	_update_attack_movement(timing, delta)
	# Intentionally disabled: restore this call to re-enable the optional pounce-contact hit window.
	# _try_resolve_heavy_pounce(previous_attack_elapsed)
	if not _attack_has_resolved and _attack_elapsed >= timing.impact_start_seconds():
		if _can_resolve_pending_attack():
			_try_attack(_pending_attack_target, 1.0, &"", _active_attack_kind == AttackKind.HEAVY and _heavy_attack_pounce_has_resolved)
			if _state != State.ATTACK:
				_attack_has_resolved = true
				return
		_attack_has_resolved = true
	if _attack_elapsed >= timing.total_seconds():
		_pending_attack_target = null
		_transition_to(State.CHASE)


func _update_attack_movement(timing: ActionTimingDefinition, delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if animation_controller != null:
		animation_controller.set_heavy_lunge_amount(0.0)
	var movement: AttackMovementDefinition = _current_attack_movement()
	if movement != null and movement.movement_source == AttackMovementDefinition.MovementSource.CONTROLLER:
		_update_controller_attack_movement(timing, movement, delta)
		return
	if _active_attack_kind != AttackKind.HEAVY or _pending_attack_target == null or not is_instance_valid(_pending_attack_target):
		return
	var phase: ActionTimingDefinition.Phase = timing.phase_at(_attack_elapsed)
	if phase not in [ActionTimingDefinition.Phase.WINDUP, ActionTimingDefinition.Phase.RELEASE]:
		return
	if _attack_elapsed < heavy_attack_pounce_timing.impact_start_seconds():
		return
	var offset: Vector3 = _pending_attack_target.global_position - global_position
	offset.y = 0.0
	var target_distance: float = offset.length()
	var terminal_stop_distance: float = maxf(0.55, attack_range * 0.38)
	if target_distance <= terminal_stop_distance:
		return
	var phase_progress: float = (_attack_elapsed - timing.phase_start_seconds(phase)) / maxf(0.001, timing.phase_duration(phase))
	var stagger_stride: float = 1.0 + absf(sin(phase_progress * PI * 3.0)) * 0.18
	var speed_scale: float = stagger_stride if phase == ActionTimingDefinition.Phase.WINDUP else lerpf(0.85, 0.30, phase_progress)
	var lunge_speed: float = definition.heavy_attack_lunge_speed if definition != null else fallback_move_speed
	var movement_speed: float = lunge_speed * speed_scale
	if not _heavy_attack_braking and definition != null and target_distance <= definition.heavy_attack_brake_distance:
		_heavy_attack_braking = true
		_heavy_attack_brake_elapsed = 0.0
		_heavy_attack_brake_start_speed = movement_speed
	if _heavy_attack_braking and definition != null:
		_heavy_attack_brake_elapsed += maxf(0.0, delta)
		var brake_progress: float = clampf(_heavy_attack_brake_elapsed / maxf(0.01, definition.heavy_attack_brake_seconds), 0.0, 1.0)
		var brake_blend: float = smoothstep(0.0, 1.0, brake_progress)
		movement_speed = lerpf(_heavy_attack_brake_start_speed, definition.heavy_attack_brake_speed, brake_blend)
	if definition != null:
		var terminal_slow_start: float = maxf(terminal_stop_distance + 0.01, minf(definition.heavy_attack_brake_distance, attack_range))
		if target_distance < terminal_slow_start:
			var terminal_speed_scale: float = inverse_lerp(terminal_stop_distance, terminal_slow_start, target_distance)
			movement_speed = minf(movement_speed, definition.heavy_attack_brake_speed * terminal_speed_scale)
	if animation_controller != null:
		animation_controller.set_heavy_lunge_amount(movement_speed / maxf(0.1, lunge_speed))
	var direction: Vector3 = offset.normalized()
	velocity.x = direction.x * movement_speed
	velocity.z = direction.z * movement_speed


func _update_controller_attack_movement(
	timing: ActionTimingDefinition,
	movement: AttackMovementDefinition,
	delta: float
) -> void:
	if _pending_attack_target == null or not is_instance_valid(_pending_attack_target):
		return
	var constraints: Dictionary = _buff_resolver.call("get_constraints", self) if _buff_resolver != null else {}
	if bool(constraints.get("movement_disabled", false)):
		return
	var phase: ActionTimingDefinition.Phase = timing.phase_at(_attack_elapsed)
	var speed_multiplier: float = movement.speed_multiplier_for_phase(phase)
	if speed_multiplier <= 0.0:
		return
	var offset: Vector3 = _pending_attack_target.global_position - global_position
	offset.y = 0.0
	var target_distance: float = offset.length()
	if target_distance <= movement.stop_distance:
		return
	var direction: Vector3 = offset.normalized()
	var distance_to_stop: float = target_distance - movement.stop_distance
	var status_speed_multiplier: float = maxf(0.0, float(constraints.get("movement_speed_multiplier", 1.0)))
	var movement_speed: float = minf(fallback_move_speed * speed_multiplier * status_speed_multiplier, distance_to_stop / maxf(0.001, delta))
	velocity.x = direction.x * movement_speed
	velocity.z = direction.z * movement_speed


func _can_resolve_pending_attack() -> bool:
	if _pending_attack_target == null or not is_instance_valid(_pending_attack_target):
		return false
	if definition != null and definition.pressure_role == EnemyDefinition.PressureRole.RANGED_PRESSURE:
		return true
	var horizontal_offset: Vector3 = _pending_attack_target.global_position - global_position
	horizontal_offset.y = 0.0
	if _active_attack_kind == AttackKind.HEAVY and definition != null:
		return horizontal_offset.length() <= definition.heavy_attack_impact_range
	return horizontal_offset.length() <= attack_range * 1.2


func _try_resolve_heavy_pounce(previous_attack_elapsed: float) -> void:
	if (
		_active_attack_kind != AttackKind.HEAVY
		or _heavy_attack_pounce_has_resolved
		or definition == null
		or _pending_attack_target == null
		or not is_instance_valid(_pending_attack_target)
	):
		return
	var pounce_start: float = heavy_attack_pounce_timing.impact_start_seconds()
	var pounce_end: float = heavy_attack_pounce_timing.impact_end_seconds()
	if _attack_elapsed < pounce_start or previous_attack_elapsed >= pounce_end:
		return
	var horizontal_offset: Vector3 = _pending_attack_target.global_position - global_position
	horizontal_offset.y = 0.0
	if horizontal_offset.length() > definition.heavy_attack_pounce_range:
		return
	_heavy_attack_pounce_has_resolved = _try_attack(
		_pending_attack_target,
		definition.heavy_attack_pounce_damage_multiplier,
		&"heavy_pounce"
	)


func _can_begin_heavy_attack(distance_to_target: float) -> bool:
	var eligible: bool = (
		definition != null
		and definition.heavy_attack_enabled
		and _heavy_attack_cooldown_remaining <= 0.0
		and _attack_cooldown_remaining <= 0.0
		and distance_to_target >= definition.heavy_attack_min_range
		and distance_to_target <= definition.heavy_attack_range
	)
	if not eligible or _heavy_attack_decision_remaining > 0.0:
		return false
	_reset_heavy_attack_decision_timer()
	return randf() <= definition.heavy_attack_trigger_probability


func _choose_close_attack_kind() -> AttackKind:
	if (
		definition == null
		or not definition.tracking_attack_enabled
		or definition.tracking_attack_probability <= 0.0
		or definition.tracking_attack_movement == null
		or definition.tracking_attack_movement.movement_source != AttackMovementDefinition.MovementSource.CONTROLLER
	):
		return AttackKind.NORMAL
	if definition.tracking_attack_probability >= 1.0 or randf() < definition.tracking_attack_probability:
		return AttackKind.TRACKING
	return AttackKind.NORMAL


func _reset_heavy_attack_decision_timer() -> void:
	if definition == null:
		_heavy_attack_decision_remaining = 0.0
		return
	var minimum: float = minf(definition.heavy_attack_decision_min_seconds, definition.heavy_attack_decision_max_seconds)
	var maximum: float = maxf(definition.heavy_attack_decision_min_seconds, definition.heavy_attack_decision_max_seconds)
	_heavy_attack_decision_remaining = randf_range(minimum, maximum)


func _current_attack_timing() -> ActionTimingDefinition:
	if _active_attack_kind == AttackKind.HEAVY:
		return heavy_attack_timing
	if _active_attack_kind == AttackKind.TRACKING:
		return tracking_attack_timing
	return attack_timing


func _current_attack_movement() -> AttackMovementDefinition:
	if _active_attack_kind == AttackKind.TRACKING and definition != null:
		return definition.tracking_attack_movement
	return null


func _cancel_pending_attack() -> void:
	_pending_attack_target = null
	_attack_elapsed = 0.0
	_attack_has_resolved = false
	_heavy_attack_pounce_has_resolved = false
	_active_attack_kind = AttackKind.NORMAL
	_heavy_attack_braking = false
	_heavy_attack_brake_elapsed = 0.0
	_heavy_attack_brake_start_speed = 0.0


func _try_attack(
	current_target: Node3D,
	damage_multiplier: float = 1.0,
	attack_tag: StringName = &"",
	ignore_cooldown: bool = false
) -> bool:
	if (not ignore_cooldown and _attack_cooldown_remaining > 0.0) or current_target == null or _state == State.DEAD:
		return false

	if not ignore_cooldown:
		_attack_cooldown_remaining = attack_cooldown_seconds
	if definition != null and definition.pressure_role == EnemyDefinition.PressureRole.RANGED_PRESSURE:
		_fire_ranged(current_target)
	else:
		_deal_melee(current_target, damage_multiplier, attack_tag)
	return true


func _deal_melee(current_target: Node3D, damage_multiplier: float = 1.0, attack_tag: StringName = &"") -> void:
	var hit_data: DamageEventData = DamageEventData.new()
	hit_data.attacker_id = get_instance_id()
	hit_data.target_id = current_target.get_instance_id()
	hit_data.amount = attack_damage * (definition.heavy_attack_damage_multiplier if _active_attack_kind == AttackKind.HEAVY and definition != null else 1.0) * damage_multiplier
	hit_data.damage_type = &"physical"
	hit_data.source_tags = [&"enemy", _enemy_id(), &"melee"]
	if definition != null:
		hit_data.status_ids_to_apply = definition.attack_status_ids.duplicate()
	if _active_attack_kind == AttackKind.HEAVY:
		hit_data.source_tags.append(&"heavy_attack")
	elif _active_attack_kind == AttackKind.TRACKING:
		hit_data.source_tags.append(&"tracking_attack")
	if not attack_tag.is_empty():
		hit_data.source_tags.append(attack_tag)
	hit_data.hit_position = current_target.global_position

	if current_target.has_method("receive_damage"):
		current_target.call("receive_damage", hit_data)


func _fire_ranged(current_target: Node3D) -> void:
	var origin: Vector3 = global_position + Vector3.UP * 1.2
	var target_point: Vector3 = current_target.global_position + Vector3.UP * 1.0
	var direction: Vector3 = target_point - origin
	if direction.length() <= 0.001:
		return
	direction = direction.normalized()

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * attack_range)
	query.collision_mask = attack_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if self is CollisionObject3D:
		query.exclude = [(self as CollisionObject3D).get_rid()]

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Object = result.get("collider")
	if not (collider is Node):
		return

	var receiver: Node = _find_damage_receiver(collider as Node)
	if receiver == null:
		return

	var hit_data: DamageEventData = DamageEventData.new()
	hit_data.attacker_id = get_instance_id()
	hit_data.target_id = receiver.get_instance_id()
	hit_data.amount = attack_damage
	hit_data.damage_type = &"ballistic"
	hit_data.source_tags = [&"enemy", _enemy_id(), &"firearm"]
	if definition != null:
		hit_data.status_ids_to_apply = definition.attack_status_ids.duplicate()
	hit_data.hit_position = result.get("position", target_point)

	if receiver.has_method("receive_damage"):
		receiver.call("receive_damage", hit_data)


func _find_damage_receiver(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("receive_damage"):
			return current
		current = current.get_parent()
	return null


func _face_target(current_target: Node3D) -> void:
	if current_target == null:
		return
	var look_target: Vector3 = current_target.global_position
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) <= 0.0001:
		return
	look_at(look_target, Vector3.UP)


func _on_health_died() -> void:
	_cancel_pending_attack()
	_transition_to(State.DEAD)
	velocity = Vector3.ZERO
	set_physics_process(false)
	var collision: CollisionShape3D = $CollisionShape3D as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	if animation_controller != null:
		animation_controller.set_locomotion_speed(0.0)
		animation_controller.play_death(death_timing)
	died.emit(_enemy_id(), get_instance_id(), wave_index)
	get_tree().create_timer(death_timing.total_seconds()).timeout.connect(queue_free)


func _transition_to(next_state: State) -> void:
	if _state == next_state or _state == State.DEAD:
		return
	_state = next_state


func _sync_locomotion_animation() -> void:
	if animation_controller == null:
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	animation_controller.set_locomotion_speed(horizontal_speed / maxf(0.1, fallback_move_speed))


func _enemy_id() -> StringName:
	if definition != null and definition.enemy_id != &"":
		return definition.enemy_id
	return &"enemy"
