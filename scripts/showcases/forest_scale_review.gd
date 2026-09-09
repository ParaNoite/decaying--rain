extends Node3D

## 仅用于尺度验收，不改正式玩家、输入映射或数值资源。
@export var automated_audit: bool = false
@export var audit_from_route: int = 0
@onready var player: CharacterBody3D = $Player
@onready var overview: Camera3D = $OverviewCamera
var hud: Label
var elapsed: float = 0.0
var walked: float = 0.0
var previous_position: Vector3
var overhead: bool = false
var audit_pending: bool = false
var audit_done: bool = false
var audit_ticks: int = 0
var probe: CharacterBody3D
var route_index: int = 0
var target_index: int = 1
var audit_routes: Array[PackedVector3Array] = []
var audit_results: Array[String] = []
var route_ticks: int = 0
var last_progress: Vector3
var stuck_ticks: int = 0
var world_environment: Environment
var checkpoints: Array[Vector3] = [Vector3(0,2,79),Vector3(38,2,32),Vector3(56,2,29),Vector3(65,5.75,27),Vector3(-68,-.9,4),Vector3(5,5,-58),Vector3(5,17.3,-71),Vector3(90,9,-47)]

func _ready() -> void:
	previous_position = player.position
	world_environment = (find_children("*","WorldEnvironment",true,false)[0] as WorldEnvironment).environment
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "ScaleReviewHUD"
	add_child(canvas)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(16,16)
	panel.size = Vector2(740,112)
	panel.color = Color(.035,.05,.045,.84)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	hud = Label.new()
	hud.position = Vector2(28,24)
	hud.add_theme_font_size_override("font_size",18)
	canvas.add_child(hud)
	get_window().size = Vector2i(1440,900)
	get_viewport().msaa_3d = Viewport.MSAA_2X
	print("林地尺度验收：点击捕获鼠标，WASD 行走，Shift 冲刺，F7 总览，F6 下一个验收点，F8 自动碰撞审计。")
	if automated_audit:
		audit_pending = true

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F7:
			overhead = not overhead
			set_overhead(overhead)
		KEY_F6:
			var nearest: int = 0
			var distance: float = INF
			for i: int in range(checkpoints.size()):
				if player.position.distance_to(checkpoints[i]) < distance:
					distance = player.position.distance_to(checkpoints[i])
					nearest = i
			player.position = checkpoints[(nearest+1)%checkpoints.size()]
			player.velocity = Vector3.ZERO
			player.reset_physics_interpolation()
			previous_position = player.position
			overhead = false
			set_overhead(false)
		KEY_F8:
			if not audit_pending:
				audit_pending = true
				audit_done = false
		KEY_F12:
			capture("manual")

func set_overhead(enabled: bool) -> void:
	player.process_mode = Node.PROCESS_MODE_DISABLED if enabled else Node.PROCESS_MODE_INHERIT
	world_environment.fog_enabled = not enabled
	if enabled:
		overview.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		(player.get_node("Head/Camera3D") as Camera3D).make_current()

func _process(delta: float) -> void:
	if not overhead and not audit_pending:
		var distance: float = player.position.distance_to(previous_position)
		if distance > .002 and distance < 2:
			elapsed += delta
			walked += distance
	previous_position = player.position
	hud.text = "丘陵林地 · 空间尺度样机  |  280 × 225 m  |  主路宽 5 m\nWASD 行走 / Shift 冲刺 / Esc 鼠标  ·  F7 总览  ·  F6 切换验收点  ·  F8 碰撞审计\n行走 %.0f m / %.0f 秒  |  位置 %.1f, %.1f, %.1f  |  %s" % [walked,elapsed,player.position.x,player.position.y,player.position.z,"正在自动检查" if audit_pending else "原版 MVP 玩家 / 未修改移动数值"]
	if player.position.y < -25:
		player.position = checkpoints[0]
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()

func begin_audit() -> void:
	set_overhead(true)
	overhead = true
	audit_results.clear()
	audit_routes.clear()
	var builder: RefCounted = load("res://scripts/showcases/forest_scale_builder.gd").new()
	for route: PackedVector2Array in builder.routes:
		var points: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in route:
			points.append(Vector3(p.x,builder.height_at(p)+.99,p.y))
		audit_routes.append(points)
	# 连续步行：厅 -> 值班室 -> 工坊 -> 维护间 -> 楼梯 -> 露天平台。
	audit_routes.append(PackedVector3Array([Vector3(38,2,32),Vector3(52,2,29),Vector3(59,2,29),Vector3(56,2,29),Vector3(56,2,21),Vector3(59,2,21),Vector3(56,2,21),Vector3(56,2,13.5),Vector3(59,2,13.5),Vector3(59,2,16),Vector3(62,2,16),Vector3(62,5.71,9.65),Vector3(64,5.71,9.65),Vector3(65,5.71,27)]))
	# 附属走廊第二出口回到室外。
	audit_routes.append(PackedVector3Array([Vector3(56,2,29),Vector3(56,2,38),Vector3(48,2,42)]))
	var descending: PackedVector3Array = audit_routes[6].duplicate()
	descending.reverse()
	audit_routes.append(descending)
	audit_routes.append(PackedVector3Array([Vector3(-60,-1,11),Vector3(-60,-1,3),Vector3(-60,-1,-5)]))
	audit_routes.append(PackedVector3Array([Vector3(33,2,15.5),Vector3(33,5.725,5.5),Vector3(42,5.725,5.5),Vector3(33,5.725,5.5),Vector3(33,2,15.5)]))
	# 锯木厂垂直节奏：底层生产厅 -> 二层检修廊 -> 上层传送带 -> 屋顶平台。
	var sawmill_route: PackedVector3Array = PackedVector3Array([Vector3(5,4.95,-58),Vector3(5,4.95,-62),Vector3(-6,4.95,-62),Vector3(-6,4.95,-63),Vector3(-6,9.2,-71),Vector3(-3,9.2,-71),Vector3(-3,9.2,-79.5),Vector3(16,9.2,-79.5),Vector3(16,13.2,-71),Vector3(18.5,13.2,-71),Vector3(18.5,13.2,-63),Vector3(10,13.2,-63),Vector3(10,17.2,-71),Vector3(5,17.2,-71)])
	audit_routes.append(sawmill_route)
	var sawmill_descent: PackedVector3Array = sawmill_route.duplicate()
	sawmill_descent.reverse()
	audit_routes.append(sawmill_descent)
	probe = CharacterBody3D.new()
	probe.name = "AuditCapsule"
	probe.collision_layer = 0
	probe.collision_mask = 1
	probe.floor_snap_length = .2
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = .35
	shape.height = 1.8
	collision.shape = shape
	probe.add_child(collision)
	add_child(probe)
	route_index = clampi(audit_from_route,0,audit_routes.size()-1)
	start_route()
	var empty: int = 0
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or mesh.mesh.get_surface_count()==0:
			empty += 1
	audit_results.append("空网格=%d" % empty)
	capture("overview")

func start_route() -> void:
	probe.position = audit_routes[route_index][0]
	probe.velocity = Vector3.ZERO
	probe.reset_physics_interpolation()
	target_index = 1
	route_ticks = 0
	stuck_ticks = 0
	last_progress = probe.position

func _physics_process(delta: float) -> void:
	if not audit_pending:
		return
	if probe == null:
		audit_ticks += 1
		if audit_ticks > 90:
			begin_audit()
		return
	var target: Vector3 = audit_routes[route_index][target_index]
	var direction: Vector3 = target-probe.position
	direction.y = 0
	if direction.length() < .28 and absf(target.y-probe.position.y) < .65:
		target_index += 1
		if target_index >= audit_routes[route_index].size():
			finish_route(true)
			return
		target = audit_routes[route_index][target_index]
		direction = target-probe.position
		direction.y = 0
	probe.velocity.x = direction.normalized().x*5.4
	probe.velocity.z = direction.normalized().z*5.4
	probe.velocity.y -= 18.0*delta
	probe.move_and_slide()
	route_ticks += 1
	stuck_ticks += 1
	if stuck_ticks >= 120:
		if probe.position.distance_to(last_progress)<.3 or probe.position.y < -20:
			finish_route(false)
			return
		last_progress = probe.position
		stuck_ticks = 0
	if route_ticks > 6000:
		finish_route(false)

func finish_route(passed: bool) -> void:
	var line: String = "路线 %d %s | %.1f s | 节点 %d | 位置 %s" % [route_index+1,"PASS" if passed else "FAIL",float(route_ticks)/Engine.physics_ticks_per_second,target_index,str(probe.position)]
	audit_results.append(line)
	print("WORLD_SCALE_AUDIT "+line)
	route_index += 1
	if route_index < audit_routes.size():
		start_route()
		return
	probe.queue_free()
	probe = null
	audit_pending = false
	audit_done = true
	var directory: String = "res://output/showcases/forest_world"
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(directory+"/collision_audit.txt",FileAccess.WRITE)
	if file:
		file.store_string("固定地图 / 0.35m 半径、1.8m 高胶囊 / 5.4m/s；仅验证通行，不代表玩家全套动作验收。\n"+"\n".join(audit_results))
	print("WORLD_SCALE_AUDIT COMPLETE "+str(audit_results))
	await verify_real_player()
	capture_views()

func verify_real_player() -> void:
	player.position = Vector3(0,2,76)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	var before: Vector3 = player.position
	Input.action_press("move_forward")
	for tick: int in range(120):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var distance: float = Vector2(player.position.x-before.x,player.position.z-before.z).length()
	var report: String = "正式 MVP 玩家前进 120 物理帧：%.2f m / %s" % [distance,"PASS" if distance>8 and distance<13 else "FAIL"]
	print("WORLD_PLAYER_AUDIT "+report)
	var file: FileAccess = FileAccess.open("res://output/showcases/forest_world/player_audit.txt",FileAccess.WRITE)
	if file:
		file.store_string(report)
	player.process_mode = Node.PROCESS_MODE_DISABLED

func _exit_tree() -> void:
	Input.action_release("move_forward")

func capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var directory: String = "res://output/showcases/forest_world"
	DirAccess.make_dir_recursive_absolute(directory)
	var result: Error = get_viewport().get_texture().get_image().save_png(directory+"/"+tag+".png")
	print("WORLD_CAPTURE %s %s" % [tag,result])

func capture_views() -> void:
	world_environment.fog_enabled = true
	overview.fov = 75
	for item: Dictionary in [{"name":"annex_rooms","p":Vector3(56,3.2,32),"target":Vector3(59,2.8,22)},{"name":"roof_terrace","p":Vector3(65,6.6,28),"target":Vector3(91,10,-61)},{"name":"base_departure","p":Vector3(0,3.2,78),"target":Vector3(4,3,-10)},{"name":"sawmill_exterior","p":Vector3(39,27,-35),"target":Vector3(5,11,-71)},{"name":"sawmill_hall","p":Vector3(8,6.5,-62),"target":Vector3(-4,10,-73)},{"name":"sawmill_roof","p":Vector3(10,18.8,-71),"target":Vector3(-85,13,-5)},{"name":"terrain_ridge","p":Vector3(-98,30,44),"target":Vector3(-76,2,-37)}]:
		overview.look_at_from_position(item.p,item.target)
		await get_tree().create_timer(.5).timeout
		await capture(item.name)
	overview.look_at_from_position(Vector3(155,180,195),Vector3(0,0,-8))
	overview.fov = 45
	player.position = checkpoints[1]
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	overhead = false
	set_overhead(false)
