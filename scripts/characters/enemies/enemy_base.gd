class_name EnemyBase
extends CharacterBody3D

signal died(enemy_id: StringName, instance_id: int, wave_index: int)

@export var definition: EnemyDefinition
@export var target_group: StringName = &"player"
@export var wave_index: int = 0
@export_range(0.1, 100.0, 0.1) var fallback_move_speed: float = 3.5
@export_range(0.1, 20.0, 0.1) var attack_range: float = 1.5
@export_range(0.1, 100.0, 0.1) var attack_damage: float = 10.0
@export_range(0.1, 20.0, 0.1) var attack_cooldown_seconds: float = 1.5
@export_flags_3d_physics var attack_collision_mask: int = 3

@onready var health: HealthComponent = %HealthComponent
@onready var status_container: StatusContainer = %StatusContainer

var target: Node3D
var _state: StringName = &"chase"
var _state_time_remaining: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _event_bus: Node
var _buff_resolver: Node
var _damage_resolver: Node


func _ready() -> void:
	add_to_group("enemy")
	_event_bus = get_node_or_null("/root/EventBus")
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
		_apply_target_tags()

	if health != null:
		health.set_health(health.max_health)
		if not health.died.is_connected(_on_health_died):
			health.died.connect(_on_health_died)


func _physics_process(delta: float) -> void:
	if _state == &"dead":
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _state_time_remaining > 0.0:
		_state_time_remaining = maxf(0.0, _state_time_remaining - delta)

	if target == null or not is_instance_valid(target):
		target = _find_target()

	if target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0

	var constraints: Dictionary = _buff_resolver.call("get_constraints", self) if _buff_resolver != null else {}
	if bool(constraints.get("movement_disabled", false)) or bool(constraints.get("combat_blocked", false)):
		velocity.x = 0.0
		velocity.z = 0.0
		_face_target(target)
		move_and_slide()
		return

	if to_target.length() <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_target(target)
		_try_attack(target)
	else:
		_state = &"chase"
		var speed_multiplier: float = maxf(0.0, float(constraints.get("movement_speed_multiplier", 1.0)))
		var direction: Vector3 = to_target.normalized()
		velocity.x = direction.x * fallback_move_speed * speed_multiplier
		velocity.z = direction.z * fallback_move_speed * speed_multiplier
		_face_target(target)

	move_and_slide()


func receive_damage(data: DamageEventData) -> void:
	if _damage_resolver != null:
		_damage_resolver.call("resolve_damage", data, self)


func on_damage_resolved(result: DamageResolutionData) -> void:
	if not result.applied or _state == &"dead":
		return
	if result.event.stagger > 0.0 and _buff_resolver != null:
		_buff_resolver.call(
			"apply_status_by_id",
			self,
			&"staggered",
			maxf(0.35, result.event.stagger * 0.05),
			result.event.attacker_id
		)


func get_health_component() -> HealthComponent:
	return health


func get_status_container() -> StatusContainer:
	return status_container


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


func _try_attack(current_target: Node3D) -> void:
	if _state_time_remaining > 0.0 or current_target == null:
		return

	_state_time_remaining = attack_cooldown_seconds
	if definition != null and definition.pressure_role == EnemyDefinition.PressureRole.RANGED_PRESSURE:
		_fire_ranged(current_target)
	else:
		_deal_melee(current_target)


func _deal_melee(current_target: Node3D) -> void:
	var hit_data: DamageEventData = DamageEventData.new()
	hit_data.attacker_id = get_instance_id()
	hit_data.target_id = current_target.get_instance_id()
	hit_data.amount = attack_damage
	hit_data.damage_type = &"physical"
	hit_data.source_tags = [&"enemy", _enemy_id(), &"melee"]
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
	look_at(look_target, Vector3.UP, true)


func _on_health_died() -> void:
	_state = &"dead"
	velocity = Vector3.ZERO
	set_physics_process(false)
	died.emit(_enemy_id(), get_instance_id(), wave_index)
	call_deferred("queue_free")


func _enemy_id() -> StringName:
	if definition != null and definition.enemy_id != &"":
		return definition.enemy_id
	return &"enemy"
