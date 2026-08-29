class_name WaveDirector
extends Node

@export var enemy_scene: PackedScene
@export var wave_definitions: Array[WaveDefinition] = []
@export var enemy_definitions: Array[EnemyDefinition] = []
@export var spawn_points_root_path: NodePath = ^"../SpawnPoints"
@export var enemy_container_path: NodePath = ^"../Enemies"

var _event_bus: Node
var _game_manager_ref: Node
var _enemy_definitions_by_id: Dictionary[StringName, EnemyDefinition] = {}
var _active_enemies: Dictionary[int, EnemyBase] = {}
var _active_wave_index: int = 0
var _active_wave_id: StringName = &""
var _spawn_points: Array[Marker3D] = []
var _spawning: bool = false


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	_game_manager_ref = get_node_or_null("/root/GameManager")
	_rebuild_enemy_lookup()
	_refresh_spawn_points()
	if _event_bus != null and not _event_bus.phase_changed.is_connected(_on_phase_changed):
		_event_bus.phase_changed.connect(_on_phase_changed)
	if _game_manager_ref != null and _game_manager_ref.current_phase == GameManager.PHASE_RAIN:
		begin_wave(_game_manager_ref.current_wave_index)


func _exit_tree() -> void:
	if _event_bus != null and _event_bus.phase_changed.is_connected(_on_phase_changed):
		_event_bus.phase_changed.disconnect(_on_phase_changed)


func get_wave(index: int) -> WaveDefinition:
	for wave: WaveDefinition in wave_definitions:
		if wave != null and wave.wave_index == index:
			return wave
	return null


func begin_wave(index: int) -> void:
	if _spawning:
		return

	var wave: WaveDefinition = get_wave(index)
	_clear_wave(true)
	_refresh_spawn_points()

	if wave == null or enemy_scene == null:
		push_warning("WaveDirector: cannot begin wave %d without wave data and an enemy scene" % index)
		return

	_active_wave_index = index
	_active_wave_id = wave.wave_id if wave != null else StringName("wave_%d" % index)

	if _event_bus != null:
		_event_bus.wave_started.emit(index, _active_wave_id)

	var spawn_entries: Array[WaveEnemyEntry] = wave.get_spawn_entries()
	if spawn_entries.is_empty():
		_complete_wave()
		return

	_spawning = true
	var spawn_index: int = 0
	for entry: WaveEnemyEntry in spawn_entries:
		for i: int in range(entry.count):
			var spawn_point: Marker3D = _spawn_point_for_index(spawn_index)
			var enemy: EnemyBase = _spawn_enemy(entry.enemy_id, wave.wave_index, spawn_point)
			if enemy != null:
				_active_enemies[enemy.get_instance_id()] = enemy
			spawn_index += 1
	_spawning = false

	if _active_enemies.is_empty():
		_complete_wave()


func complete_wave(index: int) -> void:
	var wave: WaveDefinition = get_wave(index)
	var wave_id: StringName = wave.wave_id if wave != null else StringName("wave_%d" % index)
	if _event_bus != null:
		_event_bus.wave_completed.emit(index, wave_id)

	var game_manager: Node = _game_manager()
	if game_manager != null and game_manager.current_phase == GameManager.PHASE_RAIN:
		game_manager.change_phase(GameManager.PHASE_SETTLEMENT)


func _spawn_enemy(enemy_id: StringName, wave_index: int, spawn_point: Marker3D) -> EnemyBase:
	var enemy_definition: EnemyDefinition = _enemy_definitions_by_id.get(enemy_id, null)
	if enemy_definition == null:
		push_warning("WaveDirector: missing enemy definition for '%s'" % String(enemy_id))
		return null

	var instance: Node = enemy_scene.instantiate()
	if not (instance is EnemyBase):
		push_error("WaveDirector: enemy scene must instantiate EnemyBase")
		instance.queue_free()
		return null

	var enemy: EnemyBase = instance as EnemyBase
	enemy.definition = enemy_definition
	enemy.wave_index = wave_index

	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)

	var container: Node = _enemy_container()
	if container == null:
		container = self
	container.add_child(enemy)

	if spawn_point != null:
		enemy.global_transform = spawn_point.global_transform
		var forward: Vector3 = -spawn_point.global_transform.basis.z
		enemy.look_at(enemy.global_position + forward, Vector3.UP)
	else:
		enemy.global_position = Vector3.ZERO

	if _event_bus != null:
		_event_bus.enemy_spawned.emit(enemy_definition.enemy_id, enemy.get_instance_id(), wave_index)
	return enemy


func _on_enemy_died(enemy_id: StringName, instance_id: int, wave_index: int) -> void:
	if _active_enemies.has(instance_id):
		_active_enemies.erase(instance_id)

	if _event_bus != null:
		_event_bus.enemy_died.emit(enemy_id, instance_id, wave_index)

	if wave_index == _active_wave_index and _active_enemies.is_empty():
		_complete_wave()


func _complete_wave() -> void:
	if _active_wave_index <= 0:
		return
	complete_wave(_active_wave_index)
	_active_wave_index = 0
	_active_wave_id = &""
	_active_enemies.clear()


func _clear_wave(queue_free_children: bool) -> void:
	if queue_free_children:
		for enemy: EnemyBase in _active_enemies.values():
			if enemy != null and is_instance_valid(enemy):
				enemy.queue_free()
	_active_enemies.clear()


func _rebuild_enemy_lookup() -> void:
	_enemy_definitions_by_id.clear()
	for enemy_definition: EnemyDefinition in enemy_definitions:
		if enemy_definition != null and enemy_definition.enemy_id != &"":
			_enemy_definitions_by_id[enemy_definition.enemy_id] = enemy_definition


func _refresh_spawn_points() -> void:
	_spawn_points.clear()
	var root: Node = get_node_or_null(spawn_points_root_path)
	if root == null:
		return
	_collect_spawn_points(root, _spawn_points)


func _collect_spawn_points(node: Node, output: Array[Marker3D]) -> void:
	if node is Marker3D:
		output.append(node as Marker3D)
	for child: Node in node.get_children():
		_collect_spawn_points(child, output)


func _spawn_point_for_index(index: int) -> Marker3D:
	if _spawn_points.is_empty():
		return null
	return _spawn_points[index % _spawn_points.size()]


func _enemy_container() -> Node:
	var container: Node = get_node_or_null(enemy_container_path)
	if container != null:
		return container
	return null


func _game_manager() -> Node:
	return _game_manager_ref


func _on_phase_changed(_previous_phase: StringName, current_phase: StringName, wave_index: int) -> void:
	if current_phase == GameManager.PHASE_RAIN:
		begin_wave(wave_index)
	elif current_phase == GameManager.PHASE_SETTLEMENT or current_phase == GameManager.PHASE_COMPLETE or current_phase == GameManager.PHASE_FAILED:
		_clear_wave(true)
		_active_wave_index = 0
		_active_wave_id = &""
	elif current_phase == GameManager.PHASE_DAYLIGHT or current_phase == GameManager.PHASE_PREPARATION:
		_clear_wave(true)
