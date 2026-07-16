extends Node3D

const Factory := preload("res://character_test_lab/scripts/model_factory.gd")
const CharacterScene := preload("res://character_test_lab/rain_warden_character.tscn")
const AudioController := preload("res://character_test_lab/scripts/rain_warden_audio.gd")

const CAMERA_START_YAW: float = PI - 0.48
const CAMERA_START_PITCH: float = 0.14
const CAMERA_START_DISTANCE: float = 5.25
const CLIP_BUTTONS: Array[StringName] = [&"idle", &"ready", &"inspect", &"attack", &"rain_pulse", &"run"]
var _audit_pose_ratios: Dictionary[StringName, PackedFloat32Array] = {
	&"idle": PackedFloat32Array([0.50]),
	&"ready": PackedFloat32Array([0.50]),
	&"inspect": PackedFloat32Array([0.42, 0.65]),
	&"attack": PackedFloat32Array([0.18, 0.50, 0.70]),
	&"rain_pulse": PackedFloat32Array([0.44, 0.56]),
	&"run": PackedFloat32Array([0.0, 0.25, 0.50, 0.75]),
}

var _character: Node3D
var _camera: Camera3D
var _camera_target: Node3D
var _pulse_particles: GPUParticles3D
var _pulse_light: OmniLight3D
var _audio: Node3D
var _status_label: Label
var _buttons: Dictionary[StringName, Button] = {}
var _yaw: float = CAMERA_START_YAW
var _pitch: float = CAMERA_START_PITCH
var _distance: float = CAMERA_START_DISTANCE
var _target_yaw: float = CAMERA_START_YAW
var _target_pitch: float = CAMERA_START_PITCH
var _target_distance: float = CAMERA_START_DISTANCE
var _turntable_enabled: bool = true


func _ready() -> void:
	_register_input_actions()
	_build_environment()
	_build_stage()
	_build_lighting()
	_build_character()
	_build_camera()
	_build_audio()
	_build_rain()
	_build_pulse_vfx()
	_build_interface()
	var capture_requested := OS.has_environment("RAIN_WARDEN_CAPTURE") or "--capture" in OS.get_cmdline_user_args()
	if capture_requested:
		print("Rain Warden showcase: capture requested")
		_capture_after_settle()


func _process(delta: float) -> void:
	var orbit_axis := Input.get_axis(&"showcase_orbit_left", &"showcase_orbit_right")
	if absf(orbit_axis) > 0.01:
		_target_yaw += orbit_axis * delta * 1.35
		_turntable_enabled = false
	elif _turntable_enabled:
		_target_yaw += delta * 0.16
	_yaw = lerp_angle(_yaw, _target_yaw, 1.0 - exp(-delta * 8.0))
	_pitch = lerpf(_pitch, _target_pitch, 1.0 - exp(-delta * 9.0))
	_distance = lerpf(_distance, _target_distance, 1.0 - exp(-delta * 10.0))
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"showcase_idle"):
		_play_clip(&"idle")
	elif event.is_action_pressed(&"showcase_ready"):
		_play_clip(&"ready")
	elif event.is_action_pressed(&"showcase_inspect"):
		_play_clip(&"inspect")
	elif event.is_action_pressed(&"showcase_attack"):
		_play_clip(&"attack")
	elif event.is_action_pressed(&"showcase_pulse"):
		_play_clip(&"rain_pulse")
		_trigger_pulse()
	elif event.is_action_pressed(&"showcase_run"):
		_play_clip(&"run")
	elif event.is_action_pressed(&"showcase_turntable"):
		_turntable_enabled = not _turntable_enabled
	elif event.is_action_pressed(&"showcase_reset_camera"):
		_reset_camera()

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		_target_yaw -= motion.relative.x * 0.007
		_target_pitch = clampf(_target_pitch - motion.relative.y * 0.006, -0.20, 0.55)
		_turntable_enabled = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_target_distance = maxf(_target_distance - 0.38, 3.45)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_target_distance = minf(_target_distance + 0.38, 7.20)
			get_viewport().set_input_as_handled()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10171b")
	environment.background_energy_multiplier = 0.72
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("83939a")
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.62
	environment.glow_strength = 0.76
	environment.fog_enabled = true
	environment.fog_light_color = Color("334248")
	environment.fog_light_energy = 0.48
	environment.fog_density = 0.012
	environment.fog_height = 0.2
	environment.fog_height_density = 0.22
	world_environment.environment = environment
	add_child(world_environment)


func _build_stage() -> void:
	var stage := Node3D.new()
	stage.name = "Stage"
	add_child(stage)
	var floor_material := Factory.material("Wet studio floor", Color("11191c"), 0.58, 0.24)
	var edge_material := Factory.material("Platform edge", Color("2b3537"), 0.72, 0.28)
	var amber_material := Factory.material("Amber stage marks", Color("b66f2c"), 0.12, 0.48, Color("8b451d"), 0.45)
	var cyan_material := Factory.material("Cyan stage ring", Color("3b9eaa"), 0.28, 0.22, Color("4ed8e6"), 1.55)
	var backdrop_material := Factory.material("Studio fins", Color("192327"), 0.36, 0.44)

	Factory.cylinder(stage, "PlatformBase", 2.40, 2.52, 0.22, Vector3(0, -0.15, 0), Vector3.ZERO, edge_material, 64)
	Factory.cylinder(stage, "PlatformTop", 2.29, 2.36, 0.08, Vector3(0, -0.015, 0), Vector3.ZERO, floor_material, 64)
	Factory.torus(stage, "CyanRing", 2.07, 2.13, Vector3(0, 0.035, 0), Vector3.ZERO, cyan_material)
	Factory.torus(stage, "AmberRing", 1.55, 1.58, Vector3(0, 0.041, 0), Vector3.ZERO, amber_material)
	Factory.box(stage, "CenterStripe", Vector3(0.10, 0.018, 3.0), Vector3(0, 0.045, 0.15), Vector3.ZERO, amber_material)

	for index: int in range(7):
		var x := (float(index) - 3.0) * 0.74
		var height := 2.2 + absf(float(index) - 3.0) * 0.23
		Factory.box(stage, "BackdropFin%02d" % index, Vector3(0.52, height, 0.13), Vector3(x, height * 0.5 - 0.05, 2.05 + absf(x) * 0.09), Vector3(0, x * -3.0, 0), backdrop_material)
		Factory.box(stage, "BackdropLight%02d" % index, Vector3(0.026, height * 0.62, 0.028), Vector3(x - 0.20, height * 0.52, 1.97 + absf(x) * 0.09), Vector3.ZERO, cyan_material if index in [1, 5] else amber_material)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18, 18)
	floor_mesh.subdivide_width = 2
	floor_mesh.subdivide_depth = 2
	var floor_instance := MeshInstance3D.new()
	floor_instance.name = "Floor"
	floor_instance.mesh = floor_mesh
	floor_instance.position = Vector3(0, -0.275, 0)
	floor_instance.material_override = floor_material
	stage.add_child(floor_instance)


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "RainAmbient"
	sun.rotation_degrees = Vector3(-54, -24, 0)
	sun.light_color = Color("a9c3ca")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 12.0
	sun.shadow_normal_bias = 1.8
	add_child(sun)

	var key := SpotLight3D.new()
	key.name = "WarmKey"
	key.position = Vector3(-3.6, 4.3, -3.6)
	key.look_at_from_position(key.position, Vector3(0, 1.2, 0))
	key.light_color = Color("ffd2a2")
	key.light_energy = 4.8
	key.spot_range = 11.0
	key.spot_angle = 31.0
	key.shadow_enabled = true
	key.shadow_bias = 0.08
	add_child(key)

	var rim := SpotLight3D.new()
	rim.name = "CyanRim"
	rim.position = Vector3(3.2, 3.2, 2.5)
	rim.look_at_from_position(rim.position, Vector3(0, 1.25, 0))
	rim.light_color = Color("5de2ee")
	rim.light_energy = 5.8
	rim.spot_range = 10.0
	rim.spot_angle = 36.0
	rim.shadow_enabled = true
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.name = "AmberFill"
	fill.position = Vector3(-2.1, 1.0, -0.7)
	fill.light_color = Color("e89b50")
	fill.light_energy = 1.35
	fill.omni_range = 4.2
	add_child(fill)


func _build_character() -> void:
	_character = CharacterScene.instantiate() as Node3D
	_character.name = "RainWarden"
	_character.connect("animation_changed", _on_character_animation_changed)
	add_child(_character)


func _build_camera() -> void:
	_camera_target = Node3D.new()
	_camera_target.name = "CameraTarget"
	_camera_target.position = Vector3(0, 1.18, 0)
	add_child(_camera_target)
	_camera = Camera3D.new()
	_camera.name = "OrbitCamera"
	_camera.current = true
	_camera.fov = 39.0
	_camera.near = 0.08
	_camera.far = 40.0
	add_child(_camera)
	_update_camera()


func _build_audio() -> void:
	_audio = AudioController.new() as Node3D
	_audio.name = "ShowcaseAudio"
	add_child(_audio)
	var player := _character.get("animation_player") as AnimationPlayer
	_audio.call("bind_animation_player", player)
	_audio.call("on_clip_started", &"idle")


func _build_rain() -> void:
	var rain := GPUParticles3D.new()
	rain.name = "RainField"
	rain.amount = 460
	rain.lifetime = 0.95
	rain.preprocess = 0.95
	rain.visibility_aabb = AABB(Vector3(-7, -2, -7), Vector3(14, 10, 14))
	rain.local_coords = false
	rain.fixed_fps = 30
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(5.5, 0.15, 5.5)
	process_material.direction = Vector3(0.10, -1.0, 0.04)
	process_material.spread = 3.0
	process_material.initial_velocity_min = 11.0
	process_material.initial_velocity_max = 16.0
	process_material.gravity = Vector3(0.6, -9.0, 0.2)
	rain.process_material = process_material
	var streak := BoxMesh.new()
	streak.size = Vector3(0.008, 0.52, 0.008)
	streak.material = Factory.material("Rain streak", Color(0.48, 0.72, 0.78, 0.28), 0.0, 0.18, Color("6ccbd5"), 0.65, true)
	rain.draw_pass_1 = streak
	rain.position = Vector3(0, 4.8, 0)
	add_child(rain)


func _build_pulse_vfx() -> void:
	_pulse_particles = GPUParticles3D.new()
	_pulse_particles.name = "RainPulse"
	_pulse_particles.amount = 150
	_pulse_particles.lifetime = 0.82
	_pulse_particles.one_shot = true
	_pulse_particles.emitting = false
	_pulse_particles.explosiveness = 0.92
	_pulse_particles.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 8, 10))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.22
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.initial_velocity_min = 1.6
	process_material.initial_velocity_max = 4.2
	process_material.gravity = Vector3(0, 0.9, 0)
	process_material.scale_min = 0.035
	process_material.scale_max = 0.10
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.55, 0.98, 1.0, 1.0))
	gradient.add_point(0.42, Color(0.18, 0.72, 0.84, 0.85))
	gradient.set_color(1, Color(0.05, 0.24, 0.32, 0.0))
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	process_material.color_ramp = gradient_texture
	_pulse_particles.process_material = process_material
	var mote := SphereMesh.new()
	mote.radius = 0.045
	mote.height = 0.09
	mote.radial_segments = 8
	mote.rings = 4
	mote.material = Factory.material("Rain pulse mote", Color("65e7ef"), 0.0, 0.15, Color("68edf5"), 5.2, true)
	_pulse_particles.draw_pass_1 = mote
	_pulse_particles.position = Vector3(0, 0.22, -0.35)
	add_child(_pulse_particles)

	_pulse_light = OmniLight3D.new()
	_pulse_light.name = "PulseLight"
	_pulse_light.position = Vector3(0, 0.34, -0.32)
	_pulse_light.light_color = Color("63e5ef")
	_pulse_light.light_energy = 0.0
	_pulse_light.omni_range = 5.0
	add_child(_pulse_light)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	var root := Control.new()
	root.name = "SafeArea"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.theme = _create_theme()
	canvas.add_child(root)

	var title_stack := VBoxContainer.new()
	title_stack.name = "TitleStack"
	title_stack.position = Vector2(42, 34)
	title_stack.add_theme_constant_override("separation", 2)
	root.add_child(title_stack)
	var title := Label.new()
	title.text = "RAIN WARDEN"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("edf4f2"))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.025, 0.76))
	title_stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "CHARACTER ART TEST  /  RAIN CLEAVER"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("b77b42"))
	title_stack.add_child(subtitle)

	var status_panel := PanelContainer.new()
	status_panel.name = "StatusPanel"
	status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_panel.position = Vector2(-278, 34)
	status_panel.size = Vector2(236, 66)
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.045, 0.86), Color("43666c")))
	root.add_child(status_panel)
	var status_stack := VBoxContainer.new()
	status_stack.add_theme_constant_override("separation", 3)
	status_panel.add_child(status_stack)
	var status_caption := Label.new()
	status_caption.text = "ANIMATION STATE"
	status_caption.add_theme_font_size_override("font_size", 10)
	status_caption.add_theme_color_override("font_color", Color("6fcbd4"))
	status_stack.add_child(status_caption)
	_status_label = Label.new()
	_status_label.text = "IDLE / BREATHING"
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color("e4ecea"))
	status_stack.add_child(_status_label)

	var toolbar := PanelContainer.new()
	toolbar.name = "AnimationToolbar"
	toolbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_left = 40
	toolbar.offset_right = -40
	toolbar.offset_top = -84
	toolbar.offset_bottom = -28
	toolbar.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.028, 0.032, 0.92), Color("394b4e")))
	root.add_child(toolbar)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 8)
	toolbar.add_child(button_row)
	var labels: Array[String] = ["1  IDLE", "2  READY", "3  INSPECT", "4  ATTACK", "5  PULSE", "6  RUN"]
	for index: int in range(CLIP_BUTTONS.size()):
		var clip_name := CLIP_BUTTONS[index]
		var button := Button.new()
		button.text = labels[index]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(142, 34)
		button.pressed.connect(_on_animation_button_pressed.bind(clip_name))
		button_row.add_child(button)
		_buttons[clip_name] = button
	_set_active_button(&"idle")


func _create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	var normal := _button_style(Color("172125"), Color("3b5054"))
	var hover := _button_style(Color("243338"), Color("64aeb6"))
	var pressed := _button_style(Color("254146"), Color("69d6df"))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_color("font_color", "Button", Color("b9c6c5"))
	theme.set_color("font_hover_color", "Button", Color("f0f7f5"))
	theme.set_color("font_pressed_color", "Button", Color("72e0e7"))
	return theme


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _register_input_actions() -> void:
	_add_key_action("showcase_idle", KEY_1, JOY_BUTTON_DPAD_UP)
	_add_key_action("showcase_ready", KEY_2, JOY_BUTTON_DPAD_LEFT)
	_add_key_action("showcase_inspect", KEY_3, JOY_BUTTON_DPAD_RIGHT)
	_add_key_action("showcase_attack", KEY_4, JOY_BUTTON_DPAD_DOWN)
	_add_key_action("showcase_pulse", KEY_5, JOY_BUTTON_RIGHT_SHOULDER)
	_add_key_action("showcase_run", KEY_6, JOY_BUTTON_LEFT_SHOULDER)
	_add_key_action("showcase_turntable", KEY_SPACE, JOY_BUTTON_START)
	_add_key_action("showcase_reset_camera", KEY_R, JOY_BUTTON_BACK)
	_add_key_action("showcase_orbit_left", KEY_A, -1)
	_add_key_action("showcase_orbit_right", KEY_D, -1)
	_add_joy_axis("showcase_orbit_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("showcase_orbit_right", JOY_AXIS_LEFT_X, 1.0)


func _add_key_action(action_name: StringName, physical_key: Key, joy_button: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.22)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_key
	InputMap.action_add_event(action_name, key_event)
	if joy_button >= 0:
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = joy_button as JoyButton
		InputMap.action_add_event(action_name, joy_event)


func _add_joy_axis(action_name: StringName, axis: JoyAxis, axis_value: float) -> void:
	var joy_event := InputEventJoypadMotion.new()
	joy_event.axis = axis
	joy_event.axis_value = axis_value
	InputMap.action_add_event(action_name, joy_event)


func _play_clip(clip_name: StringName) -> void:
	if _audio:
		_audio.call("play_ui_confirm")
	_character.call("play_clip", clip_name)
	_set_active_button(clip_name)


func _trigger_pulse() -> void:
	_pulse_particles.restart()
	_pulse_particles.emitting = true
	var tween := create_tween()
	tween.tween_property(_pulse_light, "light_energy", 8.5, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_pulse_light, "light_energy", 0.0, 0.72).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _set_active_button(clip_name: StringName) -> void:
	for key: StringName in _buttons:
		var button := _buttons[key] as Button
		button.set_pressed_no_signal(key == clip_name)


func _on_animation_button_pressed(clip_name: StringName) -> void:
	_play_clip(clip_name)
	if clip_name == &"rain_pulse":
		_trigger_pulse()


func _on_character_animation_changed(display_name: String) -> void:
	if _status_label:
		_status_label.text = display_name
	var player := _character.get("animation_player") as AnimationPlayer
	var active_clip := StringName(player.current_animation) if player else &"idle"
	_set_active_button(active_clip)
	if _audio:
		_audio.call("on_clip_started", active_clip)


func _update_camera() -> void:
	if not _camera or not _camera_target:
		return
	var offset := Vector3(
		_distance * cos(_pitch) * sin(_yaw),
		_distance * sin(_pitch),
		_distance * cos(_pitch) * cos(_yaw)
	)
	_camera.global_position = _camera_target.global_position + offset
	_camera.look_at(_camera_target.global_position, Vector3.UP)


func _reset_camera() -> void:
	_target_yaw = CAMERA_START_YAW
	_target_pitch = CAMERA_START_PITCH
	_target_distance = CAMERA_START_DISTANCE
	_turntable_enabled = true


func _capture_after_settle() -> void:
	_turntable_enabled = false
	var player := _character.get("animation_player") as AnimationPlayer
	if player:
		for clip_name: StringName in CLIP_BUTTONS:
			var ratios: PackedFloat32Array = _audit_pose_ratios[clip_name]
			for sample_index: int in range(ratios.size()):
				_character.call("play_clip", clip_name)
				player.seek(player.current_animation_length * ratios[sample_index], true)
				for _frame: int in range(3):
					await get_tree().process_frame
				var audit_path := "res://character_test_lab/art/animation_audit_%s_%02d.png" % [clip_name, sample_index]
				var audit_error := _save_viewport_png(audit_path)
				if audit_error != OK:
					push_error("Could not save %s animation audit: %s" % [clip_name, error_string(audit_error)])
				elif sample_index == 0:
					_save_viewport_png("res://character_test_lab/art/animation_audit_%s.png" % clip_name)
		_character.call("play_clip", &"idle")
	for _frame: int in range(16):
		await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self):
		return
	var error := _save_viewport_png("res://character_test_lab/art/showcase_capture_v2.png")
	if error != OK:
		push_error("Could not save showcase capture: %s" % error_string(error))
	get_tree().quit(error)


func _save_viewport_png(path: String) -> Error:
	var image := get_viewport().get_texture().get_image()
	if not image:
		return ERR_UNAVAILABLE
	return image.save_png(path)
