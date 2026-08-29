extends Node

@export_range(1, 5, 1) var wave_index: int = 5

@onready var level: Node3D = $MvpSkeleton


func _ready() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	var phase_controller: PhaseController = level.get_node_or_null("PhaseController") as PhaseController
	if game_manager == null or phase_controller == null:
		push_error("EnemySystemAcceptance: missing run orchestration")
		return

	_boost_acceptance_health(level.get_node_or_null("Player"), 10000.0)
	_boost_acceptance_health(level.get_node_or_null("Base/NorthBarrier"), 10000.0)
	_boost_acceptance_health(level.get_node_or_null("Base/BaseCore"), 10000.0)
	game_manager.start_mvp_run(phase_controller.run_config)
	game_manager.current_wave_index = wave_index
	game_manager.change_phase(GameManager.PHASE_RAIN)
	await get_tree().process_frame

	var enemies: Node = level.get_node_or_null("Enemies")
	var expected_counts: Array[int] = [0, 3, 5, 6, 7, 11]
	if enemies == null or enemies.get_child_count() != expected_counts[wave_index]:
		push_error("EnemySystemAcceptance: wave %d spawn count mismatch" % wave_index)
		return

	var enemy_ids: Array[StringName] = []
	for child: Node in enemies.get_children():
		if child is EnemyBase:
			enemy_ids.append((child as EnemyBase).definition.enemy_id)
	print("ENEMY_SYSTEM_ACCEPTANCE_READY: wave=%d enemies=%d ids=%s" % [wave_index, enemies.get_child_count(), enemy_ids])


func _boost_acceptance_health(target: Node, maximum: float) -> void:
	if target == null or not target.has_method("get_health_component"):
		return
	var health_value: Variant = target.call("get_health_component")
	if not (health_value is HealthComponent):
		return
	var health: HealthComponent = health_value as HealthComponent
	health.max_health = maximum
	health.set_health(maximum)
