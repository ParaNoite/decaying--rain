extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const LOOT_CONTAINER_SCENE: PackedScene = preload("res://scenes/interactables/loot_container.tscn")


class DamageTarget extends Node:
	var health: HealthComponent


	func _init() -> void:
		health = HealthComponent.new()
		health.max_health = 500.0
		add_child(health)


	func get_health_component() -> HealthComponent:
		return health


class ActionTarget extends Node3D:
	var received_hits: int = 0
	var last_hit: DamageEventData


	func _init() -> void:
		add_to_group("enemy")


	func receive_damage(data: DamageEventData) -> void:
		received_hits += 1
		last_hit = data


func _ready() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	add_child(player)
	await get_tree().process_frame

	var inventory: PlayerInventoryComponent = player.inventory_component
	var loadout: PlayerLoadoutComponent = player.loadout_component
	var profession: PlayerProfessionComponent = player.profession_component
	var statuses: StatusContainer = player.status_container
	var first_person_arms: PlayerFirstPersonArms = player.get_node_or_null("Head/Camera3D/FirstPersonArms") as PlayerFirstPersonArms

	_check(inventory != null, "inventory component missing")
	_check(inventory.get_slot_count() == 4, "inventory should expose four slots")
	_check(loadout != null, "loadout component missing")
	_check(first_person_arms != null, "first-person arms viewmodel missing")
	_check(first_person_arms.get_node_or_null("RightShoulder/RightElbow") != null, "right shoulder/elbow chain missing")
	_check(first_person_arms.get_node_or_null("LeftShoulder/LeftElbow") != null, "left shoulder/elbow chain missing")
	var weapon_socket: Marker3D = first_person_arms.get_node_or_null("RightShoulder/RightElbow/RightHandSocket/FirstPersonWeaponSocket") as Marker3D
	var tool_proxy: MeshInstance3D = first_person_arms.get_node_or_null("RightShoulder/RightElbow/RightHandSocket/FirstPersonWeaponSocket/ToolProxy") as MeshInstance3D
	_check(weapon_socket != null, "first-person weapon socket missing from right hand")
	_check(tool_proxy != null and tool_proxy.get_parent() == weapon_socket, "first-person weapon is not attached to the hand socket")
	_check_sprint_entry_uses_loop_pose(player, first_person_arms)
	await _check_arm_elbow_direction(first_person_arms, player)
	_check_action_timing_contract(player, first_person_arms)
	_check_held_combo_cadence(player)
	_check(inventory.get_quantity(&"bandage") == 0, "profession must not grant a placeholder bandage")
	_check(loadout.equipped_weapons.size() == 3, "starting loadout should contain unarmed, crowbar and pistol")
	_check(loadout.get_current_weapon().weapon_id == &"crowbar", "crowbar should be equipped first")
	_check(statuses.has_status(&"deserter_baseline"), "profession status was not applied")
	_check(profession.get_blocked_action_ids().has(&"repair"), "perk action rule missing")
	_check(_action_has_key(&"debug_god_mode", KEY_9), "debug god mode should be bound to the 9 key")
	_check(_action_has_key(&"inventory_slot_1", KEY_1), "inventory slot 1 should be bound to 1")
	_check(_action_has_key(&"inventory_slot_4", KEY_4), "inventory slot 4 should be bound to 4")
	_check(_action_has_key(&"inventory_drop", KEY_Z), "inventory drop should be bound to Z")
	_check(_action_has_key(&"inventory_clear_selection", KEY_H), "inventory clear selection should be bound to H")
	_check(_action_has_mouse(&"attack_secondary", MOUSE_BUTTON_RIGHT), "heavy attack should be bound to right mouse")
	_check(player.combat_definition.melee_range < player.combat_definition.shove_range, "primary melee reach should be shorter than shove reach")
	await _check_parry_success_animation_feedback(player)
	await _check_debug_god_mode(player)

	var ammo_before_loot: int = inventory.get_quantity(&"light_ammo")
	player.receive_loot({&"light_ammo": 4})
	_check(inventory.get_quantity(&"light_ammo") == ammo_before_loot + 5, "ammo pickup multiplier was not applied")
	var light_ammo_slot_count: int = 0
	for slot: Dictionary in inventory.get_slot_snapshots():
		if StringName(slot.get("item_id", &"")) == &"light_ammo":
			light_ammo_slot_count += 1
	_check(light_ammo_slot_count == 0, "special ammo must not occupy a backpack slot")
	_check(inventory.get_special_items().get(&"light_ammo", 0) == inventory.get_quantity(&"light_ammo"), "special ammo quantity is not exposed to the watch inventory")

	_check(loadout.switch_relative(1), "weapon switch failed")
	_check(loadout.get_current_weapon().weapon_id == &"pistol", "pistol was not equipped")
	var magazine_before: int = loadout.get_magazine_ammo()
	_check(loadout.consume_round(), "firearm did not consume a round")
	_check(loadout.get_magazine_ammo() == magazine_before - 1, "magazine count did not change")
	_check(loadout.finish_reload(), "reload failed")
	_check(loadout.get_magazine_ammo() == magazine_before, "reload did not refill magazine")

	_check(player.apply_status_by_id(&"rain_exposure"), "rain exposure could not be applied")
	_check(statuses.has_status(&"rain_exposure"), "rain exposure missing after apply")
	_check(is_equal_approx(statuses.get_status_remaining(&"rain_exposure"), 15.0), "perk duration modifier was not applied")
	var status_count: int = statuses.get_active_statuses().size()
	player.apply_status_by_id(&"rain_exposure")
	_check(statuses.get_active_statuses().size() == status_count, "status refresh incorrectly stacked")

	player.health.set_health(50.0)
	_check(player.apply_status_by_id(&"bleeding"), "bleeding could not be applied for bandage test")
	_check(inventory.add_item(&"bandage"), "bandage should fit into an empty slot")
	_check(player.use_item(&"bandage"), "bandage use failed")
	_check(is_equal_approx(player.health.current_health, 50.0), "bandage resolved before the impact phase")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.impact_start_seconds())
	_check(is_equal_approx(player.health.current_health, 50.0), "bandage must not restore health")
	_check(not statuses.has_status(&"bleeding"), "bandage did not stop bleeding")
	_check(inventory.get_quantity(&"bandage") == 0, "bandage was not consumed")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.total_seconds())
	_check(inventory.add_item(&"bandage"), "bandage should fit into an empty slot")
	_check(inventory.select_slot(0), "could not select first inventory slot")
	var dropped_item: ItemDefinition = inventory.drop_selected_item()
	_check(dropped_item != null and dropped_item.item_id == &"bandage", "dropping selected slot should remove one bandage")
	_check(inventory.get_quantity(&"bandage") == 0, "dropped bandage remained in inventory")
	_check(inventory.add_item_definition(dropped_item), "dropped bandage should fit when picked back up")
	_check(inventory.get_quantity(&"bandage") == 1, "picked-up dropped bandage was not restored")
	player._drop_selected_inventory_item()
	await get_tree().process_frame
	var dropped_world_pickup: WorldPickup
	for child: Node in get_tree().current_scene.get_children():
		if child is WorldPickup:
			dropped_world_pickup = child as WorldPickup
			break
	_check(dropped_world_pickup != null, "dropping an item did not create a world pickup")
	if dropped_world_pickup != null:
		dropped_world_pickup._on_interacted(player)
		_check(inventory.get_quantity(&"bandage") == 1, "dropped world pickup could not be collected")

	_check(inventory.add_item(&"medkit"), "medkit could not be added to the backpack")
	player.health.set_health(30.0)
	_check(player.use_item(&"medkit"), "medkit use failed")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.impact_start_seconds())
	_check(is_equal_approx(player.health.current_health, 90.0), "medkit healing value is incorrect")
	_check(inventory.get_quantity(&"medkit") == 0, "medkit was not consumed")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.total_seconds())
	_check(inventory.add_item(&"medkit"), "medkit could not be restored for held item test")
	_check(inventory.select_slot(1), "could not select the held medkit slot")
	player._sync_held_item()
	_check(player.first_person_arms.held_item_id == &"medkit", "selecting a backpack item did not enter held state")
	var held_item_input := PlayerInputReader.new()
	held_item_input.wants_primary_attack = true
	var medkits_before_cancel: int = inventory.get_quantity(&"medkit")
	player.interaction_state_machine.update_held_item_use(
		player, &"medkit", held_item_input, {}, player.combat_definition.interact_timing.impact_start_seconds() * 0.5
	)
	held_item_input.wants_primary_attack = false
	player.interaction_state_machine.update_held_item_use(player, &"medkit", held_item_input, {}, 0.0)
	_check(inventory.get_quantity(&"medkit") == medkits_before_cancel, "releasing item use early consumed the item")
	held_item_input.wants_primary_attack = true
	player.health.set_health(40.0)
	player.interaction_state_machine.update_held_item_use(
		player, &"medkit", held_item_input, {}, player.combat_definition.interact_timing.impact_start_seconds()
	)
	_check(inventory.get_quantity(&"medkit") == medkits_before_cancel - 1, "held item use did not consume at the progress completion point")
	_check(is_equal_approx(player.health.current_health, 100.0), "held item use did not apply its effect")
	player.interaction_state_machine.cancel_held_item_use()
	inventory.clear_selection()
	player._sync_held_item()
	_check(player.first_person_arms.held_item_id == &"", "clearing item selection did not return to empty hand")

	inventory.add_item(&"food_ration")
	var food_slot_count: int = 0
	for slot: Dictionary in inventory.get_slot_snapshots():
		if StringName(slot.get("item_id", &"")) == &"food_ration":
			food_slot_count += 1
	_check(food_slot_count == 0, "food must not occupy a backpack slot")
	_check(inventory.get_special_items().get(&"food_ration", 0) == inventory.get_quantity(&"food_ration"), "food quantity is not exposed to the watch inventory")
	player.health.set_health(45.0)
	player.hunger.set_hunger(40.0)
	_check(player.use_item(&"food_ration"), "food ration use failed")
	_check(is_equal_approx(player.hunger.current_hunger, 40.0), "food ration resolved before the impact phase")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.impact_start_seconds())
	_check(is_equal_approx(player.hunger.current_hunger, 75.0), "food ration restore value is incorrect")
	_check(is_equal_approx(player.health.current_health, 45.0), "food ration must not restore health")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.total_seconds())
	var health_before_invalid_item: float = player.health.current_health
	_check(not player.use_item(&"unknown_item"), "unknown item was accepted")
	_check(is_equal_approx(player.health.current_health, health_before_invalid_item), "unknown item changed health")
	inventory.add_item(&"food_ration")
	var food_before_blocked_use: int = inventory.get_quantity(&"food_ration")
	_check(
		not player.interaction_state_machine.request_item_use(player, &"food_ration", {"blocked_action_ids": [&"use_item"]}),
		"blocked item use entered the interaction state"
	)
	_check(inventory.get_quantity(&"food_ration") == food_before_blocked_use, "blocked item use consumed inventory")

	var container: LootContainer = LOOT_CONTAINER_SCENE.instantiate() as LootContainer
	add_child(container)
	await get_tree().process_frame
	var container_payload: Dictionary[StringName, int] = container.open()
	_check(not container_payload.is_empty(), "loot container did not resolve any items")
	_check(container.has_been_opened, "loot container did not retain opened state")
	_check(container.open().is_empty(), "one-shot loot container opened more than once")
	var pickup_count: int = 0
	for child: Node in container.get_children():
		if child is WorldPickup:
			pickup_count += 1
	_check(pickup_count > 0, "loot container did not spawn world pickups")
	for child: Node in container.get_children():
		if child is WorldPickup:
			var pickup: WorldPickup = child as WorldPickup
			var stale_target: InteractableComponent = pickup.interactable
			var pickup_item_id: StringName = pickup.item.item_id
			var quantity_before_pickup: int = inventory.get_quantity(pickup_item_id)
			player.interaction_state_machine._pending_actor = player
			player.interaction_state_machine._pending_target = stale_target
			player.interaction_state_machine._pending_item_id = &""
			player.interaction_state_machine._action_elapsed = player.combat_definition.interact_timing.impact_start_seconds()
			player.interaction_state_machine._action_resolved = false
			pickup._on_interacted(player)
			_check(inventory.get_quantity(pickup_item_id) > quantity_before_pickup, "world pickup did not enter inventory")
			await get_tree().process_frame
			player.interaction_state_machine._resolve_instant_use_if_due()
			_check(
				player.interaction_state_machine.current_state == PlayerInteractionStateMachine.STATE_NONE,
				"released pickup target should cancel the pending interaction"
			)
			break
	container.queue_free()

	print("PLAYER_SYSTEM_SMOKE: PASS")
	get_tree().quit()


func _check_arm_elbow_direction(arms: PlayerFirstPersonArms, player: Player3DController) -> void:
	var combat: PlayerCombatDefinition = player.combat_definition
	var movement: PlayerMovementDefinition = player.movement_definition
	var primary_timing: ActionTimingDefinition = player.combat_driver.get_primary_timing()
	var skill: PlayerActiveSkillDefinition = player.profession_component.get_active_skill()
	_check_elbows_bend_upward(arms, "idle")
	await _check_light_attacks_hold_left_hand_horizontally(arms, primary_timing)
	await _check_revised_arm_action_shapes(arms, combat)
	await _sample_arm_action(arms, arms.play_attack.bind(1, primary_timing), "light attack 1")
	await _sample_arm_action(arms, arms.play_attack.bind(2, primary_timing), "light attack 2")
	await _sample_arm_action(arms, arms.play_attack.bind(3, primary_timing), "light attack 3")
	await _sample_arm_action(arms, arms.play_heavy_attack.bind(combat.heavy_attack_timing), "heavy attack")
	await _sample_arm_action(arms, arms.play_shove.bind(combat.shove_timing), "shove")
	await _sample_arm_action(arms, arms.play_parry.bind(combat.parry_timing), "parry")
	await _sample_arm_action(arms, arms.play_parry_success.bind(combat.parry_success_timing), "parry success")
	await _sample_arm_action(arms, arms.play_interact.bind(combat.interact_timing), "interact")
	await _sample_arm_action(arms, arms.play_charged_beam.bind(skill.action_timing), "charged skill")
	await _sample_arm_action(arms, arms.play_hurt.bind(combat.hurt_timing), "hurt")
	await _sample_arm_action(arms, arms.play_sprint_start.bind(movement.sprint_start_timing), "sprint start")
	await _sample_arm_action(arms, arms.play_jump.bind(movement.jump_timing), "jump")
	await _sample_arm_action(arms, arms.play_slide.bind(movement.slide_timing), "slide")
	await get_tree().create_timer(movement.slide_timing.total_seconds() + 0.05).timeout
	var right_shoulder_before_sprint: float = arms.right_shoulder.rotation.x
	var left_shoulder_before_sprint: float = arms.left_shoulder.rotation.x
	arms.set_sprinting(true)
	arms._update_sprint_pose(0.25)
	_check_elbows_bend_upward(arms, "sprint loop")
	_check(
		arms.right_shoulder.rotation.x < right_shoulder_before_sprint,
		"sprint should lower the right arm from the shoulder; before=%.3f sprint=%.3f root_lock=%.3f" % [right_shoulder_before_sprint, arms.right_shoulder.rotation.x, arms._root_motion_time_remaining]
	)
	_check(
		arms.left_shoulder.rotation.x < left_shoulder_before_sprint,
		"sprint should lower the left arm from the shoulder; before=%.3f sprint=%.3f root_lock=%.3f" % [left_shoulder_before_sprint, arms.left_shoulder.rotation.x, arms._root_motion_time_remaining]
	)
	arms.set_sprinting(false)


func _check_sprint_entry_uses_loop_pose(player: Player3DController, arms: PlayerFirstPersonArms) -> void:
	arms._reset_action_tween()
	arms._reset_root_tween()
	arms._root_motion_time_remaining = 0.0
	arms.current_action_timing = null
	var right_shoulder_before: float = arms.right_shoulder.rotation.x
	player._on_locomotion_state_changed(
		PlayerLocomotionStateMachine.STATE_WALK,
		PlayerLocomotionStateMachine.STATE_SPRINT
	)
	_check(arms.current_action_timing == null, "entering sprint must not start a one-shot arm animation")
	arms.set_sprinting(true)
	arms._update_sprint_pose(1.0 / 30.0)
	var first_frame_delta: float = absf(arms.right_shoulder.rotation.x - right_shoulder_before)
	_check(first_frame_delta < 0.20, "sprint loop snapped the right shoulder by %.3f radians on entry" % first_frame_delta)
	arms.set_sprinting(false)
	arms._reset_pose()
	arms.position = arms._base_position


func _check_light_attacks_hold_left_hand_horizontally(arms: PlayerFirstPersonArms, timing: ActionTimingDefinition) -> void:
	var left_hand: Node3D = arms.get_node("LeftShoulder/LeftElbow/LeftHandSocket") as Node3D
	var left_elbow: Node3D = arms.get_node("LeftShoulder/LeftElbow") as Node3D
	for combo: int in range(1, 4):
		var shoulder_before: Vector3 = arms.left_shoulder.rotation
		var elbow_before: Vector3 = arms.left_elbow.rotation
		var hand_before: Vector3 = arms.to_local(left_hand.global_position)
		arms.play_attack(combo, timing)
		await get_tree().create_timer(timing.windup_seconds + timing.release_seconds * 0.35).timeout
		var shoulder_guard: Vector3 = arms.left_shoulder.rotation
		var elbow_guard: Vector3 = arms.left_elbow.rotation
		var hand_guard: Vector3 = arms.to_local(left_hand.global_position)
		var elbow_position: Vector3 = arms.to_local(left_elbow.global_position)
		_check(absf(shoulder_guard.y - shoulder_before.y) > 0.35, "light attack %d did not place the left arm horizontally" % combo)
		_check(elbow_guard.x >= PlayerFirstPersonArms.ELBOW_LOWEST_ROTATION_X - 0.001, "light attack %d bent the left forearm downward" % combo)
		_check(absf(elbow_guard.y - elbow_before.y) > 0.8, "light attack %d did not turn the left forearm across the chest" % combo)
		_check(absf(hand_guard.x) < absf(hand_before.x), "light attack %d did not draw the left hand across the chest" % combo)
		_check(
			absf(hand_guard.y - elbow_position.y) < 0.18,
			"light attack %d left forearm is not horizontal across the chest; hand=%s elbow=%s" % [combo, hand_guard, elbow_position]
		)
		await get_tree().create_timer(timing.release_seconds * 0.45).timeout
		var shoulder_drift_degrees: float = rad_to_deg(arms.left_shoulder.rotation.distance_to(shoulder_guard))
		var elbow_drift_degrees: float = rad_to_deg(arms.left_elbow.rotation.distance_to(elbow_guard))
		_check(shoulder_drift_degrees < 0.5, "light attack %d let the horizontal left shoulder drift %.3f degrees" % [combo, shoulder_drift_degrees])
		_check(elbow_drift_degrees < 0.5, "light attack %d let the horizontal left elbow drift %.3f degrees" % [combo, elbow_drift_degrees])
		await get_tree().create_timer(timing.release_seconds * 0.2 + timing.impact_seconds + timing.recovery_seconds + 0.03).timeout


func _check_revised_arm_action_shapes(arms: PlayerFirstPersonArms, combat: PlayerCombatDefinition) -> void:
	var heavy: ActionTimingDefinition = combat.heavy_attack_timing
	arms.play_heavy_attack(heavy)
	await get_tree().create_timer(heavy.windup_seconds * 0.78).timeout
	var overhead_shoulder: Vector3 = arms.right_shoulder.rotation
	var overhead_elbow: Vector3 = arms.right_elbow.rotation
	var right_hand: Node3D = arms.get_node("RightShoulder/RightElbow/RightHandSocket") as Node3D
	_check(
		overhead_shoulder.x > 1.0 and overhead_elbow.x > 1.5,
		"heavy attack must lift the right hand over the head; shoulder=%s elbow=%s hand_y=%.3f" % [overhead_shoulder, overhead_elbow, right_hand.position.y]
	)
	await get_tree().create_timer(heavy.windup_seconds * 0.12).timeout
	_check(arms.right_shoulder.rotation.is_equal_approx(overhead_shoulder), "heavy attack must hold the overhead charge pose")
	_check(arms.right_elbow.rotation.is_equal_approx(overhead_elbow), "heavy attack elbow drifted during the overhead hold")
	await get_tree().create_timer(heavy.windup_seconds * 0.1 + heavy.release_seconds + heavy.impact_seconds + heavy.recovery_seconds + 0.05).timeout

	var shove: ActionTimingDefinition = combat.shove_timing
	_check(shove.release_seconds < shove.windup_seconds, "shove release must stay faster than its windup")
	_check(shove.recovery_seconds > shove.release_seconds * 4.0, "shove must use a slow recovery after the fast release")
	_check(shove.total_seconds() >= 0.5, "shove rhythm must be slower overall")
	var left_hand: Node3D = arms.get_node("LeftShoulder/LeftElbow/LeftHandSocket") as Node3D
	var right_hand_socket: Node3D = arms.get_node("RightShoulder/RightElbow/RightHandSocket") as Node3D
	arms.play_shove(shove)
	await get_tree().create_timer(shove.windup_seconds + 0.005).timeout
	var shove_left_windup_z: float = left_hand.global_position.z
	var shove_right_windup_z: float = right_hand_socket.global_position.z
	await get_tree().create_timer(shove.release_seconds + 0.005).timeout
	_check(
		left_hand.global_position.z < shove_left_windup_z - 0.16,
		"shove must drive the left hand forward; windup=%.3f release=%.3f" % [shove_left_windup_z, left_hand.global_position.z]
	)
	_check(
		right_hand_socket.global_position.z < shove_right_windup_z - 0.16,
		"shove must drive the right hand forward; windup=%.3f release=%.3f" % [shove_right_windup_z, right_hand_socket.global_position.z]
	)
	await get_tree().create_timer(shove.impact_seconds + shove.recovery_seconds + 0.03).timeout

	var interact: ActionTimingDefinition = combat.interact_timing
	var right_hand_before: Vector3 = arms.to_local(right_hand_socket.global_position)
	var left_hand_before: Vector3 = arms.to_local(left_hand.global_position)
	arms.play_interact(interact)
	await get_tree().create_timer(interact.windup_seconds + 0.01).timeout
	var right_hand_retracted: Vector3 = arms.to_local(right_hand_socket.global_position)
	var left_hand_reaching: Vector3 = arms.to_local(left_hand.global_position)
	_check(
		left_hand_reaching.z < left_hand_before.z - 0.015,
		"interaction must extend the left hand forward; before=%s reaching=%s" % [left_hand_before, left_hand_reaching]
	)
	_check(
		right_hand_retracted.z > right_hand_before.z + 0.20,
		"interaction must move the right hand behind the body; before=%s retracted=%s" % [right_hand_before, right_hand_retracted]
	)
	_check(
		right_hand_retracted.y < right_hand_before.y + 0.08,
		"interaction must not lift the retracted right hand; before=%s retracted=%s" % [right_hand_before, right_hand_retracted]
	)


func _check_held_combo_cadence(player: Player3DController) -> void:
	var driver: PlayerCombatDriver = player.combat_driver
	var weapon: WeaponDefinition = driver.current_weapon
	_check(weapon != null and weapon.held_combo_timing != null, "melee weapon held-combo timing contract missing")
	driver.combo_index = 0
	driver.combo_time_remaining = 0.0
	driver.combo_finisher_cooldown_remaining = 0.0
	player.stamina.current_stamina = player.stamina.max_stamina
	_check(driver.begin_primary_attack(), "held combo first attack could not start")
	_check(driver.get_primary_timing(true) == weapon.primary_timing, "held combo must keep the normal first-hit timing")
	_check(driver.begin_primary_attack(), "held combo second attack could not start")
	_check(driver.get_primary_timing(true) == weapon.held_combo_timing, "held combo second hit did not use its faster shared timing contract")
	_check(driver.begin_primary_attack(), "held combo third attack could not start")
	_check(driver.get_primary_timing(true) == weapon.held_combo_timing, "held combo third hit did not use its faster shared timing contract")
	driver.finish_primary_attack()
	_check(driver.combo_finisher_cooldown_remaining > 0.0, "third light hit did not enter finisher cooldown")
	var stamina_during_cooldown: float = player.stamina.current_stamina
	_check(not driver.begin_primary_attack(), "light attack restarted during the third-hit cooldown")
	_check(is_equal_approx(player.stamina.current_stamina, stamina_during_cooldown), "blocked finisher cooldown consumed stamina")
	driver.tick(player.combat_definition.combo_finisher_cooldown_seconds + 0.001)
	_check(driver.begin_primary_attack(), "light combo did not unlock after finisher cooldown")
	_check(driver.combo_index == 1, "light combo did not restart from hit one after finisher cooldown")
	driver.combo_index = 0
	driver.combo_time_remaining = 0.0
	driver.combo_finisher_cooldown_remaining = 0.0
	player.stamina.current_stamina = player.stamina.max_stamina


func _check_action_timing_contract(player: Player3DController, arms: PlayerFirstPersonArms) -> void:
	var weapon: WeaponDefinition = player.combat_driver.current_weapon
	_check(weapon != null and weapon.primary_timing != null, "equipped weapon timing contract missing")
	_check(player.combat_driver.get_primary_timing() == weapon.primary_timing, "gameplay must use the weapon timing resource instance")
	_check(
		is_equal_approx(player.combat_driver.get_primary_action_duration(), weapon.primary_timing.total_seconds()),
		"primary action duration must come from the four-phase contract"
	)
	_check(
		is_equal_approx(player.movement_definition.slide_timing.total_seconds(), 0.35),
		"slide gameplay duration must come from the movement timing contract"
	)
	_check(
		is_equal_approx(player.floor_max_angle, deg_to_rad(player.movement_definition.max_walkable_slope_degrees)),
		"player slope limit must come from the movement definition"
	)
	_check(
		player.combat_definition.heavy_attack_timing.windup_seconds > weapon.primary_timing.windup_seconds,
		"heavy attack windup should be longer than the equipped light attack windup"
	)
	var target := ActionTarget.new()
	target.position = Vector3(0.0, 0.0, -1.0)
	add_child(target)
	_check(player.combat_driver.begin_primary_attack(), "primary attack should begin for timing test")
	player.combat_state_machine._start_action(
		player,
		PlayerCombatStateMachine.STATE_LIGHT_ATTACK,
		weapon.primary_timing
	)
	_check(arms.current_action_timing == weapon.primary_timing, "animation and gameplay must share the same timing instance")
	player.combat_state_machine._tick_action(player, weapon.primary_timing.impact_start_seconds() - 0.001)
	_check(target.received_hits == 0, "primary attack resolved before the impact phase")
	player.combat_state_machine._tick_action(player, 0.002)
	_check(target.received_hits == 1, "primary attack did not resolve at the impact phase")
	player.combat_state_machine.interrupt()
	player.input_reader.secondary_attack_buffered = true
	player.combat_state_machine.update(player, player.input_reader, {}, 0.0)
	_check(player.combat_state_machine.current_state == PlayerCombatStateMachine.STATE_HEAVY_ATTACK, "secondary attack should enter the heavy attack state")
	_check(player.combat_state_machine.current_action_timing == player.combat_definition.heavy_attack_timing, "heavy gameplay and animation must share the heavy timing resource")
	_check(arms.current_action_timing == player.combat_definition.heavy_attack_timing, "heavy arm animation must consume the gameplay timing resource")
	player.combat_state_machine._tick_action(player, player.combat_definition.heavy_attack_timing.impact_start_seconds() + 0.001)
	_check(target.received_hits == 2, "heavy attack did not resolve at the impact phase")
	_check(target.last_hit != null and target.last_hit.amount > weapon.base_damage, "heavy attack should deal more damage than a light attack")
	player.combat_state_machine.interrupt()
	target.queue_free()


func _sample_arm_action(arms: PlayerFirstPersonArms, action: Callable, action_name: String) -> void:
	action.call()
	await get_tree().create_timer(0.03).timeout
	_check_elbows_bend_upward(arms, action_name)


func _check_elbows_bend_upward(arms: PlayerFirstPersonArms, action_name: String) -> void:
	var lowest_rotation: float = PlayerFirstPersonArms.ELBOW_LOWEST_ROTATION_X - 0.001
	_check(arms.right_elbow.rotation.x >= lowest_rotation, "%s bends the right elbow downward" % action_name)
	_check(arms.left_elbow.rotation.x >= lowest_rotation, "%s bends the left elbow downward" % action_name)


func _check_debug_god_mode(player: Player3DController) -> void:
	var buff_resolver: Node = get_node_or_null("/root/BuffResolver")
	var damage_resolver: Node = get_node_or_null("/root/DamageResolver")
	_check(buff_resolver != null and damage_resolver != null, "damage services missing for god mode test")
	var baseline_constraints: Dictionary = buff_resolver.call("get_constraints", player)
	var baseline_outgoing: float = float(baseline_constraints["outgoing_damage_multiplier"])

	var toggle_event: InputEventAction = InputEventAction.new()
	toggle_event.action = &"debug_god_mode"
	toggle_event.pressed = true
	player._unhandled_input(toggle_event)
	_check(player.debug_god_mode_enabled, "9 action should enable god mode")

	var god_constraints: Dictionary = buff_resolver.call("get_constraints", player)
	_check(
		is_equal_approx(float(god_constraints["outgoing_damage_multiplier"]), baseline_outgoing * 5.0),
		"god mode should multiply all player outgoing damage by five"
	)
	_check(is_zero_approx(float(god_constraints["incoming_damage_multiplier"])), "god mode should zero incoming damage")

	var health_before: float = player.health.current_health
	var incoming: DamageEventData = DamageEventData.new()
	incoming.attacker_id = get_instance_id()
	incoming.target_id = player.get_instance_id()
	incoming.amount = 9999.0
	incoming.source_tags = [&"enemy", &"melee"]
	player.receive_damage(incoming)
	_check(is_equal_approx(player.health.current_health, health_before), "god mode should prevent health loss")

	var target: DamageTarget = DamageTarget.new()
	add_child(target)
	await get_tree().process_frame
	var outgoing: DamageEventData = DamageEventData.new()
	outgoing.attacker_id = player.get_instance_id()
	outgoing.target_id = target.get_instance_id()
	outgoing.amount = 10.0
	var result: DamageResolutionData = damage_resolver.call("resolve_damage", outgoing, target) as DamageResolutionData
	_check(result != null and is_equal_approx(result.final_amount, 10.0 * baseline_outgoing * 5.0), "god mode x5 should apply in DamageResolver")
	target.queue_free()
	await get_tree().process_frame

	player._unhandled_input(toggle_event)
	_check(not player.debug_god_mode_enabled, "pressing 9 again should disable god mode")
	health_before = player.health.current_health
	incoming.amount = 5.0
	player.receive_damage(incoming)
	_check(player.health.current_health < health_before, "damage should apply again after god mode is disabled")


func _check_parry_success_animation_feedback(player: Player3DController) -> void:
	var camera: Camera3D = player.camera_rig.camera
	var camera_transform: Transform3D = camera.transform
	var arms: PlayerFirstPersonArms = player.first_person_arms
	var arms_position: Vector3 = arms.position
	player.play_parry_success_feedback()
	_check(not arms.position.is_equal_approx(arms_position), "parry success should shake the arm animation")
	_check(camera.transform.is_equal_approx(camera_transform), "parry success must not shake the camera")
	await get_tree().create_timer(player.combat_definition.parry_success_timing.total_seconds() + 0.05).timeout
	_check(camera.transform.is_equal_approx(camera_transform), "parry success must leave the camera unchanged")


func _action_has_key(action_name: StringName, keycode: Key) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _action_has_mouse(action_name: StringName, button: MouseButton) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("PLAYER_SYSTEM_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)
