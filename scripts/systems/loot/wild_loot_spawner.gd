class_name WildLootSpawner
extends Node3D

const WORLD_PICKUP_SCENE: PackedScene = preload("res://scenes/interactables/world_pickup.tscn")

@export var loot_table: LootTableDefinition
@export_range(1, 16, 1) var minimum_spawn_count: int = 2
@export_range(1, 16, 1) var maximum_spawn_count: int = 4
@export_range(0.0, 2.0, 0.05) var spawn_height: float = 0.6

@onready var spawn_points: Node3D = $SpawnPoints

var _loot_resolver: LootResolver = LootResolver.new()
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _has_spawned: bool = false


func _ready() -> void:
	_random.randomize()
	call_deferred("spawn_initial_loot")


func spawn_initial_loot() -> void:
	if _has_spawned or loot_table == null or spawn_points == null:
		return
	_has_spawned = true
	var available_points: Array[Marker3D] = []
	for child: Node in spawn_points.get_children():
		if child is Marker3D:
			available_points.append(child as Marker3D)
	if available_points.is_empty():
		push_warning("WildLootSpawner.spawn_initial_loot has no Marker3D spawn points")
		return
	available_points.shuffle()
	var requested_count: int = _random.randi_range(minimum_spawn_count, maximum_spawn_count)
	var spawn_count: int = mini(requested_count, available_points.size())
	for index: int in spawn_count:
		_spawn_at(available_points[index])


func _spawn_at(point: Marker3D) -> void:
	var payload: Dictionary[StringName, int] = _loot_resolver.resolve_loot(loot_table, _random)
	if payload.is_empty():
		return
	var item_ids: Array = payload.keys()
	item_ids.sort()
	var item_id: StringName = StringName(item_ids[_random.randi_range(0, item_ids.size() - 1)])
	var item: ItemDefinition = loot_table.get_item_definition(item_id)
	if item == null:
		return
	var pickup: WorldPickup = WORLD_PICKUP_SCENE.instantiate() as WorldPickup
	pickup.configure(item, int(payload[item_id]))
	var world_parent: Node = get_tree().current_scene if get_tree().current_scene != null else self
	world_parent.add_child(pickup)
	pickup.global_position = point.global_position + Vector3.UP * spawn_height
