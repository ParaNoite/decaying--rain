extends Node3D

const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const RUPTURED_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/ruptured.tres")


func _ready() -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.definition = RUPTURED_DEFINITION
	enemy.position = Vector3(0.0, 0.0, -1.0)
	add_child(enemy)
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	add_child(player)
	await get_tree().physics_frame
	enemy.set_physics_process(false)
	player.set_physics_process(false)

	var animation: EnemyAnimationController = enemy.get_animation_controller()
	var normal_hit: DamageEventData = _event(player, enemy, 1.0, 0.0, 0.0, [&"melee"])
	enemy.receive_damage(normal_hit)
	_check(enemy.get_state() == EnemyBase.State.HURT, "normal hit should play a brief hurt reaction")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_HURT, "normal hit should use the old hurt animation")
	_check(is_zero_approx(enemy.get_knockback_velocity().length()), "normal hit must not physically knock back the enemy")

	_reset_stagger(enemy)
	_check(player.combat_driver.begin_shove(), "player should begin shove")
	_check(player.combat_driver.resolve_shove(player), "player shove should resolve through its combat driver")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_SHOVED, "shove should use the old shove animation")
	var shove_speed: float = enemy.get_knockback_velocity().length()
	_check(shove_speed > 5.4, "shove should apply its old physical knockback")
	var before_shove: Vector3 = enemy.global_position
	enemy._physics_process(0.1)
	_check(enemy.global_position.z < before_shove.z, "shove should move the enemy away from the player")

	_reset_stagger(enemy)
	var health_before: float = player.health.current_health
	player.combat_state_machine.parry_active = true
	var enemy_hit: DamageEventData = _event(enemy, player, 10.0, 0.0, 0.0, [&"enemy", &"melee"])
	player.receive_damage(enemy_hit)
	_check(is_equal_approx(player.health.current_health, health_before), "successful Q parry should block damage")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_PARRIED, "Q parry should use the old parry animation")
	_check(enemy.get_knockback_velocity().length() > shove_speed, "Q parry should knock back harder than shove")

	_reset_stagger(enemy)
	enemy._attack_cooldown_remaining = 0.0
	player.combat_state_machine.parry_active = true
	enemy._begin_attack(player)
	enemy._update_attack(enemy.attack_timing.impact_start_seconds() + 0.01)
	_check(enemy.get_state() == EnemyBase.State.HURT, "Q parry should interrupt the enemy attack")
	animation._process(0.35)
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_PARRIED, "attack impact must not overwrite the Q parry animation")
	_check(absf(enemy.get_visual_rig().spine.rotation.x) > 0.25, "Q parry should visibly hold the backward stagger")

	print("ENEMY_REACTION_SMOKE: PASS")
	get_tree().quit()


func _event(
	attacker: Node,
	target: Node,
	amount: float,
	stagger: float,
	knockback: float,
	tags: Array[StringName]
) -> DamageEventData:
	var event: DamageEventData = DamageEventData.new()
	event.attacker_id = attacker.get_instance_id()
	event.target_id = target.get_instance_id()
	event.amount = amount
	event.stagger = stagger
	event.knockback_force = knockback
	event.source_tags = tags
	event.hit_position = (attacker as Node3D).global_position if attacker is Node3D else Vector3.ZERO
	return event


func _reset_stagger(enemy: EnemyBase) -> void:
	get_node("/root/BuffResolver").call("remove_status", enemy, &"staggered")
	enemy._physics_process(0.01)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ENEMY_REACTION_SMOKE: FAIL - %s" % message)
	assert(condition, message)
