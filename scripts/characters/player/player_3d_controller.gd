class_name Player3DController
extends CharacterBody3D

const WORLD_PICKUP_SCENE: PackedScene = preload("res://scenes/interactables/world_pickup.tscn")

@export var movement_definition: PlayerMovementDefinition
@export var combat_definition: PlayerCombatDefinition

@onready var input_reader: PlayerInputReader = %InputReader
@onready var camera_rig: PlayerCameraRig = %CameraRig
@onready var movement_motor: PlayerMovementMotor = %MovementMotor
@onready var combat_driver: PlayerCombatDriver = %CombatDriver
@onready var interaction_driver: PlayerInteractionDriver = %InteractionDriver
@onready var health: HealthComponent = %HealthComponent
@onready var stamina: StaminaComponent = %StaminaComponent
@onready var sprint_reserve: SprintReserveComponent = %SprintReserveComponent
@onready var hunger: HungerComponent = %HungerComponent
@onready var status_container: StatusContainer = %StatusContainer
@onready var inventory_component: PlayerInventoryComponent = %PlayerInventoryComponent
@onready var loadout_component: PlayerLoadoutComponent = %PlayerLoadoutComponent
@onready var profession_component: PlayerProfessionComponent = %ProfessionComponent
@onready var skill_component: PlayerSkillComponent = %PlayerSkillComponent
@onready var locomotion_state_machine: PlayerLocomotionStateMachine = %LocomotionStateMachine
@onready var combat_state_machine: PlayerCombatStateMachine = %CombatStateMachine
@onready var interaction_state_machine: PlayerInteractionStateMachine = %InteractionStateMachine
@onready var condition_state_machine: PlayerConditionStateMachine = %PlayerConditionStateMachine
@onready var watch_state_machine: PlayerWatchStateMachine = %WatchStateMachine
@onready var first_person_arms: PlayerFirstPersonArms = %FirstPersonArms
@onready var body_visual: Node3D = %PlayerBodyVisual

var _event_bus = null
var _game_manager = null
var _buff_resolver: Node
var _damage_resolver: Node
var debug_god_mode_enabled: bool = false
var _held_item_id: StringName = &""
var _footstep_elapsed: float = 0.0
var _footstep_audio_active: bool = false


func _ready() -> void:
	add_to_group("player")
	_event_bus = get_node_or_null("/root/EventBus")
	_game_manager = get_node_or_null("/root/GameManager")
	_buff_resolver = get_node_or_null("/root/BuffResolver")
	_damage_resolver = get_node_or_null("/root/DamageResolver")
	if _event_bus != null:
		_event_bus.phase_changed.connect(_on_phase_changed)
		_event_bus.watch_item_use_requested.connect(_on_watch_item_use_requested)

	_apply_definitions()
	_initialize_runtime_components()
	if _buff_resolver != null:
		_buff_resolver.call("bind_container", self, status_container)
	_apply_profession_statuses()
	# Mouse is not captured by default — player clicks to capture

	health.died.connect(_on_died)
	locomotion_state_machine.state_changed.connect(_on_locomotion_state_changed)
	combat_state_machine.state_changed.connect(_on_combat_state_changed)
	combat_state_machine.action_phase_changed.connect(_on_combat_action_phase_changed)
	combat_driver.light_combo_ended.connect(_on_light_combo_ended)
	combat_driver.firearm_fired.connect(_on_firearm_fired)
	interaction_state_machine.state_changed.connect(_on_interaction_state_changed)
	watch_state_machine.state_changed.connect(_on_watch_state_changed)
	skill_component.active_skill_charge_started.connect(_on_active_skill_charge_started)
	skill_component.active_skill_triggered.connect(_on_active_skill_triggered)
	skill_component.action_blocked.connect(_on_action_blocked)


func _exit_tree() -> void:
	if _event_bus == null:
		return
	if _event_bus.phase_changed.is_connected(_on_phase_changed):
		_event_bus.phase_changed.disconnect(_on_phase_changed)
	if _event_bus.watch_item_use_requested.is_connected(_on_watch_item_use_requested):
		_event_bus.watch_item_use_requested.disconnect(_on_watch_item_use_requested)


func _input(event: InputEvent) -> void:
	if watch_state_machine.is_active():
		if event.is_action_pressed("watch") or event.is_action_pressed("ui_cancel"):
			watch_state_machine.close()
			get_viewport().set_input_as_handled()
		return
	if camera_rig.recapture_from_click(event):
		get_viewport().set_input_as_handled()
		return

	if _capture_mouse_gameplay_action(event):
		get_viewport().set_input_as_handled()
		return

	if camera_rig.handle_look(event, self):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_god_mode"):
		set_debug_god_mode(not debug_god_mode_enabled)
		get_viewport().set_input_as_handled()
		return
	input_reader.handle_input(event)

	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	input_reader.refresh()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and combat_driver.is_current_firearm():
		input_reader.wants_primary_attack = false
		input_reader.primary_attack_buffered = false
	_sync_survival_statuses()
	_update_watch_state()
	_process_quick_slot_input()
	movement_motor.tick_timers(delta, is_on_floor())
	movement_motor.apply_gravity(self, delta)

	var constraints: Dictionary = _buff_resolver.call("get_constraints", self) if _buff_resolver != null else {}
	constraints = condition_state_machine.update(constraints)
	if stamina != null:
		stamina.recovery_multiplier = maxf(0.0, float(constraints.get("stamina_recovery_multiplier", 1.0)))
	_merge_constraints(constraints, watch_state_machine.update())
	_merge_constraints(constraints, skill_component.update(self, input_reader, constraints, delta))
	_update_held_item_state(constraints, delta)

	if interaction_state_machine.current_state != PlayerInteractionStateMachine.STATE_ITEM_USE:
		interaction_state_machine.update(self, input_reader, constraints, delta)
	_update_firearm_handling(constraints, delta)
	combat_state_machine.update(self, input_reader, constraints, delta)
	locomotion_state_machine.physics_update(self, input_reader, constraints, delta)
	_emit_footstep_if_due(delta)
	body_visual.update_locomotion(
		Vector2(velocity.x, velocity.z).length(),
		locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT,
		delta
	)
	camera_rig.update_motion_feedback(locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT, delta)
	_call_arms(&"set_sprinting", [locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT])
	_consume_deferred_inputs()

	move_and_slide()


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var damage: DamageEventData = DamageEventData.new()
	damage.target_id = get_instance_id()
	damage.amount = amount
	damage.damage_type = &"environmental"
	damage.source_tags = [&"legacy_apply_damage"]
	damage.bypass_outgoing_modifiers = true
	receive_damage(damage)


func apply_status(status: StatusEffectDefinition, duration_override: float = -1.0) -> bool:
	return _buff_resolver != null and bool(
		_buff_resolver.call("apply_status", self, status, duration_override, get_instance_id())
	)


func apply_status_by_id(status_id: StringName, duration_override: float = -1.0) -> bool:
	return _buff_resolver != null and bool(
		_buff_resolver.call("apply_status_by_id", self, status_id, duration_override, get_instance_id())
	)


func receive_loot(payload: Dictionary) -> void:
	if inventory_component != null:
		inventory_component.add_loot(payload)


func remove_status(status_id: StringName) -> void:
	if _buff_resolver != null:
		_buff_resolver.call("remove_status", self, status_id)


func has_status(status_id: StringName) -> bool:
	return _buff_resolver != null and bool(_buff_resolver.call("has_status", self, status_id))


func receive_damage(data: DamageEventData) -> void:
	if _damage_resolver != null:
		_damage_resolver.call("resolve_damage", data, self)


func try_block_damage(data: DamageEventData) -> bool:
	if debug_god_mode_enabled:
		return true
	if not combat_state_machine.parry_active or not data.source_tags.has(&"melee"):
		return false
	_apply_parry_counter(data)
	play_parry_success_feedback()
	if _event_bus != null:
		_event_bus.combat_audio.emit(&"parry", global_position, 1.0)
		_event_bus.debug_test_notice.emit("Parry success: blocked %.0f damage" % data.amount, &"combat")
		_event_bus.combat_feedback.emit("PARRY SUCCESS", &"success")
	return true


func play_parry_success_feedback() -> void:
	var timing: ActionTimingDefinition = combat_definition.parry_success_timing
	_call_arms(&"play_parry_success", [timing])


func on_damage_resolved(result: DamageResolutionData) -> void:
	if result.blocked or not result.applied:
		return
	var is_periodic: bool = result.event.source_tags.has(&"periodic")
	if is_periodic:
		return
	combat_state_machine.interrupt()
	if result.final_amount > 0.0:
		_emit_debug_notice("Player hit: -%.0f HP" % result.final_amount, &"combat")
		if _event_bus != null:
			_event_bus.combat_audio.emit(&"hurt", global_position, clampf(result.final_amount / 20.0, 0.25, 2.0))
			_event_bus.combat_feedback.emit("HIT -%.0f" % result.final_amount, &"danger")
		_call_arms(&"play_hurt", [combat_definition.hurt_timing])
	if result.event.stagger >= combat_definition.stagger_threshold:
		apply_status_by_id(&"staggered")
	if result.final_amount >= combat_definition.bleeding_damage_threshold:
		apply_status_by_id(&"bleeding")


func get_health_component() -> HealthComponent:
	return health


func get_stamina_component() -> StaminaComponent:
	return stamina


func get_hunger_component() -> HungerComponent:
	return hunger


func get_status_container() -> StatusContainer:
	return status_container


func is_status_immune(status_id: StringName) -> bool:
	var immune: bool = profession_component != null and profession_component.is_status_immune(status_id)
	if immune:
		_emit_action_blocked(&"status", &"status_immune")
	return immune


func get_status_duration_multiplier(status_id: StringName) -> float:
	if profession_component == null:
		return 1.0
	return profession_component.get_status_duration_multiplier(status_id)


func amend_buff_constraints(constraints: Dictionary) -> void:
	_apply_profession_constraints(constraints)
	if debug_god_mode_enabled:
		constraints["outgoing_damage_multiplier"] = float(
			constraints.get("outgoing_damage_multiplier", 1.0)
		) * 5.0
		constraints["incoming_damage_multiplier"] = 0.0


func set_debug_god_mode(enabled: bool) -> void:
	if debug_god_mode_enabled == enabled:
		return
	debug_god_mode_enabled = enabled
	var state_text: String = "ON - DAMAGE x5" if enabled else "OFF"
	_emit_debug_notice("Invincible mode %s" % state_text, &"debug")
	if _event_bus != null:
		_event_bus.combat_feedback.emit("INVINCIBLE %s" % state_text, &"success" if enabled else &"neutral")


func heal(amount: float) -> void:
	health.heal(amount)


func is_alive() -> bool:
	return health != null and health.is_alive()


func _apply_definitions() -> void:
	if movement_definition != null:
		floor_max_angle = deg_to_rad(movement_definition.max_walkable_slope_degrees)
		camera_rig.movement_definition = movement_definition
		movement_motor.movement_definition = movement_definition
		locomotion_state_machine.movement_definition = movement_definition
		if sprint_reserve != null:
			sprint_reserve.max_reserve = movement_definition.sprint_reserve_max
			sprint_reserve.current_reserve = sprint_reserve.max_reserve
			sprint_reserve.recovery_per_second = movement_definition.sprint_reserve_recovery_per_second
			sprint_reserve.recovery_delay_seconds = movement_definition.sprint_reserve_recovery_delay_seconds

	if combat_definition != null:
		combat_driver.combat_definition = combat_definition
		combat_state_machine.combat_definition = combat_definition
		if stamina != null:
			stamina.recovery_delay_seconds = combat_definition.stamina_recovery_delay_seconds


func _initialize_runtime_components() -> void:
	if profession_component == null:
		return
	if inventory_component != null:
		inventory_component.initialize(
			profession_component.get_starting_item_ids(),
			profession_component.get_stat_multiplier(&"ammo_pickup")
		)
	if loadout_component != null:
		loadout_component.initialize(profession_component.get_starting_weapon_ids())


func _apply_profession_constraints(constraints: Dictionary) -> void:
	if profession_component == null:
		return
	constraints["blocked_action_ids"] = profession_component.get_blocked_action_ids()
	constraints["outgoing_damage_multiplier"] = float(constraints.get("outgoing_damage_multiplier", 1.0)) * profession_component.get_stat_multiplier(&"outgoing_damage")
	constraints["movement_speed_multiplier"] = float(constraints.get("movement_speed_multiplier", 1.0)) * profession_component.get_stat_multiplier(&"movement_speed")
	constraints["stamina_recovery_multiplier"] = float(constraints.get("stamina_recovery_multiplier", 1.0)) * profession_component.get_stat_multiplier(&"stamina_recovery")
	constraints["firearm_spread_multiplier"] = profession_component.get_stat_multiplier(&"firearm_stability")


func _apply_profession_statuses() -> void:
	if status_container == null or profession_component == null:
		return
	if profession_component.profession_definition == null:
		return
	for status_id: StringName in profession_component.profession_definition.status_ids_on_spawn:
		apply_status_by_id(status_id)


func _sync_survival_statuses() -> void:
	if hunger != null:
		if hunger.current_hunger <= 0.0 and not has_status(&"hungry"):
			apply_status_by_id(&"hungry")
		elif hunger.current_hunger > 0.0:
			remove_status(&"hungry")
	if sprint_reserve != null:
		if sprint_reserve.current_reserve <= 0.0 and not has_status(&"exhausted"):
			apply_status_by_id(&"exhausted")
		elif sprint_reserve.current_reserve >= sprint_reserve.max_reserve:
			remove_status(&"exhausted")


func use_item(item_id: StringName) -> bool:
	if inventory_component == null or not inventory_component.can_use_item(item_id):
		_emit_action_blocked(&"use_item", &"item_unavailable")
		return false
	var constraints: Dictionary = _get_item_use_constraints()
	if not interaction_state_machine.request_item_use(self, item_id, constraints):
		_emit_action_blocked(&"use_item", &"action_busy")
		return false
	return true


func resolve_item_use(item_id: StringName) -> bool:
	if inventory_component == null:
		return false
	var item: ItemDefinition = inventory_component.consume_item(item_id)
	if item == null:
		_emit_action_blocked(&"use_item", &"item_unavailable")
		return false
	if item.health_restore > 0.0:
		heal(item.health_restore)
	if item.hunger_restore > 0.0 and hunger != null:
		hunger.restore_hunger(item.hunger_restore)
	if item.clears_bleeding:
		remove_status(&"bleeding")
	if _event_bus != null:
		_event_bus.item_used.emit(item.item_id, 1)
	_emit_debug_notice("Used %s" % item.display_name, &"inventory")
	return true


func receive_item(item: ItemDefinition, quantity: int) -> bool:
	return inventory_component != null and inventory_component.add_item_definition(item, quantity, true)


func _process_quick_slot_input() -> void:
	if inventory_component == null or watch_state_machine.is_active():
		return
	var slot_index: int = input_reader.consume_inventory_slot()
	if slot_index >= 0:
		inventory_component.select_slot(slot_index)
	if input_reader.consume_inventory_clear_selection():
		interaction_state_machine.cancel_held_item_use()
		inventory_component.clear_selection()
		_sync_held_item()
	if input_reader.consume_inventory_drop():
		_drop_selected_inventory_item()
		_sync_held_item()


func _drop_selected_inventory_item() -> void:
	if not is_alive() or inventory_component == null:
		return
	var item: ItemDefinition = inventory_component.drop_selected_item()
	if item == null:
		_emit_action_blocked(&"drop_item", &"slot_empty")
		return
	var pickup: WorldPickup = WORLD_PICKUP_SCENE.instantiate() as WorldPickup
	pickup.configure(item, 1)
	var world_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	world_parent.add_child(pickup)
	var forward: Vector3 = -global_transform.basis.z.normalized()
	pickup.global_position = global_position + forward * 0.9 + Vector3.UP * 0.35
	pickup.launch(forward * 0.7 + Vector3.UP * 0.35)
	_emit_debug_notice("Dropped %s" % item.display_name, &"inventory")


func _on_watch_item_use_requested(item_id: StringName) -> void:
	watch_state_machine.close()
	use_item(item_id)


func _update_held_item_state(constraints: Dictionary, delta: float) -> void:
	_sync_held_item()
	var held_item: ItemDefinition = inventory_component.get_selected_item() if inventory_component != null else null
	if held_item == null:
		return
	constraints["combat_blocked"] = true
	if held_item.has_use_effect():
		interaction_state_machine.update_held_item_use(self, held_item.item_id, input_reader, constraints, delta)
	else:
		input_reader.consume_primary_attack()


func _sync_held_item() -> void:
	var held_item: ItemDefinition = inventory_component.get_selected_item() if inventory_component != null else null
	var next_item_id: StringName = held_item.item_id if held_item != null else &""
	if _held_item_id == next_item_id:
		return
	_held_item_id = next_item_id
	_call_arms(&"set_held_item", [held_item])
	if _event_bus != null:
		_event_bus.held_item_changed.emit(_held_item_id)


func _get_item_use_constraints() -> Dictionary:
	var constraints: Dictionary = _buff_resolver.call("get_constraints", self) if _buff_resolver != null else {}
	constraints = condition_state_machine.update(constraints)
	_merge_constraints(constraints, watch_state_machine.update())
	return constraints


func _on_phase_changed(_previous_phase: StringName, current_phase: StringName, _wave_index: int) -> void:
	if current_phase == &"rain":
		var rain_duration: float = 120.0
		if _game_manager != null and _game_manager.active_run_config != null:
			rain_duration = _game_manager.active_run_config.default_rain_seconds
		apply_status_by_id(&"rain_exposure", rain_duration)
	else:
		remove_status(&"rain_exposure")


func _apply_parry_counter(data: DamageEventData) -> void:
	var attacker: Object = instance_from_id(data.attacker_id)
	if not (attacker is Node):
		return
	var counter: DamageEventData = DamageEventData.new()
	counter.attacker_id = get_instance_id()
	counter.target_id = data.attacker_id
	counter.amount = 0.0
	counter.stagger = combat_definition.parry_stagger
	counter.knockback_force = combat_definition.parry_knockback_force
	counter.source_tags = [&"parry", &"melee"]
	counter.hit_position = global_position
	var attacker_node: Node = attacker as Node
	if attacker_node.has_method("receive_damage"):
		attacker_node.call("receive_damage", counter)


func _on_died() -> void:
	camera_rig.reset_recoil()
	first_person_arms.reset_firearm_recoil()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _event_bus != null:
		_event_bus.player_died.emit(&"player_died")
	if _game_manager != null and _game_manager.has_method("fail_run"):
		_game_manager.fail_run(&"player_died")
	elif _event_bus != null:
		_event_bus.run_failed.emit(&"player_died")


func _on_locomotion_state_changed(_previous_state: StringName, current_state: StringName) -> void:
	match current_state:
		PlayerLocomotionStateMachine.STATE_SPRINT:
			_emit_debug_notice("Action: sprinting", &"action")
		PlayerLocomotionStateMachine.STATE_SLIDE:
			_emit_debug_notice("Action: sliding", &"action")
			_call_arms(&"play_slide", [movement_definition.slide_timing])
		PlayerLocomotionStateMachine.STATE_JUMP:
			_emit_debug_notice("Action: jumping", &"action")
			_call_arms(&"play_jump", [movement_definition.jump_timing])
		PlayerLocomotionStateMachine.STATE_FALL:
			_emit_debug_notice("Action: falling", &"action")
		_:
			return


func _on_combat_state_changed(_previous_state: StringName, current_state: StringName) -> void:
	var timing: ActionTimingDefinition = combat_state_machine.get_current_action_timing()
	match current_state:
		PlayerCombatStateMachine.STATE_LIGHT_ATTACK:
			_emit_debug_notice("Action: primary attack", &"action")
			_call_arms(&"play_attack", [combat_driver.combo_index, timing, true])
		PlayerCombatStateMachine.STATE_HEAVY_ATTACK:
			_emit_debug_notice("Action: heavy attack", &"action")
			_call_arms(&"play_heavy_attack", [timing])
		PlayerCombatStateMachine.STATE_FIRE:
			_call_arms(&"play_firearm_fire", [timing])
		PlayerCombatStateMachine.STATE_RELOAD:
			_call_arms(&"play_firearm_reload", [timing])
		PlayerCombatStateMachine.STATE_READY, PlayerCombatStateMachine.STATE_DISABLED:
			_call_arms(&"cancel_firearm_action")
		PlayerCombatStateMachine.STATE_PARRY:
			_emit_debug_notice("Action: parry window", &"action")
			_call_arms(&"play_parry", [timing])
		PlayerCombatStateMachine.STATE_SHOVE:
			_emit_debug_notice("Action: shove", &"action")
			_call_arms(&"play_shove", [timing])
		_:
			return


func _on_combat_action_phase_changed(action_id: StringName, phase: int) -> void:
	if _event_bus != null:
		_event_bus.player_action_audio.emit(action_id, _phase_name(phase), global_position)


func _phase_name(phase: int) -> StringName:
	match phase:
		ActionTimingDefinition.Phase.WINDUP: return &"windup"
		ActionTimingDefinition.Phase.RELEASE: return &"release"
		ActionTimingDefinition.Phase.IMPACT: return &"impact"
		ActionTimingDefinition.Phase.RECOVERY: return &"recovery"
		_: return &"complete"


func _emit_footstep_if_due(delta: float) -> void:
	if _event_bus == null or not is_on_floor():
		_footstep_elapsed = 0.0
		_stop_footstep_audio()
		return
	var state: StringName = locomotion_state_machine.current_state
	if state not in [PlayerLocomotionStateMachine.STATE_WALK, PlayerLocomotionStateMachine.STATE_SPRINT]:
		_footstep_elapsed = 0.0
		_stop_footstep_audio()
		return
	var sprinting: bool = state == PlayerLocomotionStateMachine.STATE_SPRINT
	var cadence: float = 0.34 if sprinting else 0.52
	_footstep_elapsed += delta
	if _footstep_elapsed < cadence:
		return
	_footstep_elapsed = fmod(_footstep_elapsed, cadence)
	_footstep_audio_active = true
	_event_bus.player_footstep.emit(global_position, sprinting)


func _stop_footstep_audio() -> void:
	if not _footstep_audio_active:
		return
	_footstep_audio_active = false
	if _event_bus != null:
		_event_bus.player_footstep_stopped.emit(global_position)


func _on_light_combo_ended() -> void:
	_call_arms(&"release_light_combo_guard")


func _on_interaction_state_changed(_previous_state: StringName, current_state: StringName) -> void:
	if current_state in [PlayerInteractionStateMachine.STATE_INSTANT_USE, PlayerInteractionStateMachine.STATE_ITEM_USE]:
		combat_state_machine.interrupt()
		_emit_debug_notice("Action: interact", &"action")
		_call_arms(&"play_interact", [combat_definition.interact_timing])
		if _event_bus != null:
			_event_bus.interaction_audio.emit(&"start", global_position)


func _on_watch_state_changed(active: bool) -> void:
	var timing: ActionTimingDefinition = combat_definition.watch_timing if combat_definition != null else ActionTimingDefinition.new()
	if active:
		_call_arms(&"play_watch_raised", [timing])
	else:
		_call_arms(&"play_watch_lowered", [timing])
	if _event_bus != null:
		_event_bus.ui_audio.emit(&"watch.open" if active else &"watch.close")
	_emit_debug_notice("Action: watch %s" % ("open" if active else "closed"), &"action")


func _on_active_skill_charge_started(skill_id: StringName, timing: ActionTimingDefinition) -> void:
	_emit_debug_notice("Skill charging: %s" % String(skill_id), &"skill")
	_call_arms(&"play_charged_beam", [timing])


func _on_active_skill_triggered(skill_id: StringName) -> void:
	_emit_debug_notice("Skill fired: %s" % String(skill_id), &"skill")


func _on_action_blocked(action_id: StringName, reason_id: StringName) -> void:
	_emit_debug_notice("Blocked %s: %s" % [String(action_id), String(reason_id)], &"skill")


func _emit_debug_notice(message: String, category: StringName) -> void:
	if _event_bus != null:
		_event_bus.debug_test_notice.emit(message, category)


func _capture_mouse_gameplay_action(event: InputEvent) -> bool:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if not (event is InputEventMouseButton):
		return false

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed:
		return false
	if not event.is_action_pressed("attack_primary") and not event.is_action_pressed("attack_secondary"):
		return false

	input_reader.handle_input(event)
	return true


func _call_arms(method_name: StringName, args: Array = []) -> void:
	if first_person_arms == null or not first_person_arms.has_method(method_name):
		return
	first_person_arms.callv(method_name, args)


func _consume_deferred_inputs() -> void:
	input_reader.consume_pause()


func _update_watch_state() -> void:
	if input_reader.consume_watch_toggle():
		watch_state_machine.toggle()


func _emit_action_blocked(action_id: StringName, reason_id: StringName) -> void:
	if _event_bus != null:
		_event_bus.player_action_blocked.emit(action_id, reason_id)


func _merge_constraints(target: Dictionary, incoming: Dictionary) -> void:
	const boolean_constraints: Array[StringName] = [
		&"movement_disabled",
		&"combat_blocked",
		&"interaction_blocked",
		&"mobility_blocked",
	]
	for key: StringName in boolean_constraints:
		if incoming.has(key):
			target[key] = bool(target.get(key, false)) or bool(incoming[key])

	for key: Variant in incoming.keys():
		if not boolean_constraints.has(key):
			target[key] = incoming[key]


func _update_firearm_handling(constraints: Dictionary, delta: float) -> void:
	var weapon: WeaponDefinition = combat_driver.current_weapon
	var firearm_active: bool = combat_driver.is_current_firearm()
	var sprinting: bool = input_reader.wants_sprint and input_reader.move_vector != Vector2.ZERO and is_on_floor() and not constraints.get("mobility_blocked", false)
	constraints["firearm_sprinting"] = sprinting
	if firearm_active:
		combat_driver.apply_firearm_modifiers(constraints)
		camera_rig.recoil_recovery_multiplier = combat_driver.firearm_recoil_recovery_multiplier
		var aiming: bool = input_reader.wants_aim and not sprinting and not constraints.get("combat_blocked", false) and combat_state_machine.current_state != PlayerCombatStateMachine.STATE_RELOAD
		combat_driver.aim_fraction = move_toward(combat_driver.aim_fraction, 1.0 if aiming else 0.0, delta / maxf(0.01, weapon.ads_transition_seconds))
		constraints["movement_speed_multiplier"] = float(constraints.get("movement_speed_multiplier", 1.0)) * lerpf(1.0, weapon.ads_move_multiplier, combat_driver.aim_fraction)
		combat_driver.motion_spread = weapon.moving_spread_multiplier if Vector2(velocity.x, velocity.z).length() > 0.3 else 1.0
		if not is_on_floor():
			combat_driver.motion_spread *= weapon.airborne_spread_multiplier
	camera_rig.set_firearm(weapon if firearm_active else null)
	camera_rig.aim_fraction = combat_driver.aim_fraction if firearm_active else 0.0
	first_person_arms.set_firearm(weapon if firearm_active else null, camera_rig.aim_fraction)


func _on_firearm_fired(weapon: WeaponDefinition, recoil: Vector2) -> void:
	camera_rig.add_firearm_recoil(weapon, recoil)
	first_person_arms.firearm_impact(combat_driver.firearm_viewmodel_recoil_multiplier, recoil.y)
