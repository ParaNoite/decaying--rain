extends Node3D

const NORMAL_BACKGROUND: Color = Color(0.18, 0.22, 0.25, 1.0)
const NORMAL_AMBIENT_COLOR: Color = Color(0.42, 0.48, 0.55, 1.0)
const NORMAL_AMBIENT_ENERGY: float = 0.65
const NORMAL_SUN_COLOR: Color = Color.WHITE
const NORMAL_SUN_ENERGY: float = 1.8

const RAIN_BACKGROUND: Color = Color(0.035, 0.055, 0.07, 1.0)
const RAIN_AMBIENT_COLOR: Color = Color(0.12, 0.16, 0.20, 1.0)
const RAIN_AMBIENT_ENERGY: float = 0.28
const RAIN_SUN_COLOR: Color = Color(0.55, 0.68, 0.78, 1.0)
const RAIN_SUN_ENERGY: float = 0.35
const ATMOSPHERE_TRANSITION_SECONDS: float = 0.8
const MEDIUM_RAIN_AMOUNT: int = 900

@export var auto_start_run: bool = true
@onready var phase_controller: PhaseController = %PhaseController
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var base_rain_shelter: Area3D = $BaseRainShelter
@onready var rain_particles: Array[GPUParticles3D] = [
	$RainOutsideBase/RainNorth,
	$RainOutsideBase/RainSouth,
	$RainOutsideBase/RainWest,
	$RainOutsideBase/RainEast,
]

var _event_bus: Node
var _atmosphere_tween: Tween
var _current_phase: StringName = &"daylight"
var _player_in_base: bool = false


func _ready() -> void:
	_apply_render_budget()
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null and not _event_bus.phase_changed.is_connected(_on_phase_changed):
		_event_bus.phase_changed.connect(_on_phase_changed)
	base_rain_shelter.body_entered.connect(_on_base_shelter_body_entered)
	base_rain_shelter.body_exited.connect(_on_base_shelter_body_exited)

	var game_manager: Node = get_node_or_null("/root/GameManager")
	var initial_phase: StringName = game_manager.current_phase if game_manager != null else &"daylight"
	_current_phase = initial_phase
	_apply_atmosphere(initial_phase, false)

	if auto_start_run:
		phase_controller.begin_run()

func _apply_render_budget() -> void:
	var viewport := get_viewport()
	viewport.scaling_3d_scale = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	for emitter: GPUParticles3D in rain_particles:
		emitter.amount = MEDIUM_RAIN_AMOUNT
		emitter.visibility_aabb = AABB(Vector3(-24, -18, -24), Vector3(48, 26, 48))


func _exit_tree() -> void:
	if _event_bus != null and _event_bus.phase_changed.is_connected(_on_phase_changed):
		_event_bus.phase_changed.disconnect(_on_phase_changed)
	if base_rain_shelter.body_entered.is_connected(_on_base_shelter_body_entered):
		base_rain_shelter.body_entered.disconnect(_on_base_shelter_body_entered)
	if base_rain_shelter.body_exited.is_connected(_on_base_shelter_body_exited):
		base_rain_shelter.body_exited.disconnect(_on_base_shelter_body_exited)
	if _atmosphere_tween != null and _atmosphere_tween.is_valid():
		_atmosphere_tween.kill()


func _on_phase_changed(_previous_phase: StringName, current_phase: StringName, _wave_index: int) -> void:
	_current_phase = current_phase
	_apply_atmosphere(current_phase, true)


func _on_base_shelter_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_base = true
	_apply_atmosphere(_current_phase, true)


func _on_base_shelter_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_base = false
	_apply_atmosphere(_current_phase, true)


func _apply_atmosphere(phase: StringName, animate: bool) -> void:
	var is_rain: bool = phase == &"rain"
	for emitter: GPUParticles3D in rain_particles:
		emitter.emitting = is_rain

	if _atmosphere_tween != null and _atmosphere_tween.is_valid():
		_atmosphere_tween.kill()

	var environment: Environment = world_environment.environment
	if environment == null:
		return

	var player_exposed_to_rain: bool = is_rain and not _player_in_base
	var background: Color = RAIN_BACKGROUND if player_exposed_to_rain else NORMAL_BACKGROUND
	var ambient_color: Color = RAIN_AMBIENT_COLOR if player_exposed_to_rain else NORMAL_AMBIENT_COLOR
	var ambient_energy: float = RAIN_AMBIENT_ENERGY if player_exposed_to_rain else NORMAL_AMBIENT_ENERGY
	var sun_color: Color = RAIN_SUN_COLOR if player_exposed_to_rain else NORMAL_SUN_COLOR
	var sun_energy: float = RAIN_SUN_ENERGY if player_exposed_to_rain else NORMAL_SUN_ENERGY

	if not animate:
		environment.background_color = background
		environment.ambient_light_color = ambient_color
		environment.ambient_light_energy = ambient_energy
		sun.light_color = sun_color
		sun.light_energy = sun_energy
		return

	_atmosphere_tween = create_tween().set_parallel(true)
	_atmosphere_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_atmosphere_tween.tween_property(environment, "background_color", background, ATMOSPHERE_TRANSITION_SECONDS)
	_atmosphere_tween.tween_property(environment, "ambient_light_color", ambient_color, ATMOSPHERE_TRANSITION_SECONDS)
	_atmosphere_tween.tween_property(environment, "ambient_light_energy", ambient_energy, ATMOSPHERE_TRANSITION_SECONDS)
	_atmosphere_tween.tween_property(sun, "light_color", sun_color, ATMOSPHERE_TRANSITION_SECONDS)
	_atmosphere_tween.tween_property(sun, "light_energy", sun_energy, ATMOSPHERE_TRANSITION_SECONDS)
