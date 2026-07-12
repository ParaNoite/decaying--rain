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
@onready var locomotion_state_machine: PlayerLocomotionStateMachine = %LocomotionStateMachine
@onready var combat_state_machine: PlayerCombatStateMachine = %CombatStateMachine
@onready var interaction_state_machine: PlayerInteractionStateMachine = %InteractionStateMachine
@onready var condition_state_machine: PlayerConditionStateMachine = %PlayerConditionStateMachine
@onready var watch_state_machine: PlayerWatchStateMachine = %WatchStateMachine

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


func _input(event: InputEvent) -> void:
	if not Input.is_action_pressed("watch") and camera_rig.recapture_from_click(event):
		get_viewport().set_input_as_handled()
		return

	if camera_rig.handle_look(event, self):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	input_reader.handle_input(event)

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

	interaction_state_machine.update(self, input_reader, constraints, delta)
	combat_state_machine.update(self, input_reader, constraints, delta)
	locomotion_state_machine.physics_update(self, input_reader, constraints, delta)
	camera_rig.update_motion_feedback(locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT, delta)
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
		return
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
		PlayerLocomotionStateMachine.STATE_SLIDE:
			_emit_debug_notice("Action: sliding", &"action")
		PlayerLocomotionStateMachine.STATE_JUMP:
			_emit_debug_notice("Action: jumping", &"action")
		PlayerLocomotionStateMachine.STATE_FALL:
			_emit_debug_notice("Action: falling", &"action")
		_:
			return


func _on_combat_state_changed(_previous_state: StringName, current_state: StringName) -> void:
	match current_state:
		PlayerCombatStateMachine.STATE_LIGHT_ATTACK:
			_emit_debug_notice("Action: primary attack", &"action")
		PlayerCombatStateMachine.STATE_PARRY:
			_emit_debug_notice("Action: parry window", &"action")
		PlayerCombatStateMachine.STATE_SHOVE:
			_emit_debug_notice("Action: shove", &"action")
		_:
			return


func _on_interaction_state_changed(_previous_state: StringName, current_state: StringName) -> void:
	if current_state == PlayerInteractionStateMachine.STATE_INSTANT_USE:
		_emit_debug_notice("Action: interact", &"action")


func _on_watch_state_changed(active: bool) -> void:
	_emit_debug_notice("Action: watch %s" % ("open" if active else "closed"), &"action")


func _emit_debug_notice(message: String, category: StringName) -> void:
	if _event_bus != null:
		_event_bus.debug_test_notice.emit(message, category)


func _consume_deferred_inputs() -> void:
	input_reader.consume_weapon_next()
	input_reader.consume_weapon_previous()
	input_reader.consume_inventory()
	input_reader.consume_pause()
