extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")

var _resolution_event_count: int = 0
var _periodic_resolution_seen: bool = false


func _ready() -> void:
	var damage_resolver: Node = get_node("/root/DamageResolver")
	var buff_resolver: Node = get_node("/root/BuffResolver")
	damage_resolver.damage_resolved.connect(_on_damage_resolved)

	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	player.position = Vector3.ZERO
	enemy.position = Vector3(100.0, 0.0, 0.0)
	add_child(player)
	add_child(enemy)
	await get_tree().process_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)

	_check(player.has_status(&"deserter_baseline"), "player profession buff was not resolved")
	_check(enemy.get_status_container() != null, "enemy status container missing")

	enemy.health.set_health(100.0)
	var outgoing_hit: DamageEventData = _damage_event(player, enemy, 10.0)
	var outgoing_result: DamageResolutionData = damage_resolver.call("resolve_damage", outgoing_hit, enemy)
	_check(outgoing_result.applied, "outgoing damage was not applied")
	_check(is_equal_approx(outgoing_result.final_amount, 11.0), "outgoing buff was not resolved centrally")
	_check(is_equal_approx(enemy.health.current_health, 89.0), "enemy health did not receive resolved damage")

	enemy.health.set_health(100.0)
	var critical_hit: DamageEventData = _damage_event(player, enemy, 10.0)
	critical_hit.is_critical = true
	var critical_result: DamageResolutionData = damage_resolver.call("resolve_damage", critical_hit, enemy)
	_check(is_equal_approx(critical_result.final_amount, 22.0), "critical multiplier was not resolved centrally")

	var guard: StatusEffectDefinition = StatusEffectDefinition.new()
	guard.status_id = &"resolver_test_guard"
	guard.display_name = "Resolver Test Guard"
	guard.duration_seconds = 1.0
	guard.incoming_damage_multiplier = 0.5
	_check(bool(buff_resolver.call("apply_status", player, guard, -1.0, enemy.get_instance_id())), "guard buff could not be applied")
	player.health.set_health(100.0)
	var guarded_hit: DamageEventData = _damage_event(enemy, player, 20.0)
	var guarded_result: DamageResolutionData = damage_resolver.call("resolve_damage", guarded_hit, player)
	_check(is_equal_approx(guarded_result.final_amount, 10.0), "incoming buff was not resolved centrally")
	_check(is_equal_approx(player.health.current_health, 90.0), "guarded damage did not reach health")

	var refreshed: StatusEffectDefinition = StatusEffectDefinition.new()
	refreshed.status_id = &"resolver_test_refresh"
	refreshed.display_name = "Resolver Test Refresh"
	refreshed.duration_seconds = 1.0
	refreshed.outgoing_damage_multiplier = 1.2
	_check(bool(buff_resolver.call("apply_status", enemy, refreshed)), "first unique status could not be applied")
	_check(bool(buff_resolver.call("apply_status", enemy, refreshed)), "repeated status could not be refreshed")
	_check(enemy.status_container.get_status_stack_count(refreshed.status_id) == 1, "repeated status incorrectly stacked")
	var refreshed_constraints: Dictionary = buff_resolver.call("get_constraints", enemy)
	_check(is_equal_approx(float(refreshed_constraints["outgoing_damage_multiplier"]), 1.2), "refreshed status multiplier was applied more than once")

	var periodic: StatusEffectDefinition = StatusEffectDefinition.new()
	periodic.status_id = &"resolver_test_periodic"
	periodic.display_name = "Resolver Test Periodic"
	periodic.duration_seconds = 0.2
	periodic.tick_interval_seconds = 0.05
	periodic.health_delta_per_tick = -4.0
	periodic.tick_damage_type = &"physical"
	enemy.health.set_health(100.0)
	_check(bool(buff_resolver.call("apply_status", enemy, periodic, -1.0, player.get_instance_id())), "periodic buff could not be applied")
	await get_tree().create_timer(0.07).timeout
	_check(enemy.health.current_health < 100.0, "periodic damage did not reach health")
	_check(_periodic_resolution_seen, "periodic damage bypassed DamageResolver")

	var stagger_hit: DamageEventData = _damage_event(player, enemy, 0.0)
	stagger_hit.stagger = 10.0
	var stagger_result: DamageResolutionData = damage_resolver.call("resolve_damage", stagger_hit, enemy)
	_check(stagger_result.applied, "zero-damage stagger event was rejected")
	_check(enemy.status_container.has_status(&"staggered"), "enemy stagger did not use BuffResolver")
	_check(_resolution_event_count >= 5, "resolved damage signal was not emitted consistently")

	print("COMBAT_BUFF_RESOLVER_SMOKE: PASS")
	get_tree().quit()


func _damage_event(attacker: Node, target: Node, amount: float) -> DamageEventData:
	var event: DamageEventData = DamageEventData.new()
	event.attacker_id = attacker.get_instance_id()
	event.target_id = target.get_instance_id()
	event.amount = amount
	event.damage_type = &"physical"
	event.source_tags = [&"resolver_test"]
	return event


func _on_damage_resolved(result: DamageResolutionData) -> void:
	_resolution_event_count += 1
	if result.event != null and result.event.source_tags.has(&"periodic"):
		_periodic_resolution_seen = true


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("COMBAT_BUFF_RESOLVER_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)
