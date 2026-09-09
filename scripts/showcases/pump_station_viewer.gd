extends Node3D
## 展示专用自由相机，不是玩法角色；所有动作仅存在于此场景运行期间。
@export var capture_on_start: bool = false
@export var validation_on_start: bool = false
@onready var camera: Camera3D = $ReferenceCamera
var home_transform: Transform3D
var added_actions: Array[StringName] = []
var capturing: bool = false

func _ready() -> void:
	home_transform = camera.transform
	get_window().content_scale_size = Vector2i(1536, 1024)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().size = Vector2i(1440, 960)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_bind(&"showcase_forward", KEY_W)
	_bind(&"showcase_back", KEY_S)
	_bind(&"showcase_left", KEY_A)
	_bind(&"showcase_right", KEY_D)
	_bind(&"showcase_up", KEY_E)
	_bind(&"showcase_down", KEY_Q)
	_bind(&"showcase_fast", KEY_SHIFT)
	_bind(&"showcase_home", KEY_HOME)
	_bind(&"showcase_capture", KEY_F12)
	_bind(&"showcase_view_1", KEY_1)
	_bind(&"showcase_view_2", KEY_2)
	_bind(&"showcase_view_3", KEY_3)
	_bind(&"showcase_view_4", KEY_4)
	print("泵站展示场景已就绪：右键按住观察；WASD 移动；Q/E 降升；Shift 加速；Home 还原构图；F12 截图。")
	if capture_on_start:
		await get_tree().create_timer(4.0).timeout
		await capture()
	if validation_on_start:
		await validate_showcase()

func _bind(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	added_actions.append(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for action: StringName in added_actions:
		InputMap.erase_action(action)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * 0.002
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*0.002, -1.5, 1.5)
	if event.is_action_pressed(&"showcase_home"):
		camera.transform = home_transform
	if event.is_action_pressed(&"showcase_capture"):
		capture()
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for index: int in range(1,5):
		if event.is_action_pressed(StringName("showcase_view_%d" % index)):
			set_view(index)

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var axis: Vector2 = Input.get_vector(&"showcase_left", &"showcase_right", &"showcase_forward", &"showcase_back")
	var direction: Vector3 = camera.basis * Vector3(axis.x, 0, axis.y)
	direction.y += Input.get_axis(&"showcase_down", &"showcase_up")
	camera.position += direction.limit_length() * delta * (12.0 if Input.is_action_pressed(&"showcase_fast") else 4.0)

func set_view(index: int) -> void:
	match index:
		1:
			camera.transform = home_transform
		2:
			camera.position = Vector3(4.2,2.1,5.2)
			camera.look_at(Vector3(0.2,1.8,-1.5))
		3:
			camera.position = Vector3(3.1,2.5,16.2)
			camera.look_at(Vector3(-2.8,-1.0,10.7))
		4:
			camera.position = Vector3(-8.4,5.25,-5.5)
			camera.look_at(Vector3(-8.7,4.7,6.0))

func capture(filename: String = "pump_station_showcase") -> void:
	if capturing:
		return
	capturing = true
	await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var path: String = "user://%s.png" % filename
	var error: Error = shot.save_png(path)
	print("PUMP_SHOWCASE_CAPTURE ", ProjectSettings.globalize_path(path), " result=", error, " meshes=", find_children("*", "MeshInstance3D").size())
	print("PUMP_SHOWCASE_RENDER fps=", Engine.get_frames_per_second(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	capturing = false

func validate_showcase() -> void:
	assert(has_node("SunkenInspectionPit"))
	assert(has_node("ControlRoomMezzanine"))
	assert(has_node("MainPumpingMachinery"))
	assert(has_node("RightServicePipeGallery"))
	assert(has_node("DamagedRoofAndTrusses"))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press(&"showcase_forward")
	_process(0.25)
	Input.action_release(&"showcase_forward")
	assert(camera.position.distance_to(home_transform.origin)>0.9)
	var reset := InputEventAction.new()
	reset.action = &"showcase_home"
	reset.pressed = true
	_unhandled_input(reset)
	assert(camera.transform.is_equal_approx(home_transform))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for index: int in range(2,5):
		set_view(index)
		await get_tree().create_timer(2.0).timeout
		await capture("pump_station_view_%d" % index)
	set_view(1)
	print("PUMP_SHOWCASE_AUDIT PASS: 五组建筑节点、自由相机前进、Home 复位、三个近景截图、入口镜头还原。")
