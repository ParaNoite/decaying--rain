class_name PhaseController
extends Node

const PHASE_DAYLIGHT: StringName = &"daylight"
const PHASE_PREPARATION: StringName = &"preparation"
const PHASE_RAIN: StringName = &"rain"
const PHASE_SETTLEMENT: StringName = &"settlement"

@export var run_config: RunConfig

var phase_time_remaining: float = 0.0


func begin_run(config: RunConfig = null) -> void:
	run_config = config
	var game_manager = _game_manager()
	if game_manager == null:
		return
	game_manager.start_mvp_run(run_config)
	phase_time_remaining = _duration_for_phase(game_manager.current_phase)


func _process(delta: float) -> void:
	if phase_time_remaining <= 0.0:
		return

	phase_time_remaining -= delta
	if phase_time_remaining <= 0.0:
		_advance_phase()


func _advance_phase() -> void:
	var game_manager = _game_manager()
	if game_manager == null:
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

	phase_time_remaining = _duration_for_phase(game_manager.current_phase)


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
