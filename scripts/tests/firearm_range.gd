extends Node3D

const PLAYER: PackedScene = preload("res://scenes/characters/player/player.tscn")
const TARGET: PackedScene = preload("res://scenes/tests/firearm_target.tscn")

var player: Player3DController
var _status: Label
var _feedback: Label
var _crosshair: AimHud


func _ready() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	var settings: Environment = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.055, 0.08, 0.11)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.72, 0.82, 1.0)
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.25
	add_child(sun)
	_box(Vector3(28, 0.4, 85), Vector3(0, -0.2, -34), Color(0.12, 0.17, 0.20))
	_box(Vector3(28, 8, 0.4), Vector3(0, 4, -75), Color(0.19, 0.25, 0.29))
	_box(Vector3(28, 4, 0.4), Vector3(0, 2, 8), Color(0.19, 0.25, 0.29))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.4, 6, 85), Vector3(side * 14, 3, -34), Color(0.16, 0.22, 0.26))
	for distance: float in [10.0, 25.0, 50.0]:
		_box(Vector3(27, 0.01, 0.08), Vector3(0, 0.01, -distance), Color(0.4, 0.7, 0.7), false)
		var distance_label: Label3D = Label3D.new()
		distance_label.text = "%d 米" % int(distance)
		distance_label.position = Vector3(-8, 2.5, -distance)
		distance_label.font_size = 70
		distance_label.pixel_size = 0.015
		add_child(distance_label)
		var target: Node3D = TARGET.instantiate() as Node3D
		target.position = Vector3(0 if distance == 10 else (-4 if distance == 25 else 4), 0, -distance)
		target.set("moving", distance == 25)
		target.connect("hit_report", _on_hit)
		add_child(target)
	player = PLAYER.instantiate() as Player3DController
	player.position = Vector3(0, 0.95, 0)
	add_child(player)
	player.camera_rig.head.rotation.x = -0.045
	player.inventory_component.clear_selection()
	for id: StringName in [&"pistol", &"rifle", &"smg", &"shotgun"]:
		player.loadout_component.add_weapon(id)
	for id: StringName in [&"light_ammo", &"rifle_ammo", &"shells"]:
		player.inventory_component.add_item(id, 500)
	while player.loadout_component.get_current_weapon().weapon_id != &"rifle":
		player.loadout_component.switch_relative(1)
	_build_ui()
	player.camera_rig.capture_mouse()


func _process(_delta: float) -> void:
	if player == null or _status == null:
		return
	var weapon: WeaponDefinition = player.combat_driver.current_weapon
	var mode: String = "开镜" if player.combat_driver.aim_fraction > 0.5 else "腰射"
	var state: String = "装填中" if player.combat_state_machine.current_state == &"reload" else mode
	_status.text = "%s  |  %d / %d  |  %s\n散布 %.2f°  ·  %s" % [weapon.display_name, player.loadout_component.get_magazine_ammo(), player.loadout_component.get_reserve_ammo(), state, player.combat_driver.get_current_spread(), "自动" if weapon.automatic else "半自动"]
	if player.position.y < -5:
		player.position = Vector3(0, 0.95, 0)
		player.velocity = Vector3.ZERO


func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var title: Label = Label.new()
	title.text = "枪械手感靶场 · 第一版\n10 米静态 / 25 米移动 / 50 米远距"
	title.position = Vector2(28, 24)
	title.add_theme_font_size_override("font_size", 24)
	canvas.add_child(title)
	_status = Label.new()
	_status.position = Vector2(28, 106)
	_status.add_theme_font_size_override("font_size", 22)
	canvas.add_child(_status)
	_feedback = Label.new()
	_feedback.position = Vector2(28, 174)
	_feedback.text = "黄色头部 ×2 / 青色躯干 ×1 / 灰色肢体 ×0.75"
	canvas.add_child(_feedback)
	var controls: Label = Label.new()
	controls.text = "左键开火  ·  右键按住开镜  ·  R 装填  ·  滚轮切武器\nWASD 移动  ·  Shift 冲刺（不中断装填） ·  Ctrl 滑铲  ·  空格跳跃\nEsc 释放鼠标；点击回到测试。靶子自动复位，弹药充足。"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(28, -96)
	canvas.add_child(controls)
	_crosshair = preload("res://scenes/ui/aim_hud.tscn").instantiate() as AimHud
	_crosshair.player = player
	canvas.add_child(_crosshair)


func _on_hit(message: String) -> void:
	_feedback.text = message


func _box(size: Vector3, offset: Vector3, color: Color, solid: bool = true) -> void:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.position = offset
	add_child(root)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	root.add_child(visual)
	if solid:
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
