class_name Player3DController
extends CharacterBody3D

@export var movement_definition: PlayerMovementDefinition
@export var combat_definition: PlayerCombatDefinition

@onready var input_reader: PlayerInputReader = %InputReader
@onready var camera_rig: PlayerCameraRig = %CameraRig
@onready var movement_motor: PlayerMovementMotor = %MovementMotor
@onready var combat_driver: PlayerCombatDriver = %CombatDriver
@onready var interaction_driver: PlayerInteractionDriver = %InteractionDriver
@onready var health: HealthComponent = %HealthComponent
@onready var stamina: StaminaComponent = %StaminaComponent
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
@onready var first_person_hands: Node = %FirstPersonHands_TEST_ONLY_DELETE_WITH_ANIMATION_SYSTEM

var _event_bus = null
var _game_manager = null
var _buff_resolver: Node
var _damage_resolver: Node
var inventory_open: bool = false


func _ready() -> void:
	add_to_group("player")
	_event_bus = get_node_or_null("/root/EventBus")
	_game_manager = get_node_or_null("/root/GameManager")
	_buff_resolver = get_node_or_null("/root/BuffResolver")
	_damage_resolver = get_node_or_null("/root/DamageResolver")
	if _event_bus != null:
		_event_bus.phase_changed.connect(_on_phase_changed)
		_event_bus.inventory_item_use_requested.connect(_on_inventory_item_use_requested)

	_apply_definitions()
	_initialize_runtime_components()
	if _buff_resolver != null:
		_buff_resolver.call("bind_container", self, status_container)
	_apply_profession_statuses()
	# Mouse is not captured by default — player clicks to capture

	health.died.connect(_on_died)
	locomotion_state_machine.state_changed.connect(_on_locomotion_state_changed)
	combat_state_machine.state_changed.connect(_on_combat_state_changed)
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
	if _event_bus.inventory_item_use_requested.is_connected(_on_inventory_item_use_requested):
		_event_bus.inventory_item_use_requested.disconnect(_on_inventory_item_use_requested)


func _input(event: InputEvent) -> void:
	if inventory_open:
		return
	if not Input.is_action_pressed("watch") and camera_rig.recapture_from_click(event):
		get_viewport().set_input_as_handled()
		return

	if _capture_mouse_gameplay_action(event):
		get_viewport().set_input_as_handled()
		return

	if camera_rig.handle_look(event, self):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	input_reader.handle_input(event)
	_preview_action_input(event)

	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	input_reader.refresh()
	_update_overlay_state()
	movement_motor.tick_timers(delta, is_on_floor())
	movement_motor.apply_gravity(self, delta)

	var constraints: Dictionary = _buff_resolver.call("get_constraints", self) if _buff_resolver != null else {}
	constraints = condition_state_machine.update(constraints)
	if inventory_open:
		_merge_constraints(constraints, {
			"movement_disabled": true,
			"combat_blocked": true,
			"interaction_blocked": true,
			"mobility_blocked": true,
			"inventory_open": true,
		})
	if stamina != null:
		stamina.recovery_multiplier = maxf(0.0, float(constraints.get("stamina_recovery_multiplier", 1.0)))
	_merge_constraints(constraints, watch_state_machine.update(input_reader))
	_merge_constraints(constraints, skill_component.update(self, input_reader, constraints, delta))

	interaction_state_machine.update(self, input_reader, constraints, delta)
	combat_state_machine.update(self, input_reader, constraints, delta)
	locomotion_state_machine.physics_update(self, input_reader, constraints, delta)
	camera_rig.update_motion_feedback(locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT, delta)
	_call_hands(&"set_sprinting", [locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT])
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
	if not combat_state_machine.parry_active or not data.source_tags.has(&"melee"):
		return false
	_apply_parry_counter(data)
	if _event_bus != null:
		_event_bus.debug_test_notice.emit("Parry success: blocked %.0f damage" % data.amount, &"combat")
		_event_bus.combat_feedback.emit("PARRY SUCCESS", &"success")
	return true


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
			_event_bus.combat_feedback.emit("HIT -%.0f" % result.final_amount, &"danger")
		_call_hands(&"play_hurt")
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
	if hunger != null and hunger.is_hungry:
		constraints["outgoing_damage_multiplier"] = float(
			constraints.get("outgoing_damage_multiplier", 1.0)
		) * 0.75


func heal(amount: float) -> void:
	health.heal(amount)


func is_alive() -> bool:
	return health != null and health.is_alive()


func _apply_definitions() -> void:
	if movement_definition != null:
		camera_rig.movement_definition = movement_definition
		movement_motor.movement_definition = movement_definition
		locomotion_state_machine.movement_definition = movement_definition

	if combat_definition != null:
		combat_driver.combat_definition = combat_definition
		combat_state_machine.combat_definition = combat_definition


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


func use_item(item_id: StringName) -> bool:
	if inventory_component == null or inventory_component.get_quantity(item_id) <= 0:
		_emit_action_blocked(&"use_item", &"item_unavailable")
		return false
	match item_id:
		&"bandage":
			heal(30.0)
			remove_status(&"bleeding")
		&"food_ration":
			hunger.restore_hunger(35.0)
		_:
			_emit_action_blocked(&"use_item", &"unsupported_item")
			return false
	inventory_component.remove_item(item_id)
	_emit_debug_notice("Used %s" % String(item_id).replace("_", " ").capitalize(), &"inventory")
	return true


func _on_inventory_item_use_requested(item_id: StringName) -> void:
	use_item(item_id)


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
	counter.source_tags = [&"parry", &"melee"]
	counter.hit_position = global_position
	var attacker_node: Node = attacker as Node
	if attacker_node.has_method("receive_damage"):
		attacker_node.call("receive_damage", counter)


func _on_died() -> void:
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
			_call_hands(&"play_sprint_start")
		PlayerLocomotionStateMachine.STATE_SLIDE:
			_emit_debug_notice("Action: sliding", &"action")
			_call_hands(&"play_slide")
		PlayerLocomotionStateMachine.STATE_JUMP:
			_emit_debug_notice("Action: jumping", &"action")
			_call_hands(&"play_jump")
		PlayerLocomotionStateMachine.STATE_FALL:
			_emit_debug_notice("Action: falling", &"action")
		_:
			return


func _on_combat_state_changed(_previous_state: StringName, current_state: StringName) -> void:
	match current_state:
		PlayerCombatStateMachine.STATE_LIGHT_ATTACK:
			_emit_debug_notice("Action: primary attack", &"action")
			_call_hands(&"play_attack", [combat_driver.combo_index])
		PlayerCombatStateMachine.STATE_FIRE:
			_emit_debug_notice("Action: firearm fired", &"combat")
			_call_hands(&"play_attack", [1])
		PlayerCombatStateMachine.STATE_RELOAD:
			_emit_debug_notice("Action: reloading", &"combat")
			_call_hands(&"play_interact")
		PlayerCombatStateMachine.STATE_PARRY:
			_emit_debug_notice("Action: parry window", &"action")
			_call_hands(&"play_parry", [combat_state_machine.state_time_remaining])
		PlayerCombatStateMachine.STATE_SHOVE:
			_emit_debug_notice("Action: shove", &"action")
			_call_hands(&"play_shove")
		_:
			return


func _on_interaction_state_changed(_previous_state: StringName, current_state: StringName) -> void:
	if current_state == PlayerInteractionStateMachine.STATE_INSTANT_USE:
		_emit_debug_notice("Action: interact", &"action")
		_call_hands(&"play_interact")


func _on_watch_state_changed(active: bool) -> void:
	_emit_debug_notice("Action: watch %s" % ("open" if active else "closed"), &"action")


func _on_active_skill_charge_started(skill_id: StringName, windup_seconds: float) -> void:
	_emit_debug_notice("Skill charging: %s" % String(skill_id), &"skill")
	_call_hands(&"play_charged_beam", [windup_seconds])


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
	_preview_action_input(event)
	return true


func _preview_action_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_primary"):
		_emit_debug_notice("Hands: attack input", &"hands")
		_call_hands(&"play_attack", [_preview_combo_index()])
	elif event.is_action_pressed("attack_secondary"):
		_emit_debug_notice("Hands: secondary attack placeholder", &"hands")
		_call_hands(&"play_heavy_attack")
	elif event.is_action_pressed("shove"):
		_emit_debug_notice("Hands: shove input", &"hands")
		_call_hands(&"play_shove")
	elif event.is_action_pressed("parry"):
		_emit_debug_notice("Hands: parry input", &"hands")
		_call_hands(&"play_parry", [_preview_parry_duration()])
	elif event.is_action_pressed("interact"):
		_emit_debug_notice("Hands: interact input", &"hands")
		_call_hands(&"play_interact")
	elif event.is_action_pressed("jump"):
		_call_hands(&"play_jump")
	elif event.is_action_pressed("slide"):
		_call_hands(&"play_slide")


func _preview_combo_index() -> int:
	return maxi(1, combat_driver.combo_index + 1)


func _preview_parry_duration() -> float:
	if combat_definition != null:
		return combat_definition.parry_window
	return 0.55


func _call_hands(method_name: StringName, args: Array = []) -> void:
	if first_person_hands == null or not first_person_hands.has_method(method_name):
		return
	first_person_hands.callv(method_name, args)


func _consume_deferred_inputs() -> void:
	input_reader.consume_pause()


func _update_overlay_state() -> void:
	if not input_reader.consume_inventory():
		return
	inventory_open = not inventory_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_open else Input.MOUSE_MODE_CAPTURED
	if _event_bus != null:
		_event_bus.inventory_visibility_changed.emit(inventory_open)


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
