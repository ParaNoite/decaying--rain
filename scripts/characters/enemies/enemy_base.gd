class_name EnemyBase
extends CharacterBody3D

@export var definition: EnemyDefinition
@export var target_group: StringName = &"player"
@export_range(0.1, 100.0, 0.1) var fallback_move_speed: float = 3.5
@export_range(0.1, 20.0, 0.1) var attack_range: float = 1.5
@export_range(0.1, 100.0, 0.1) var attack_damage: float = 10.0

@onready var health: HealthComponent = %HealthComponent

var target: Node3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("enemy")
	if definition != null:
		health.max_health = definition.max_health
		attack_damage = definition.attack_damage
		attack_range = definition.attack_range
		fallback_move_speed = definition.move_speed


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if target == null or not is_instance_valid(target):
		target = _find_target()

	if target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0

	if to_target.length() <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var direction: Vector3 = to_target.normalized()
		velocity.x = direction.x * fallback_move_speed
		velocity.z = direction.z * fallback_move_speed

	move_and_slide()


func receive_damage(data: DamageEventData) -> void:
	if data == null:
		return
	health.take_damage(data.amount)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.combat_hit.emit(data)


func _find_target() -> Node3D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(target_group)
	for node: Node in nodes:
		if node is Node3D:
			return node as Node3D
	return null
