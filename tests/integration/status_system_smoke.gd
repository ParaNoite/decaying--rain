extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")


func _ready() -> void:
	var damage_resolver: Node = get_node("/root/DamageResolver")
	var buff_resolver: Node = get_node("/root/BuffResolver")
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	add_child(player)
	add_child(enemy)
	await get_tree().process_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)

	_check(player.apply_status_by_id(&"bleeding", 0.2), "bleeding could not be applied to player")
	await get_tree().create_timer(0.11).timeout
	_check(player.apply_status_by_id(&"bleeding", 0.2), "bleeding could not be refreshed")
	_check(player.status_container.get_status_stack_count(&"bleeding") == 1, "bleeding incorrectly stacked")
	_check(player.status_container.get_status_remaining(&"bleeding") > 0.15, "bleeding duration did not refresh")
	player.remove_status(&"bleeding")

	var bleeding_hit: DamageEventData = DamageEventData.new()
	bleeding_hit.attacker_id = enemy.get_instance_id()
	bleeding_hit.target_id = player.get_instance_id()
	bleeding_hit.amount = 1.0
	bleeding_hit.status_ids_to_apply = [&"bleeding"]
	damage_resolver.call("resolve_damage", bleeding_hit, player)
	_check(player.has_status(&"bleeding"), "damage event did not apply bleeding to player")
	player.remove_status(&"bleeding")

	var enemy_bleeding_hit: DamageEventData = DamageEventData.new()
	enemy_bleeding_hit.attacker_id = player.get_instance_id()
	enemy_bleeding_hit.target_id = enemy.get_instance_id()
	enemy_bleeding_hit.amount = 1.0
	enemy_bleeding_hit.status_ids_to_apply = [&"bleeding"]
	damage_resolver.call("resolve_damage", enemy_bleeding_hit, enemy)
	_check(enemy.status_container.has_status(&"bleeding"), "damage event did not apply bleeding to enemy")

	player.hunger.set_hunger(0.0)
	player._sync_survival_statuses()
	_check(player.has_status(&"hungry"), "empty hunger did not apply hungry")
	var hungry_constraints: Dictionary = buff_resolver.call("get_constraints", player)
	_check(is_equal_approx(float(hungry_constraints["outgoing_damage_multiplier"]), 0.75), "hungry damage modifier is incorrect")
	player.hunger.restore_hunger(1.0)
	player._sync_survival_statuses()
	_check(not player.has_status(&"hungry"), "restoring hunger did not clear hungry")

	player.sprint_reserve.current_reserve = 0.0
	player._sync_survival_statuses()
	_check(player.has_status(&"exhausted"), "empty sprint reserve did not apply exhausted")
	var exhausted_constraints: Dictionary = buff_resolver.call("get_constraints", player)
	_check(is_equal_approx(float(exhausted_constraints["sprint_speed_multiplier"]), 0.5), "exhausted sprint modifier is incorrect")
	player.sprint_reserve.current_reserve = player.sprint_reserve.max_reserve
	player._sync_survival_statuses()
	_check(not player.has_status(&"exhausted"), "recovered sprint reserve did not clear exhausted")

	print("STATUS_SYSTEM_SMOKE: PASS")
	get_tree().quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("STATUS_SYSTEM_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)
