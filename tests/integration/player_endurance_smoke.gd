extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")


class ActionTarget extends Node3D:
	var received_hits: int = 0
	var last_hit: DamageEventData


	func _init() -> void:
		add_to_group("enemy")


	func receive_damage(data: DamageEventData) -> void:
		received_hits += 1
		last_hit = data


func _ready() -> void:
	await _check_stamina_recovery_delay()
	await _check_sprint_reserve_is_separate_from_stamina()
	await _check_exhausted_attack_and_combo_rules()
	print("PLAYER_ENDURANCE_SMOKE: PASS")
	get_tree().quit()


func _check_stamina_recovery_delay() -> void:
	var stamina := StaminaComponent.new()
	stamina.max_stamina = 100.0
	stamina.current_stamina = 100.0
	stamina.recovery_per_second = 100.0
	stamina.recovery_delay_seconds = 0.12
	add_child(stamina)
	await get_tree().process_frame
	_check(stamina.consume(30.0), "stamina test setup could not consume")
	await get_tree().create_timer(0.07).timeout
	_check(is_equal_approx(stamina.current_stamina, 70.0), "stamina recovered before its delay elapsed")
	_check(stamina.consume(10.0), "second stamina consumption failed")
	await get_tree().create_timer(0.07).timeout
	_check(is_equal_approx(stamina.current_stamina, 60.0), "new stamina consumption did not interrupt recovery")
	await get_tree().create_timer(0.10).timeout
	_check(stamina.current_stamina > 60.0, "stamina did not recover after the latest delay elapsed")
	stamina.queue_free()


func _check_sprint_reserve_is_separate_from_stamina() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	add_child(player)
	await get_tree().process_frame
	player.stamina.auto_recover = false
	player.stamina.current_stamina = 61.0
	player.sprint_reserve.current_reserve = 100.0
	var reserve_before: float = player.sprint_reserve.current_reserve
	_check(player.locomotion_state_machine._consume_sprint_reserve(1.0), "sprint reserve could not fund sprinting")
	_check(player.sprint_reserve.current_reserve < reserve_before, "sprinting did not consume the hidden reserve")
	_check(is_equal_approx(player.stamina.current_stamina, 61.0), "sprinting consumed combat stamina")
	player.sprint_reserve.current_reserve = 0.0
	_check(not player.locomotion_state_machine._consume_sprint_reserve(0.1), "empty sprint reserve did not report exhaustion")
	_check_empty_sprint_reserve_stays_empty_while_drained()
	player.queue_free()


func _check_empty_sprint_reserve_stays_empty_while_drained() -> void:
	var reserve := SprintReserveComponent.new()
	reserve.max_reserve = 100.0
	reserve.current_reserve = 0.0
	reserve.recovery_per_second = 100.0
	reserve.recovery_delay_seconds = 0.01
	for _index: int in 3:
		reserve.consume(1.0)
		reserve._process(0.02)
	_check(is_equal_approx(reserve.current_reserve, 0.0), "empty reserve recovered while sprint drain continued")
	reserve._process(0.02)
	_check(reserve.current_reserve > 0.0, "empty reserve did not recover after sprint drain stopped")


func _check_exhausted_attack_and_combo_rules() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	add_child(player)
	await get_tree().process_frame
	var driver: PlayerCombatDriver = player.combat_driver
	var combat: PlayerCombatDefinition = player.combat_definition
	var weapon: WeaponDefinition = driver.current_weapon
	_check(weapon != null and weapon.held_combo_timing != null, "melee weapon is missing its held combo timing")
	_check(weapon.held_combo_timing.total_seconds() < weapon.primary_timing.total_seconds(), "later light attacks are not faster")

	player.stamina.auto_recover = false
	player.stamina.current_stamina = 0.0
	var light_target := ActionTarget.new()
	light_target.position = Vector3(0.0, 0.0, -combat.melee_range * 1.25)
	add_child(light_target)
	_check(driver.begin_primary_attack(), "exhausted light attack was blocked")
	_check(driver.primary_attack_exhausted, "exhausted light attack did not record its penalty")
	driver.resolve_primary_attack(player)
	_check(light_target.received_hits == 1, "light attack did not use its extended reach")
	_check(
		is_equal_approx(light_target.last_hit.amount, weapon.base_damage * combat.exhausted_attack_damage_multiplier),
		"exhausted light attack used the wrong damage multiplier"
	)

	var heavy_target := ActionTarget.new()
	heavy_target.position = Vector3(0.0, 0.0, -1.0)
	add_child(heavy_target)
	_check(driver.begin_heavy_attack(), "exhausted heavy attack was blocked")
	_check(driver.heavy_attack_exhausted, "exhausted heavy attack did not record its penalty")
	driver.resolve_heavy_attack(player)
	_check(
		is_equal_approx(
			heavy_target.last_hit.amount,
			weapon.base_damage * combat.heavy_attack_damage_multiplier * combat.exhausted_attack_damage_multiplier
		),
		"exhausted heavy attack used the wrong damage multiplier"
	)

	var arms: PlayerFirstPersonArms = player.first_person_arms
	arms.play_attack(1, weapon.primary_timing, true)
	await get_tree().create_timer(weapon.primary_timing.total_seconds() + 0.02).timeout
	_check(
		not arms.left_shoulder.transform.is_equal_approx(arms._left_shoulder_base),
		"left hand dropped during an active light combo"
	)
	arms.release_light_combo_guard()
	await get_tree().create_timer(0.25).timeout
	_check(
		rad_to_deg(arms.left_shoulder.rotation.distance_to(arms._left_shoulder_base.basis.get_euler())) < 3.0,
		"left hand did not return after combo ended"
	)
	light_target.queue_free()
	heavy_target.queue_free()
	player.queue_free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("PLAYER_ENDURANCE_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)
