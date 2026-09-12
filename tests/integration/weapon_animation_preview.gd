extends Node3D
## Run with F6 to review both weapon mechanisms without gameplay input.
var _view: FirearmViewmodel
var _weapon: WeaponDefinition
var _elapsed: float = 0.0
var _index: int = -1
var _label: Label
var _captured: bool = false
var _saved: Dictionary[int, bool] = {}


func _ready() -> void:
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.8, 0.38, 0.65)
	camera.look_at(Vector3(0, 0, -0.18))
	var light: DirectionalLight3D = DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-35, -40, 0)
	light.light_energy = 2.0
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.10, 0.14)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	_label.position = Vector2(24, 24)
	canvas.add_child(_label)
	_next()


func _next() -> void:
	if _view != null:
		_view.queue_free()
	_index = (_index + 1) % 4
	var id: String = "pistol" if _index < 2 else "rifle"
	_weapon = load("res://resources/gameplay/weapons/" + id + ".tres")
	_view = _weapon.first_person_scene.instantiate()
	add_child(_view)
	_view.transform = Transform3D.IDENTITY
	_elapsed = 0.0
	_captured = false
	_label.text = id + (" — FIRE (slow motion)" if _index % 2 == 0 else " — RELOAD")


func _process(delta: float) -> void:
	if _view == null:
		return
	var fire: bool = _index % 2 == 0
	var timing: ActionTimingDefinition = _weapon.primary_timing if fire else _weapon.reload_timing
	_elapsed += delta * (0.08 if fire else 0.65)
	_view.sample_action(&"fire" if fire else &"reload", timing, minf(_elapsed, timing.total_seconds()))
	var capture_time: float = timing.impact_start_seconds() + timing.impact_seconds * 0.85 if fire else timing.windup_seconds + timing.release_seconds * 0.35
	if not _captured and not _saved.has(_index) and _elapsed >= capture_time:
		_captured = true
		_saved[_index] = true
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/weapon_animation")
		get_viewport().get_texture().get_image().save_png("res://artifacts/weapon_animation/" + str(_index) + ".png")
	if _elapsed > timing.total_seconds() + (0.05 if fire else 0.4):
		_next()
