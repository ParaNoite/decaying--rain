class_name PhaseController
extends Node

const PHASE_DAYLIGHT: StringName = &"daylight"
const PHASE_PREPARATION: StringName = &"preparation"
const PHASE_RAIN: StringName = &"rain"
const PHASE_SETTLEMENT: StringName = &"settlement"

@export var run_config: RunConfig
@export var rain_requires_wave_clear: bool = true

var phase_time_remaining: float = 0.0
var phase_duration_seconds: float = 0.0
var _timer_broadcast_remaining: float = 0.0
var _event_bus: Node


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null and not _event_bus.phase_changed.is_connected(_on_phase_changed):
		_event_bus.phase_changed.connect(_on_phase_changed)


func _exit_tree() -> void:
	if _event_bus != null and _event_bus.phase_changed.is_connected(_on_phase_changed):
		_event_bus.phase_changed.disconnect(_on_phase_changed)


func begin_run(config: RunConfig = null) -> void:
	run_config = config
	var game_manager = _game_manager()
	if game_manager == null:
		return
	game_manager.start_mvp_run(run_config)


func _process(delta: float) -> void:
	if phase_time_remaining <= 0.0:
		return

	phase_time_remaining -= delta
	_timer_broadcast_remaining -= delta
	if _timer_broadcast_remaining <= 0.0:
		_broadcast_wave_timer()

	if phase_time_remaining <= 0.0:
		_advance_phase()


func _advance_phase() -> void:
	var game_manager = _game_manager()
	if game_manager == null:
		return

	if rain_requires_wave_clear and game_manager.current_phase == PHASE_RAIN:
		_broadcast_wave_timer()
		return

	match game_manager.current_phase:
		PHASE_DAYLIGHT:
			game_manager.change_phase(PHASE_PREPARATION)
		PHASE_PREPARATION:
			game_manager.change_phase(PHASE_RAIN)
		PHASE_RAIN:
			game_manager.change_phase(PHASE_SETTLEMENT)
		PHASE_SETTLEMENT:
			_advance_wave_or_complete()
		_:
			return


func _advance_wave_or_complete() -> void:
	var game_manager = _game_manager()
	if game_manager == null:
		return

	var max_waves: int = run_config.max_waves if run_config != null else 5
	if game_manager.current_wave_index >= max_waves:
		game_manager.complete_run()
	else:
		game_manager.advance_wave()


func _duration_for_phase(phase: StringName) -> float:
	if run_config == null:
		match phase:
			PHASE_DAYLIGHT:
				return 180.0
			PHASE_PREPARATION:
				return 30.0
			PHASE_RAIN:
				return 120.0
			PHASE_SETTLEMENT:
				return 10.0
			_:
				return 0.0

	match phase:
		PHASE_DAYLIGHT:
			return run_config.daylight_seconds
		PHASE_PREPARATION:
			return run_config.preparation_seconds
		PHASE_RAIN:
			return run_config.default_rain_seconds
		PHASE_SETTLEMENT:
			return 10.0
		_:
			return 0.0


func _game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _broadcast_wave_timer() -> void:
	_timer_broadcast_remaining = 0.25
	var event_bus = get_node_or_null("/root/EventBus")
	var game_manager = _game_manager()
	if event_bus == null or game_manager == null:
		return
	event_bus.wave_timer_changed.emit(maxf(0.0, phase_time_remaining), phase_duration_seconds, game_manager.current_wave_index)


func _on_phase_changed(_previous_phase: StringName, current_phase: StringName, _wave_index: int) -> void:
	phase_duration_seconds = _duration_for_phase(current_phase)
	phase_time_remaining = phase_duration_seconds
	_broadcast_wave_timer()
