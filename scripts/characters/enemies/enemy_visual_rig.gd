class_name EnemyVisualRig
extends Node3D

const Factory := preload("res://scripts/characters/enemies/enemy_model_factory.gd")

var definition: EnemyDefinition
var materials: Dictionary[StringName, StandardMaterial3D] = {}
var motion_root: Node3D
var hips: Node3D
var spine: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_forearm: Node3D
var right_forearm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_knee: Node3D
var right_knee: Node3D
var coat_left: Node3D
var coat_right: Node3D
var weapon_mount: Node3D
var body_mesh: MeshInstance3D
var muzzle_flash: MeshInstance3D


func build(enemy_definition: EnemyDefinition) -> void:
	definition = enemy_definition
	for child: Node in get_children():
		child.queue_free()
	_build_materials()
	_build_body()
	_build_role_details()


func get_body_mesh() -> MeshInstance3D:
	return body_mesh


func _build_materials() -> void:
	var base_color: Color = definition.body_color if definition != null else Color(0.35, 0.48, 0.38)
	var accent: Color = _role_accent()
	materials = {
		&"coat": Factory.material("Waterlogged outer cloth", base_color.darkened(0.30), 0.04, 0.52),
		&"coat_dark": Factory.material("Saturated underlayer", base_color.darkened(0.58), 0.03, 0.66),
		&"flesh": Factory.material("Rain blighted skin", Color(0.34, 0.38, 0.33), 0.0, 0.78),
		&"armor": Factory.material("Oxidized scavenged plate", Color(0.16, 0.19, 0.20), 0.70, 0.31),
		&"armor_edge": Factory.material("Exposed steel edges", Color(0.42, 0.47, 0.48), 0.82, 0.26),
		&"rubber": Factory.material("Black rain rubber", Color(0.035, 0.05, 0.055), 0.0, 0.34),
		&"leather": Factory.material("Waterlogged leather", Color(0.22, 0.14, 0.10), 0.0, 0.80),
		&"accent": Factory.material("Faction warning paint", accent, 0.18, 0.48),
		&"glow": Factory.material("Rain sickness glow", accent.lightened(0.24), 0.12, 0.16, accent.lightened(0.3), 3.4),
	}


func _build_body() -> void:
	motion_root = _pivot(self, "MotionRoot", Vector3.ZERO)
	hips = _pivot(motion_root, "Hips", Vector3(0.0, 0.92, 0.0))
	_build_legs()
	_build_torso()
	_build_head()
	_build_arms()


func _build_legs() -> void:
	left_leg = _pivot(hips, "LeftLeg", Vector3(-0.18, -0.02, 0.02))
	right_leg = _pivot(hips, "RightLeg", Vector3(0.18, -0.02, 0.02))
	_build_leg(left_leg, "L", -1.0)
	_build_leg(right_leg, "R", 1.0)


func _build_leg(leg: Node3D, prefix: String, side: float) -> void:
	Factory.capsule(leg, prefix + "Thigh", 0.13, 0.48, Vector3(0, -0.21, 0), Vector3.ZERO, materials.coat_dark, 14)
	Factory.box(leg, prefix + "ThighWrap", Vector3(0.20, 0.24, 0.17), Vector3(0, -0.18, -0.08), Vector3(3, 0, side * 3), materials.coat)
	var knee: Node3D = _pivot(leg, prefix + "Knee", Vector3(0, -0.42, 0.01))
	if prefix == "L":
		left_knee = knee
	else:
		right_knee = knee
	Factory.capsule(knee, prefix + "Shin", 0.105, 0.42, Vector3(0, -0.19, 0), Vector3.ZERO, materials.coat_dark, 14)
	Factory.box(knee, prefix + "KneeGuard", Vector3(0.21, 0.15, 0.10), Vector3(0, -0.03, -0.12), Vector3(-8, 0, 0), materials.armor)
	Factory.box(knee, prefix + "ShinPlate", Vector3(0.16, 0.23, 0.075), Vector3(0, -0.24, -0.11), Vector3(3, 0, 0), materials.armor_edge)
	Factory.box(knee, prefix + "Boot", Vector3(0.23, 0.17, 0.34), Vector3(0, -0.41, -0.08), Vector3.ZERO, materials.rubber)
	Factory.box(knee, prefix + "BootToe", Vector3(0.24, 0.10, 0.19), Vector3(0, -0.41, -0.25), Vector3(-6, 0, 0), materials.armor)
	Factory.box(knee, prefix + "AnkleMark", Vector3(0.045, 0.12, 0.022), Vector3(side * 0.105, -0.29, -0.14), Vector3.ZERO, materials.accent)


func _build_torso() -> void:
	Factory.tapered_box(hips, "PelvisCoat", Vector2(0.28, 0.19), Vector2(0.35, 0.22), 0.34, Vector3(0, 0.08, 0.02), Vector3.ZERO, materials.coat)
	Factory.box(hips, "UtilityBelt", Vector3(0.62, 0.09, 0.31), Vector3(0, 0.23, 0.01), Vector3.ZERO, materials.leather)
	Factory.box(hips, "BeltBuckle", Vector3(0.11, 0.10, 0.055), Vector3(0, 0.23, -0.18), Vector3.ZERO, materials.armor_edge)
	Factory.box(hips, "LeftPouch", Vector3(0.15, 0.18, 0.12), Vector3(-0.32, 0.09, 0.0), Vector3(0, 6, 3), materials.leather)
	Factory.box(hips, "RightPouch", Vector3(0.15, 0.18, 0.12), Vector3(0.32, 0.09, 0.0), Vector3(0, -6, -3), materials.leather)
	coat_left = _pivot(hips, "CoatLeft", Vector3(-0.17, -0.05, 0.11))
	coat_right = _pivot(hips, "CoatRight", Vector3(0.17, -0.05, 0.11))
	Factory.tapered_box(coat_left, "LeftTornTail", Vector2(0.18, 0.09), Vector2(0.23, 0.13), 0.61, Vector3(0, -0.28, 0), Vector3(0, 0, 4), materials.coat)
	Factory.tapered_box(coat_right, "RightTornTail", Vector2(0.18, 0.09), Vector2(0.22, 0.12), 0.54, Vector3(0, -0.25, 0), Vector3(0, 0, -5), materials.coat)
	Factory.box(coat_left, "LeftTailMark", Vector3(0.26, 0.045, 0.14), Vector3(0, -0.56, -0.01), Vector3.ZERO, materials.accent)

	spine = _pivot(hips, "Spine", Vector3(0, 0.25, 0))
	body_mesh = Factory.tapered_box(spine, "BodyMesh", Vector2(0.36, 0.20), Vector2(0.29, 0.18), 0.64, Vector3(0, 0.31, 0), Vector3.ZERO, materials.coat)
	Factory.tapered_box(spine, "ShoulderMantle", Vector2(0.47, 0.23), Vector2(0.35, 0.20), 0.25, Vector3(0, 0.57, 0.03), Vector3.ZERO, materials.coat_dark)
	Factory.box(spine, "ChestPlate", Vector3(0.50, 0.34, 0.085), Vector3(0, 0.40, -0.205), Vector3(-3, 0, 0), materials.armor)
	Factory.box(spine, "ChestEdge", Vector3(0.42, 0.035, 0.025), Vector3(0, 0.56, -0.255), Vector3.ZERO, materials.armor_edge)
	Factory.box(spine, "ChestMark", Vector3(0.06, 0.28, 0.025), Vector3(-0.15, 0.40, -0.258), Vector3(0, 0, -9), materials.accent)
	Factory.torus(spine, "SealedCollar", 0.18, 0.25, Vector3(0, 0.70, 0), Vector3.ZERO, materials.rubber)


func _build_head() -> void:
	head = _pivot(spine, "Head", Vector3(0, 0.86, 0))
	Factory.sphere(head, "RainHood", 0.27, 0.51, Vector3(0, 0.0, 0.025), Vector3.ZERO, materials.coat_dark, 20)
	Factory.sphere(head, "BlightedFace", 0.19, 0.35, Vector3(0, -0.025, -0.07), Vector3.ZERO, materials.flesh, 18)
	Factory.torus(head, "HoodSeal", 0.15, 0.215, Vector3(0, 0, -0.105), Vector3(90, 0, 0), materials.rubber)
	Factory.box(head, "Respirator", Vector3(0.30, 0.17, 0.13), Vector3(0, -0.09, -0.225), Vector3(7, 0, 0), materials.armor)
	Factory.box(head, "RespiratorVent", Vector3(0.17, 0.07, 0.04), Vector3(0, -0.11, -0.315), Vector3.ZERO, materials.armor_edge)
	Factory.box(head, "EyeGlow", Vector3(0.25, 0.045, 0.021), Vector3(0, 0.055, -0.265), Vector3.ZERO, materials.glow)
	Factory.cylinder(head, "LeftFilter", 0.06, 0.075, 0.12, Vector3(-0.17, -0.10, -0.21), Vector3(90, 0, 0), materials.armor_edge, 12)
	Factory.cylinder(head, "RightFilter", 0.06, 0.075, 0.12, Vector3(0.17, -0.10, -0.21), Vector3(90, 0, 0), materials.armor_edge, 12)


func _build_arms() -> void:
	left_arm = _pivot(spine, "LeftArm", Vector3(-0.46, 0.59, 0.0))
	right_arm = _pivot(spine, "RightArm", Vector3(0.46, 0.59, 0.0))
	_build_arm(left_arm, "L", -1.0)
	_build_arm(right_arm, "R", 1.0)


func _build_arm(arm: Node3D, prefix: String, side: float) -> void:
	Factory.sphere(arm, prefix + "Shoulder", 0.16, 0.23, Vector3(0, -0.03, 0), Vector3(0, 0, side * 6), materials.armor, 14)
	Factory.capsule(arm, prefix + "UpperArm", 0.115, 0.39, Vector3(0, -0.20, 0), Vector3.ZERO, materials.coat, 14)
	Factory.box(arm, prefix + "UpperPlate", Vector3(0.16, 0.22, 0.085), Vector3(0, -0.17, -0.105), Vector3(2, 0, 0), materials.armor_edge)
	var forearm: Node3D = _pivot(arm, prefix + "Forearm", Vector3(0, -0.37, 0))
	if prefix == "L":
		left_forearm = forearm
	else:
		right_forearm = forearm
	Factory.capsule(forearm, prefix + "LowerArm", 0.10, 0.35, Vector3(0, -0.17, 0), Vector3.ZERO, materials.coat_dark, 14)
	Factory.box(forearm, prefix + "Bracer", Vector3(0.16, 0.22, 0.105), Vector3(0, -0.18, -0.085), Vector3(-3, 0, 0), materials.armor)
	Factory.sphere(forearm, prefix + "Glove", 0.105, 0.17, Vector3(0, -0.36, -0.01), Vector3.ZERO, materials.rubber, 12)
	Factory.box(forearm, prefix + "CuffMark", Vector3(0.17, 0.055, 0.15), Vector3(0, -0.30, 0), Vector3.ZERO, materials.accent)
	if prefix == "R":
		weapon_mount = _pivot(forearm, "WeaponMount", Vector3(0, -0.38, 0))


func _build_role_details() -> void:
	if definition == null:
		return
	match definition.pressure_role:
		EnemyDefinition.PressureRole.BASE_BREAKER:
			_build_doorbreaker()
		EnemyDefinition.PressureRole.ELITE_MELEE:
			_build_armored_scavenger()
		EnemyDefinition.PressureRole.RANGED_PRESSURE:
			_build_wet_gunner()
		_:
			_build_ruptured()


func _build_ruptured() -> void:
	motion_root.scale = Vector3(0.82, 1.08, 0.82)
	_set_part_visible(head, "Respirator", false)
	_set_part_visible(head, "RespiratorVent", false)
	_set_part_visible(head, "LeftFilter", false)
	_set_part_visible(head, "RightFilter", false)
	_set_part_visible(head, "EyeGlow", false)
	_set_part_visible(spine, "ChestPlate", false)
	_set_part_visible(spine, "ChestEdge", false)
	Factory.sphere(head, "ExposedJaw", 0.16, 0.22, Vector3(0.03, -0.12, -0.19), Vector3(10, 0, -7), materials.flesh, 16)
	Factory.sphere(head, "LeftSickEye", 0.045, 0.075, Vector3(-0.09, 0.045, -0.245), Vector3.ZERO, materials.glow, 10)
	Factory.box(head, "SplitFaceScar", Vector3(0.026, 0.25, 0.022), Vector3(0.06, -0.015, -0.258), Vector3(0, 0, -18), materials.glow)
	Factory.tapered_box(spine, "TornChestFlap", Vector2(0.22, 0.05), Vector2(0.30, 0.08), 0.48, Vector3(-0.06, 0.32, -0.23), Vector3(0, 0, 8), materials.coat)
	Factory.box(left_arm, "BareShoulderLesion", Vector3(0.18, 0.24, 0.10), Vector3(0, -0.10, -0.11), Vector3(5, 0, -8), materials.flesh)
	Factory.box(spine, "ExposedRibGlowA", Vector3(0.035, 0.24, 0.025), Vector3(0.16, 0.37, -0.26), Vector3(0, 0, 18), materials.glow)
	Factory.box(spine, "ExposedRibGlowB", Vector3(0.035, 0.18, 0.025), Vector3(0.23, 0.32, -0.245), Vector3(0, 0, -12), materials.glow)
	for index: int in 3:
		Factory.cylinder(weapon_mount, "RainClaw%02d" % index, 0.014, 0.026, 0.32, Vector3((index - 1) * 0.045, -0.13, -0.03), Vector3(8, 0, (index - 1) * 5), materials.armor_edge, 8)


func _build_doorbreaker() -> void:
	motion_root.scale = Vector3(1.24, 0.99, 1.18)
	_set_part_visible(head, "EyeGlow", false)
	_set_part_visible(head, "RespiratorVent", false)
	Factory.box(head, "WeldersFaceplate", Vector3(0.42, 0.43, 0.12), Vector3(0, -0.01, -0.22), Vector3(0, 0, 0), materials.armor)
	Factory.box(head, "BreakerVisor", Vector3(0.30, 0.055, 0.025), Vector3(0, 0.06, -0.292), Vector3.ZERO, materials.glow)
	Factory.box(head, "BreakerJawGuard", Vector3(0.32, 0.14, 0.08), Vector3(0, -0.18, -0.28), Vector3(7, 0, 0), materials.armor_edge)
	Factory.tapered_box(hips, "BreakerApron", Vector2(0.34, 0.08), Vector2(0.27, 0.10), 0.66, Vector3(0, -0.18, -0.22), Vector3(-4, 0, 0), materials.coat_dark)
	Factory.box(hips, "ApronWarning", Vector3(0.42, 0.07, 0.025), Vector3(0, -0.22, -0.30), Vector3(0, 0, -8), materials.accent)
	Factory.box(spine, "BreakerChestSlab", Vector3(0.68, 0.48, 0.13), Vector3(0, 0.42, -0.26), Vector3(-3, 0, 0), materials.armor)
	Factory.box(spine, "BreakerWarningBar", Vector3(0.48, 0.07, 0.028), Vector3(0, 0.43, -0.335), Vector3(0, 0, -11), materials.accent)
	Factory.box(left_arm, "LeftRamPauldron", Vector3(0.31, 0.23, 0.31), Vector3(-0.02, -0.03, 0), Vector3(0, 0, -8), materials.armor)
	Factory.box(right_arm, "RightRamPauldron", Vector3(0.31, 0.23, 0.31), Vector3(0.02, -0.03, 0), Vector3(0, 0, 8), materials.armor)
	Factory.cylinder(weapon_mount, "BreakerShaft", 0.04, 0.05, 1.10, Vector3(0, -0.30, 0), Vector3.ZERO, materials.leather, 14)
	Factory.box(weapon_mount, "BreakerHead", Vector3(0.68, 0.25, 0.30), Vector3(0, -0.88, 0), Vector3(0, 0, 4), materials.armor)
	Factory.box(weapon_mount, "BreakerFace", Vector3(0.56, 0.18, 0.055), Vector3(0, -0.88, -0.18), Vector3.ZERO, materials.armor_edge)
	Factory.box(weapon_mount, "BreakerPaint", Vector3(0.36, 0.045, 0.06), Vector3(0, -0.88, -0.215), Vector3(0, 0, -12), materials.accent)


func _build_armored_scavenger() -> void:
	motion_root.scale = Vector3(1.11, 1.12, 1.08)
	_set_part_visible(head, "EyeGlow", false)
	_set_part_visible(head, "Respirator", false)
	_set_part_visible(head, "RespiratorVent", false)
	_set_part_visible(head, "LeftFilter", false)
	_set_part_visible(head, "RightFilter", false)
	Factory.box(head, "ScavengerHelmet", Vector3(0.45, 0.35, 0.40), Vector3(0, 0.06, 0.01), Vector3(0, 0, 0), materials.armor)
	Factory.box(head, "ScavengerBrow", Vector3(0.43, 0.09, 0.09), Vector3(0, 0.07, -0.235), Vector3(-5, 0, 0), materials.armor_edge)
	Factory.box(head, "VerticalVisor", Vector3(0.075, 0.20, 0.025), Vector3(-0.04, -0.015, -0.29), Vector3(0, 0, 5), materials.glow)
	Factory.box(head, "HelmetCrest", Vector3(0.07, 0.25, 0.42), Vector3(0.05, 0.29, 0.02), Vector3(0, 0, -6), materials.accent)
	for index: int in 3:
		Factory.box(spine, "LamellarPlate%02d" % index, Vector3(0.58 - index * 0.06, 0.15, 0.10), Vector3(0, 0.52 - index * 0.15, -0.27), Vector3(-4 + index * 3, 0, 0), materials.armor_edge if index == 1 else materials.armor)
	Factory.box(left_arm, "LeftScrapPauldron", Vector3(0.38, 0.18, 0.36), Vector3(-0.05, -0.02, 0), Vector3(0, 0, -13), materials.armor)
	Factory.box(right_arm, "RightScrapPauldron", Vector3(0.34, 0.20, 0.34), Vector3(0.04, -0.02, 0), Vector3(0, 0, 10), materials.armor_edge)
	Factory.cylinder(weapon_mount, "CleaverGrip", 0.035, 0.045, 0.48, Vector3(0, -0.18, 0), Vector3.ZERO, materials.leather, 12)
	Factory.scrap_blade(weapon_mount, "ScrapCleaver", Vector3(0, -0.62, 0), Vector3(0, 0, 180), materials.armor_edge)
	Factory.box(weapon_mount, "CleaverWarning", Vector3(0.025, 0.28, 0.035), Vector3(0.11, -0.61, -0.035), Vector3(0, 0, 12), materials.accent)


func _build_wet_gunner() -> void:
	motion_root.scale = Vector3(0.88, 1.10, 0.90)
	_set_part_visible(head, "EyeGlow", false)
	Factory.sphere(head, "LeftGoggle", 0.07, 0.10, Vector3(-0.10, 0.045, -0.255), Vector3.ZERO, materials.glow, 12)
	Factory.sphere(head, "RightGoggle", 0.07, 0.10, Vector3(0.10, 0.045, -0.255), Vector3.ZERO, materials.glow, 12)
	Factory.box(head, "HoodPeak", Vector3(0.38, 0.075, 0.24), Vector3(0, 0.24, -0.08), Vector3(-8, 0, 0), materials.coat)
	Factory.cylinder(head, "RadioAntenna", 0.012, 0.018, 0.48, Vector3(0.25, 0.19, 0.03), Vector3(0, 0, -8), materials.armor_edge, 8)
	Factory.tapered_box(spine, "GunnerHalfCape", Vector2(0.27, 0.08), Vector2(0.20, 0.07), 0.70, Vector3(0.17, 0.25, 0.20), Vector3(-9, 0, -5), materials.coat_dark)
	Factory.box(spine, "AmmoHarnessLeft", Vector3(0.07, 0.52, 0.06), Vector3(-0.19, 0.39, -0.25), Vector3(0, 0, -12), materials.leather)
	Factory.box(spine, "AmmoHarnessRight", Vector3(0.07, 0.52, 0.06), Vector3(0.19, 0.39, -0.25), Vector3(0, 0, 12), materials.leather)
	for index: int in 4:
		Factory.cylinder(spine, "ChestRound%02d" % index, 0.022, 0.022, 0.13, Vector3(-0.19 + index * 0.11, 0.42, -0.31), Vector3(90, 0, 0), materials.accent, 8)
	Factory.box(weapon_mount, "RifleReceiver", Vector3(0.18, 0.48, 0.17), Vector3(0, -0.28, 0), Vector3.ZERO, materials.armor)
	Factory.cylinder(weapon_mount, "RifleBarrel", 0.025, 0.035, 0.62, Vector3(0, -0.78, 0), Vector3.ZERO, materials.armor_edge, 12)
	Factory.box(weapon_mount, "RifleStock", Vector3(0.17, 0.28, 0.20), Vector3(0, 0.10, 0.06), Vector3(7, 0, 0), materials.rubber)
	Factory.box(weapon_mount, "RifleMagazine", Vector3(0.13, 0.25, 0.10), Vector3(0, -0.40, 0.14), Vector3(15, 0, 0), materials.armor_edge)
	Factory.cylinder(weapon_mount, "RainScope", 0.055, 0.055, 0.24, Vector3(0, -0.22, -0.15), Vector3.ZERO, materials.glow, 12)
	muzzle_flash = Factory.sphere(weapon_mount, "MuzzleFlash", 0.11, 0.22, Vector3(0, -1.10, 0), Vector3.ZERO, materials.glow, 12)
	muzzle_flash.visible = false


func _role_accent() -> Color:
	if definition == null:
		return Color(0.45, 0.8, 0.62)
	match definition.pressure_role:
		EnemyDefinition.PressureRole.BASE_BREAKER:
			return Color(0.92, 0.24, 0.10)
		EnemyDefinition.PressureRole.ELITE_MELEE:
			return Color(0.92, 0.60, 0.16)
		EnemyDefinition.PressureRole.RANGED_PRESSURE:
			return Color(0.16, 0.80, 0.92)
		_:
			return Color(0.55, 0.94, 0.28)


func _set_part_visible(parent: Node, part_name: String, visible_value: bool) -> void:
	var part: Node3D = parent.find_child(part_name, true, false) as Node3D
	if part != null:
		part.visible = visible_value


func _pivot(parent: Node3D, node_name: String, local_position: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = node_name
	pivot.position = local_position
	parent.add_child(pivot)
	return pivot
