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
@onready var profession_component = %ProfessionComponent
@onready var skill_component = %PlayerSkillComponent
@onready var locomotion_state_machine: PlayerLocomotionStateMachine = %LocomotionStateMachine
@onready var combat_state_machine: PlayerCombatStateMachine = %CombatStateMachine
@onready var interaction_state_machine: PlayerInteractionStateMachine = %InteractionStateMachine
@onready var condition_state_machine: PlayerConditionStateMachine = %PlayerConditionStateMachine
@onready var watch_state_machine: PlayerWatchStateMachine = %WatchStateMachine
@onready var first_person_hands: Node = %FirstPersonHands_TEST_ONLY_DELETE_WITH_ANIMATION_SYSTEM

var _event_bus = null
var _game_manager = null


func _ready() -> void:
	add_to_group("player")
	_event_bus = get_node_or_null("/root/EventBus")
	_game_manager = get_node_or_null("/root/GameManager")

	_apply_definitions()
	camera_rig.capture_mouse()

	health.died.connect(_on_died)
	locomotion_state_machine.state_changed.connect(_on_locomotion_state_changed)
	combat_state_machine.state_changed.connect(_on_combat_state_changed)
	interaction_state_machine.state_changed.connect(_on_interaction_state_changed)
	watch_state_machine.state_changed.connect(_on_watch_state_changed)
	skill_component.active_skill_charge_started.connect(_on_active_skill_charge_started)
	skill_component.active_skill_triggered.connect(_on_active_skill_triggered)
	skill_component.action_blocked.connect(_on_action_blocked)


func _input(event: InputEvent) -> void:
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
	movement_motor.tick_timers(delta, is_on_floor())
	movement_motor.apply_gravity(self, delta)

	var constraints: Dictionary = condition_state_machine.update()
	constraints.merge(watch_state_machine.update(input_reader), true)
	constraints.merge(skill_component.update(self, input_reader, constraints, delta), true)

	interaction_state_machine.update(self, input_reader, constraints, delta)
	combat_state_machine.update(self, input_reader, constraints, delta)
	locomotion_state_machine.physics_update(self, input_reader, constraints, delta)
	camera_rig.update_motion_feedback(locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT, delta)
	_call_hands(&"set_sprinting", [locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT])
	_consume_deferred_inputs()

	move_and_slide()


func apply_damage(amount: float) -> void:
	health.take_damage(amount)


func receive_damage(data: DamageEventData) -> void:
	if data == null or not data.is_valid_hit():
		return
	if combat_state_machine.parry_active and data.source_tags.has(&"melee"):
		if _event_bus != null:
			_event_bus.combat_hit.emit(data)
			_event_bus.debug_test_notice.emit("Parry success: blocked %.0f damage" % data.amount, &"combat")
			_event_bus.combat_feedback.emit("PARRY SUCCESS", &"success")
		return
	_emit_debug_notice("Player hit: -%.0f HP" % data.amount, &"combat")
	if _event_bus != null:
		_event_bus.combat_feedback.emit("HIT -%.0f" % data.amount, &"danger")
	_call_hands(&"play_hurt")
	apply_damage(data.amount)


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
	input_reader.consume_weapon_next()
	input_reader.consume_weapon_previous()
	input_reader.consume_inventory()
	input_reader.consume_pause()
