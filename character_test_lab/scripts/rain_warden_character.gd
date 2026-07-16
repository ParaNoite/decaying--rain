class_name RainWardenCharacter
extends Node3D

signal animation_changed(display_name: String)

const Factory := preload("res://character_test_lab/scripts/model_factory.gd")
const WeaponScene := preload("res://character_test_lab/rain_cleaver_weapon.tscn")

const CLIP_LABELS: Dictionary[String, String] = {
	"idle": "IDLE / BREATHING",
	"ready": "READY STANCE",
	"inspect": "WEAPON INSPECTION",
	"attack": "CLEAVER ARC",
	"rain_pulse": "RAIN PULSE",
	"run": "COMBAT RUN",
}

const ONE_SHOT_CLIPS: Array[StringName] = [&"inspect", &"attack", &"rain_pulse"]
const UPPER_ARM_LENGTH: float = 0.41
const LOWER_ARM_LENGTH: float = 0.42
const IDLE_WEAPON_POSITION := Vector3(0.10, 0.12, -0.30)
const IDLE_WEAPON_ROTATION_DEGREES := Vector3(-5, 0, 42)

var animation_player: AnimationPlayer
var _materials: Dictionary[String, StandardMaterial3D] = {}
var _motion_root: Node3D
var _hips: Node3D
var _spine: Node3D
var _head: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_forearm: Node3D
var _right_forearm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_knee: Node3D
var _right_knee: Node3D
var _weapon_rig: Node3D
var _primary_grip: Marker3D
var _secondary_grip: Marker3D
var _coat_left: Node3D
var _coat_right: Node3D


func _ready() -> void:
	_build_materials()
	_build_character()
	_build_animation_player()
	play_clip(&"idle")
	_solve_arms()


func _process(delta: float) -> void:
	if not animation_player:
		return
	animation_player.advance(delta)
	_solve_arms()


func play_clip(clip_name: StringName) -> void:
	if not animation_player.has_animation(clip_name):
		return
	if animation_player.current_animation == clip_name and clip_name in ONE_SHOT_CLIPS:
		animation_player.stop()
	animation_player.play(clip_name, 0.16)
	animation_changed.emit(CLIP_LABELS.get(String(clip_name), String(clip_name).to_upper()))


func get_clip_label() -> String:
	return CLIP_LABELS.get(String(animation_player.current_animation), "IDLE / BREATHING")


func _build_materials() -> void:
	_materials = {
		"coat": Factory.material("Waxed olive raincoat", Color("313b35"), 0.04, 0.67),
		"coat_dark": Factory.material("Wet charcoal mantle", Color("151c1d"), 0.06, 0.54),
		"armor": Factory.material("Segmented charcoal armor", Color("242c2d"), 0.64, 0.30),
		"armor_edge": Factory.material("Armor edge wear", Color("657071"), 0.78, 0.28),
		"rubber": Factory.material("Black rain rubber", Color("0d1214"), 0.0, 0.39),
		"leather": Factory.material("Worn utility leather", Color("49362b"), 0.0, 0.78),
		"amber": Factory.material("Amber waterproof cloth", Color("c07a31"), 0.06, 0.62),
		"steel": Factory.material("Rain-etched steel", Color("677274"), 0.82, 0.30),
		"cyan": Factory.material("Cyan filter glass", Color("42aebb"), 0.20, 0.16, Color("56e4ef"), 3.8),
		"warning": Factory.material("Worn warning paint", Color("b74631"), 0.18, 0.54),
	}


func _build_character() -> void:
	_motion_root = _pivot(self, "MotionRoot", Vector3.ZERO)
	_hips = _pivot(_motion_root, "Hips", Vector3(0.0, 1.04, 0.0))
	_build_legs()
	_build_coat_and_torso()
	_build_head()
	_build_arms_and_weapon()
	_build_backpack()


func _build_legs() -> void:
	_left_leg = _pivot(_hips, "LeftLeg", Vector3(-0.19, -0.02, 0.015))
	_right_leg = _pivot(_hips, "RightLeg", Vector3(0.19, -0.02, 0.015))
	_build_leg(_left_leg, "L", -1.0)
	_build_leg(_right_leg, "R", 1.0)


func _build_leg(leg: Node3D, prefix: String, side: float) -> void:
	Factory.capsule(leg, prefix + "Thigh", 0.145, 0.55, Vector3(0, -0.24, 0), Vector3.ZERO, _materials.coat, 16)
	Factory.box(leg, prefix + "ThighArmor", Vector3(0.22, 0.31, 0.18), Vector3(0, -0.20, -0.085), Vector3(4, 0, side * 2), _materials.armor)
	var knee := _pivot(leg, prefix + "Knee", Vector3(0, -0.48, 0.015))
	if prefix == "L":
		_left_knee = knee
	else:
		_right_knee = knee
	Factory.capsule(knee, prefix + "Shin", 0.12, 0.49, Vector3(0, -0.23, 0), Vector3.ZERO, _materials.coat_dark, 16)
	Factory.box(knee, prefix + "KneePlate", Vector3(0.23, 0.20, 0.11), Vector3(0, -0.03, -0.13), Vector3(-7, 0, 0), _materials.armor_edge)
	Factory.box(knee, prefix + "ShinPlate", Vector3(0.18, 0.28, 0.10), Vector3(0, -0.28, -0.12), Vector3(3, 0, 0), _materials.armor)
	Factory.box(knee, prefix + "Boot", Vector3(0.25, 0.19, 0.40), Vector3(0, -0.48, -0.095), Vector3.ZERO, _materials.rubber)
	Factory.box(knee, prefix + "BootToe", Vector3(0.26, 0.12, 0.23), Vector3(0, -0.48, -0.28), Vector3(-5, 0, 0), _materials.armor)
	Factory.box(knee, prefix + "AmberTab", Vector3(0.07, 0.17, 0.025), Vector3(side * 0.11, -0.23, -0.17), Vector3.ZERO, _materials.amber)


func _build_coat_and_torso() -> void:
	Factory.tapered_box(_hips, "PelvisCoat", Vector2(0.30, 0.20), Vector2(0.38, 0.23), 0.38, Vector3(0, 0.07, 0.02), Vector3.ZERO, _materials.coat)
	Factory.box(_hips, "UtilityBelt", Vector3(0.68, 0.105, 0.34), Vector3(0, 0.23, 0.01), Vector3.ZERO, _materials.leather)
	Factory.box(_hips, "BeltBuckle", Vector3(0.13, 0.12, 0.06), Vector3(0, 0.23, -0.20), Vector3.ZERO, _materials.steel)
	Factory.box(_hips, "LeftPouch", Vector3(0.18, 0.21, 0.14), Vector3(-0.34, 0.10, -0.02), Vector3(0, 5, 2), _materials.leather)
	Factory.box(_hips, "RightPouch", Vector3(0.18, 0.21, 0.14), Vector3(0.34, 0.10, -0.02), Vector3(0, -5, -2), _materials.leather)

	_coat_left = _pivot(_hips, "CoatLeft", Vector3(-0.18, -0.08, 0.12))
	_coat_right = _pivot(_hips, "CoatRight", Vector3(0.18, -0.08, 0.12))
	Factory.tapered_box(_coat_left, "LeftTail", Vector2(0.19, 0.10), Vector2(0.25, 0.14), 0.73, Vector3(0, -0.34, 0), Vector3(0, 0, 3), _materials.coat)
	Factory.tapered_box(_coat_right, "RightTail", Vector2(0.19, 0.10), Vector2(0.25, 0.14), 0.73, Vector3(0, -0.34, 0), Vector3(0, 0, -3), _materials.coat)
	Factory.box(_coat_left, "LeftTailTrim", Vector3(0.30, 0.055, 0.17), Vector3(0, -0.68, -0.01), Vector3.ZERO, _materials.amber)
	Factory.box(_coat_right, "RightTailTrim", Vector3(0.30, 0.055, 0.17), Vector3(0, -0.68, -0.01), Vector3.ZERO, _materials.amber)

	_spine = _pivot(_hips, "Spine", Vector3(0, 0.26, 0))
	Factory.tapered_box(_spine, "CoatBody", Vector2(0.38, 0.21), Vector2(0.31, 0.19), 0.70, Vector3(0, 0.32, 0), Vector3.ZERO, _materials.coat)
	Factory.tapered_box(_spine, "RainMantle", Vector2(0.54, 0.25), Vector2(0.39, 0.22), 0.37, Vector3(0, 0.56, 0.035), Vector3.ZERO, _materials.coat_dark)
	Factory.box(_spine, "ChestPlate", Vector3(0.56, 0.40, 0.11), Vector3(0, 0.43, -0.22), Vector3(-3, 0, 0), _materials.armor)
	Factory.box(_spine, "ChestEdge", Vector3(0.48, 0.045, 0.035), Vector3(0, 0.61, -0.29), Vector3.ZERO, _materials.armor_edge)
	Factory.box(_spine, "ChestAmberStripe", Vector3(0.075, 0.35, 0.032), Vector3(-0.17, 0.43, -0.292), Vector3(0, 0, -8), _materials.amber)
	Factory.box(_spine, "LowerPlate", Vector3(0.42, 0.16, 0.09), Vector3(0.04, 0.18, -0.22), Vector3(4, 0, 0), _materials.armor_edge)
	Factory.torus(_spine, "MantleCollar", 0.22, 0.30, Vector3(0, 0.72, 0), Vector3.ZERO, _materials.rubber)


func _build_head() -> void:
	_head = _pivot(_spine, "HeadPivot", Vector3(0, 0.93, 0))
	Factory.sphere(_head, "Hood", 0.30, 0.57, Vector3(0, 0, 0.035), Vector3.ZERO, _materials.coat_dark, 24)
	Factory.sphere(_head, "ShadowedFace", 0.215, 0.40, Vector3(0, -0.02, -0.075), Vector3.ZERO, _materials.rubber, 20)
	Factory.torus(_head, "HoodRim", 0.175, 0.245, Vector3(0, 0, -0.112), Vector3(90, 0, 0), _materials.coat)
	Factory.tapered_box(_head, "HoodPeak", Vector2(0.06, 0.09), Vector2(0.23, 0.15), 0.24, Vector3(0, 0.22, -0.12), Vector3(78, 0, 0), _materials.coat_dark)
	Factory.box(_head, "Respirator", Vector3(0.34, 0.20, 0.15), Vector3(0, -0.09, -0.245), Vector3(8, 0, 0), _materials.armor)
	Factory.box(_head, "RespiratorFront", Vector3(0.20, 0.10, 0.055), Vector3(0, -0.12, -0.345), Vector3.ZERO, _materials.armor_edge)
	Factory.box(_head, "VisorLeft", Vector3(0.105, 0.055, 0.025), Vector3(-0.075, 0.045, -0.290), Vector3(0, -5, -3), _materials.cyan)
	Factory.box(_head, "VisorRight", Vector3(0.105, 0.055, 0.025), Vector3(0.075, 0.045, -0.290), Vector3(0, 5, 3), _materials.cyan)
	Factory.cylinder(_head, "LeftFilter", 0.075, 0.09, 0.14, Vector3(-0.205, -0.10, -0.235), Vector3(90, 0, 0), _materials.steel, 12)
	Factory.cylinder(_head, "RightFilter", 0.075, 0.09, 0.14, Vector3(0.205, -0.10, -0.235), Vector3(90, 0, 0), _materials.steel, 12)
	Factory.box(_head, "HoodAmberMark", Vector3(0.055, 0.19, 0.025), Vector3(0.18, 0.12, -0.235), Vector3(0, -18, -8), _materials.amber)


func _build_arms_and_weapon() -> void:
	_left_arm = _pivot(_spine, "LeftArm", Vector3(-0.49, 0.61, 0.0))
	_right_arm = _pivot(_spine, "RightArm", Vector3(0.49, 0.61, 0.0))
	Factory.sphere(_spine, "LShoulderArmor", 0.19, 0.26, Vector3(-0.52, 0.58, 0), Vector3(0, 0, -8), _materials.armor, 16)
	Factory.sphere(_spine, "RShoulderArmor", 0.19, 0.26, Vector3(0.52, 0.58, 0), Vector3(0, 0, 8), _materials.armor, 16)
	_build_arm(_left_arm, "L")
	_build_arm(_right_arm, "R")

	_weapon_rig = _pivot(_spine, "WeaponRig", IDLE_WEAPON_POSITION)
	_weapon_rig.rotation_degrees = IDLE_WEAPON_ROTATION_DEGREES
	var weapon := WeaponScene.instantiate() as Node3D
	weapon.name = "RainCleaver"
	weapon.scale = Vector3.ONE * 0.75
	_weapon_rig.add_child(weapon)
	_primary_grip = weapon.get_node("PrimaryGrip") as Marker3D
	_secondary_grip = weapon.get_node("SecondaryGrip") as Marker3D


func _build_arm(arm: Node3D, prefix: String) -> void:
	Factory.capsule(arm, prefix + "UpperArm", 0.13, 0.44, Vector3(0, -0.22, 0), Vector3.ZERO, _materials.coat, 16)
	Factory.box(arm, prefix + "UpperPlate", Vector3(0.18, 0.26, 0.10), Vector3(0, -0.18, -0.12), Vector3(2, 0, 0), _materials.armor_edge)
	var forearm := _pivot(arm, prefix + "Forearm", Vector3(0, -0.41, 0))
	if prefix == "L":
		_left_forearm = forearm
	else:
		_right_forearm = forearm
	Factory.capsule(forearm, prefix + "LowerArm", 0.115, 0.40, Vector3(0, -0.19, 0), Vector3.ZERO, _materials.coat_dark, 16)
	Factory.box(forearm, prefix + "Bracer", Vector3(0.18, 0.26, 0.12), Vector3(0, -0.20, -0.10), Vector3(-3, 0, 0), _materials.armor)
	Factory.sphere(forearm, prefix + "Glove", 0.12, 0.19, Vector3(0, -0.42, -0.01), Vector3.ZERO, _materials.rubber, 14)
	Factory.box(forearm, prefix + "AmberCuff", Vector3(0.19, 0.075, 0.18), Vector3(0, -0.34, 0), Vector3.ZERO, _materials.amber)


func _build_backpack() -> void:
	Factory.box(_spine, "Backpack", Vector3(0.48, 0.52, 0.22), Vector3(0, 0.42, 0.27), Vector3(2, 0, 0), _materials.coat_dark)
	Factory.box(_spine, "BackpackFrame", Vector3(0.56, 0.045, 0.28), Vector3(0, 0.59, 0.31), Vector3.ZERO, _materials.steel)
	Factory.cylinder(_spine, "LeftRainCanister", 0.075, 0.075, 0.43, Vector3(-0.30, 0.38, 0.27), Vector3.ZERO, _materials.steel, 12)
	Factory.cylinder(_spine, "RightRainCanister", 0.075, 0.075, 0.43, Vector3(0.30, 0.38, 0.27), Vector3.ZERO, _materials.warning, 12)
	Factory.box(_spine, "BackpackGlow", Vector3(0.19, 0.055, 0.025), Vector3(0, 0.37, 0.405), Vector3.ZERO, _materials.cyan)


func _build_animation_player() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animation_player)
	var library := AnimationLibrary.new()
	library.add_animation("RESET", _reset_animation())
	library.add_animation("idle", _idle_animation())
	library.add_animation("ready", _ready_animation())
	library.add_animation("inspect", _inspect_animation())
	library.add_animation("attack", _attack_animation())
	library.add_animation("rain_pulse", _rain_pulse_animation())
	library.add_animation("run", _run_animation())
	animation_player.add_animation_library("", library)
	animation_player.animation_finished.connect(_on_animation_finished)


func _reset_animation() -> Animation:
	var animation := _animation(0.1, false)
	_position_track(animation, "MotionRoot:position", [0.0], [Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips", [0.0], [Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/Spine", [0.0], [Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/Spine/HeadPivot", [0.0], [Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg", [0.0], [Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg", [0.0], [Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg/LKnee", [0.0], [Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg/RKnee", [0.0], [Vector3.ZERO])
	_position_track(animation, "MotionRoot/Hips/Spine/WeaponRig:position", [0.0], [IDLE_WEAPON_POSITION])
	_rotation_track(animation, "MotionRoot/Hips/Spine/WeaponRig", [0.0], [IDLE_WEAPON_ROTATION_DEGREES])
	_rotation_track(animation, "MotionRoot/Hips/CoatLeft", [0.0], [Vector3(0, 0, 2)])
	_rotation_track(animation, "MotionRoot/Hips/CoatRight", [0.0], [Vector3(0, 0, -2)])
	return animation


func _idle_animation() -> Animation:
	var animation := _animation(3.0, true)
	var times: Array[float] = [0.0, 1.5, 3.0]
	_position_track(animation, "MotionRoot:position", times, [Vector3.ZERO, Vector3(0, 0.016, 0), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips", times, [Vector3(0, -1, -0.5), Vector3(0, 1, 0.5), Vector3(0, -1, -0.5)])
	_rotation_track(animation, "MotionRoot/Hips/Spine", times, [Vector3(-1, 0, 0), Vector3(1.2, 0, 0), Vector3(-1, 0, 0)])
	_rotation_track(animation, "MotionRoot/Hips/Spine/HeadPivot", times, [Vector3(0, -2, 0), Vector3(1, 2, 0), Vector3(0, -2, 0)])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg", times, [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(1, 0, 0)])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg", times, [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0)])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg/LKnee", times, [Vector3(-3, 0, 0), Vector3(-1, 0, 0), Vector3(-3, 0, 0)])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg/RKnee", times, [Vector3(-1, 0, 0), Vector3(-3, 0, 0), Vector3(-1, 0, 0)])
	_position_track(animation, "MotionRoot/Hips/Spine/WeaponRig:position", times, [IDLE_WEAPON_POSITION, Vector3(0.10, 0.135, -0.305), IDLE_WEAPON_POSITION])
	_rotation_track(animation, "MotionRoot/Hips/Spine/WeaponRig", times, [IDLE_WEAPON_ROTATION_DEGREES, Vector3(-4, 1, 43), IDLE_WEAPON_ROTATION_DEGREES])
	_rotation_track(animation, "MotionRoot/Hips/CoatLeft", times, [Vector3(0, 0, 2), Vector3(-2, 1, 4), Vector3(0, 0, 2)])
	_rotation_track(animation, "MotionRoot/Hips/CoatRight", times, [Vector3(0, 0, -2), Vector3(1, -1, -4), Vector3(0, 0, -2)])
	return animation


func _ready_animation() -> Animation:
	var animation := _animation(2.2, true)
	var times: Array[float] = [0.0, 1.1, 2.2]
	_position_track(animation, "MotionRoot:position", times, [Vector3.ZERO, Vector3(0, 0.012, -0.012), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips", times, [Vector3(0, -6, -1), Vector3(0, -4, 1), Vector3(0, -6, -1)])
	_rotation_track(animation, "MotionRoot/Hips/Spine", times, [Vector3(-5, 4, 0), Vector3(-3, 2, 0), Vector3(-5, 4, 0)])
	_rotation_track(animation, "MotionRoot/Hips/Spine/HeadPivot", times, [Vector3(-2, -8, 1), Vector3(0, -5, 0), Vector3(-2, -8, 1)])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg", times, [Vector3(7, 0, -3), Vector3(5, 0, -2), Vector3(7, 0, -3)])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg", times, [Vector3(-5, 0, 3), Vector3(-3, 0, 2), Vector3(-5, 0, 3)])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg/LKnee", times, [Vector3(-14, 0, 0), Vector3(-11, 0, 0), Vector3(-14, 0, 0)])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg/RKnee", times, [Vector3(-20, 0, 0), Vector3(-17, 0, 0), Vector3(-20, 0, 0)])
	_position_track(animation, "MotionRoot/Hips/Spine/WeaponRig:position", times, [Vector3(0.08, 0.46, -0.40), Vector3(0.08, 0.475, -0.41), Vector3(0.08, 0.46, -0.40)])
	_rotation_track(animation, "MotionRoot/Hips/Spine/WeaponRig", times, [Vector3(-18, -8, 64), Vector3(-16, -6, 62), Vector3(-18, -8, 64)])
	_rotation_track(animation, "MotionRoot/Hips/CoatLeft", times, [Vector3(-2, 2, 5), Vector3(0, 0, 3), Vector3(-2, 2, 5)])
	_rotation_track(animation, "MotionRoot/Hips/CoatRight", times, [Vector3(1, -1, -4), Vector3(-1, 1, -2), Vector3(1, -1, -4)])
	return animation


func _inspect_animation() -> Animation:
	var animation := _animation(3.4, false)
	var times: Array[float] = [0.0, 0.55, 1.35, 2.2, 2.85, 3.4]
	_position_track(animation, "MotionRoot:position", times, [Vector3.ZERO, Vector3(0, 0.01, 0), Vector3(0, 0.015, 0), Vector3(0, 0.01, 0), Vector3.ZERO, Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips", times, [Vector3.ZERO, Vector3(0, -4, 0), Vector3(0, -6, 0), Vector3(0, 5, 0), Vector3(0, -3, 0), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/Spine", times, [Vector3.ZERO, Vector3(-4, -6, 0), Vector3(-3, -9, 0), Vector3(-3, 8, 0), Vector3(-4, -5, 0), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/Spine/HeadPivot", times, [Vector3.ZERO, Vector3(7, 12, -2), Vector3(3, 18, -3), Vector3(-4, -15, 2), Vector3(6, 10, -1), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg", times, [Vector3.ZERO, Vector3(4, 0, -2), Vector3(4, 0, -2), Vector3(-2, 0, 1), Vector3.ZERO, Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg", times, [Vector3.ZERO, Vector3(-3, 0, 2), Vector3(-3, 0, 2), Vector3(2, 0, -1), Vector3.ZERO, Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg/LKnee", times, [Vector3.ZERO, Vector3(-8, 0, 0), Vector3(-8, 0, 0), Vector3(-5, 0, 0), Vector3.ZERO, Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg/RKnee", times, [Vector3.ZERO, Vector3(-12, 0, 0), Vector3(-12, 0, 0), Vector3(-7, 0, 0), Vector3.ZERO, Vector3.ZERO])
	_position_track(animation, "MotionRoot/Hips/Spine/WeaponRig:position", times, [IDLE_WEAPON_POSITION, Vector3(0.03, 0.50, -0.43), Vector3(-0.03, 0.56, -0.46), Vector3(0.02, 0.54, -0.45), Vector3(0.05, 0.46, -0.40), IDLE_WEAPON_POSITION])
	_rotation_track(animation, "MotionRoot/Hips/Spine/WeaponRig", times, [IDLE_WEAPON_ROTATION_DEGREES, Vector3(-8, 8, 86), Vector3(-5, 14, 96), Vector3(-8, -12, 88), Vector3(-10, 4, 76), IDLE_WEAPON_ROTATION_DEGREES])
	_rotation_track(animation, "MotionRoot/Hips/CoatLeft", times, [Vector3(0, 0, 2), Vector3(-3, 2, 5), Vector3(-2, 3, 6), Vector3(2, -2, -1), Vector3(0, 0, 2), Vector3(0, 0, 2)])
	_rotation_track(animation, "MotionRoot/Hips/CoatRight", times, [Vector3(0, 0, -2), Vector3(2, -2, -5), Vector3(1, -3, -6), Vector3(-2, 2, 1), Vector3(0, 0, -2), Vector3(0, 0, -2)])
	return animation


func _attack_animation() -> Animation:
	var animation := _animation(1.35, false)
	var times: Array[float] = [0.0, 0.22, 0.48, 0.68, 0.90, 1.35]
	_position_track(animation, "MotionRoot:position", times, [Vector3.ZERO, Vector3(0, 0.02, 0.04), Vector3(0, 0.03, 0.07), Vector3(0, -0.015, -0.15), Vector3(0, 0, -0.10), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips", times, [Vector3.ZERO, Vector3(0, -16, -2), Vector3(0, -30, -4), Vector3(0, 24, 7), Vector3(0, 14, 3), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/Spine", times, [Vector3.ZERO, Vector3(-8, -18, -3), Vector3(-12, -24, -5), Vector3(16, 22, 9), Vector3(8, 12, 4), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/Spine/HeadPivot", times, [Vector3.ZERO, Vector3(-4, 12, 1), Vector3(-6, 18, 2), Vector3(7, -18, -2), Vector3(3, -10, -1), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg", times, [Vector3.ZERO, Vector3(8, 0, -3), Vector3(10, 0, -4), Vector3(6, 0, -3), Vector3(3, 0, -1), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg", times, [Vector3.ZERO, Vector3(-7, 0, 3), Vector3(-9, 0, 4), Vector3(-5, 0, 3), Vector3(-2, 0, 1), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg/LKnee", times, [Vector3.ZERO, Vector3(-14, 0, 0), Vector3(-18, 0, 0), Vector3(-12, 0, 0), Vector3(-7, 0, 0), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg/RKnee", times, [Vector3.ZERO, Vector3(-22, 0, 0), Vector3(-26, 0, 0), Vector3(-17, 0, 0), Vector3(-9, 0, 0), Vector3.ZERO])
	_position_track(animation, "MotionRoot/Hips/Spine/WeaponRig:position", times, [IDLE_WEAPON_POSITION, Vector3(0.02, 0.48, -0.28), Vector3(0.02, 0.50, -0.30), Vector3(-0.02, 0.28, -0.52), Vector3(-0.04, 0.16, -0.46), IDLE_WEAPON_POSITION], Animation.INTERPOLATION_LINEAR)
	_rotation_track(animation, "MotionRoot/Hips/Spine/WeaponRig", times, [IDLE_WEAPON_ROTATION_DEGREES, Vector3(-8, 0, -42), Vector3(-10, 0, -38), Vector3(-5, 0, 82), Vector3(-5, 0, 104), IDLE_WEAPON_ROTATION_DEGREES])
	_rotation_track(animation, "MotionRoot/Hips/CoatLeft", times, [Vector3(0, 0, 2), Vector3(-4, 4, 8), Vector3(-8, 7, 14), Vector3(10, -8, -12), Vector3(5, -4, -6), Vector3(0, 0, 2)])
	_rotation_track(animation, "MotionRoot/Hips/CoatRight", times, [Vector3(0, 0, -2), Vector3(3, -3, -7), Vector3(7, -6, -13), Vector3(-9, 7, 11), Vector3(-4, 3, 5), Vector3(0, 0, -2)])
	return animation


func _rain_pulse_animation() -> Animation:
	var animation := _animation(2.4, false)
	var times: Array[float] = [0.0, 0.55, 1.05, 1.35, 1.80, 2.4]
	_position_track(animation, "MotionRoot:position", times, [Vector3.ZERO, Vector3(0, -0.08, 0), Vector3(0, -0.15, -0.03), Vector3(0, 0.02, -0.05), Vector3(0, -0.04, -0.02), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips", times, [Vector3.ZERO, Vector3(-8, 0, 0), Vector3(-12, 0, 0), Vector3(5, 0, 0), Vector3(-3, 0, 0), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/Spine", times, [Vector3.ZERO, Vector3(14, 0, 0), Vector3(19, 0, 0), Vector3(-10, 0, 0), Vector3(5, 0, 0), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/Spine/HeadPivot", times, [Vector3.ZERO, Vector3(-8, 0, 0), Vector3(-12, 0, 0), Vector3(8, 0, 0), Vector3(-3, 0, 0), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg", times, [Vector3.ZERO, Vector3(8, 0, -3), Vector3(11, 0, -4), Vector3(6, 0, -2), Vector3(3, 0, -1), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg", times, [Vector3.ZERO, Vector3(8, 0, 3), Vector3(11, 0, 4), Vector3(6, 0, 2), Vector3(3, 0, 1), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg/LKnee", times, [Vector3.ZERO, Vector3(-22, 0, 0), Vector3(-30, 0, 0), Vector3(-18, 0, 0), Vector3(-8, 0, 0), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg/RKnee", times, [Vector3.ZERO, Vector3(-22, 0, 0), Vector3(-30, 0, 0), Vector3(-18, 0, 0), Vector3(-8, 0, 0), Vector3.ZERO])
	_position_track(animation, "MotionRoot/Hips/Spine/WeaponRig:position", times, [IDLE_WEAPON_POSITION, Vector3(0.02, 0.44, -0.42), Vector3(0.0, 0.34, -0.48), Vector3(0.0, 0.28, -0.50), Vector3(0.04, 0.38, -0.44), IDLE_WEAPON_POSITION])
	_rotation_track(animation, "MotionRoot/Hips/Spine/WeaponRig", times, [IDLE_WEAPON_ROTATION_DEGREES, Vector3(-8, 0, 18), Vector3(-5, 0, 4), Vector3(-3, 0, 2), Vector3(-6, 0, 20), IDLE_WEAPON_ROTATION_DEGREES])
	_rotation_track(animation, "MotionRoot/Hips/CoatLeft", times, [Vector3(0, 0, 2), Vector3(-7, 4, 9), Vector3(-12, 7, 15), Vector3(8, -6, -8), Vector3(3, -2, -1), Vector3(0, 0, 2)])
	_rotation_track(animation, "MotionRoot/Hips/CoatRight", times, [Vector3(0, 0, -2), Vector3(-7, -4, -9), Vector3(-12, -7, -15), Vector3(8, 6, 8), Vector3(3, 2, 1), Vector3(0, 0, -2)])
	return animation


func _run_animation() -> Animation:
	var animation := _animation(0.86, true)
	var times: Array[float] = [0.0, 0.215, 0.43, 0.645, 0.86]
	_position_track(animation, "MotionRoot:position", times, [Vector3.ZERO, Vector3(0, 0.05, -0.025), Vector3.ZERO, Vector3(0, 0.05, -0.025), Vector3.ZERO])
	_rotation_track(animation, "MotionRoot/Hips", times, [Vector3(1, -5, -3), Vector3(-1, 0, 3), Vector3(1, 5, -3), Vector3(-1, 0, 3), Vector3(1, -5, -3)])
	_rotation_track(animation, "MotionRoot/Hips/Spine", times, [Vector3(-14, 7, 2), Vector3(-11, 0, -2), Vector3(-14, -7, 2), Vector3(-11, 0, -2), Vector3(-14, 7, 2)])
	_rotation_track(animation, "MotionRoot/Hips/Spine/HeadPivot", times, [Vector3(5, -3, 0), Vector3(3, 0, 0), Vector3(5, 3, 0), Vector3(3, 0, 0), Vector3(5, -3, 0)])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg", times, [Vector3(34, 0, -2), Vector3(0, 0, 0), Vector3(-34, 0, 2), Vector3(0, 0, 0), Vector3(34, 0, -2)])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg", times, [Vector3(-34, 0, 2), Vector3(0, 0, 0), Vector3(34, 0, -2), Vector3(0, 0, 0), Vector3(-34, 0, 2)])
	_rotation_track(animation, "MotionRoot/Hips/LeftLeg/LKnee", times, [Vector3(-18, 0, 0), Vector3(-36, 0, 0), Vector3(-64, 0, 0), Vector3(-30, 0, 0), Vector3(-18, 0, 0)])
	_rotation_track(animation, "MotionRoot/Hips/RightLeg/RKnee", times, [Vector3(-64, 0, 0), Vector3(-30, 0, 0), Vector3(-18, 0, 0), Vector3(-36, 0, 0), Vector3(-64, 0, 0)])
	_position_track(animation, "MotionRoot/Hips/Spine/WeaponRig:position", times, [Vector3(0.08, 0.26, -0.36), Vector3(0.07, 0.28, -0.37), Vector3(0.08, 0.26, -0.36), Vector3(0.07, 0.28, -0.37), Vector3(0.08, 0.26, -0.36)])
	_rotation_track(animation, "MotionRoot/Hips/Spine/WeaponRig", times, [Vector3(-12, -10, 60), Vector3(-10, -5, 56), Vector3(-12, 2, 58), Vector3(-10, -5, 62), Vector3(-12, -10, 60)])
	_rotation_track(animation, "MotionRoot/Hips/CoatLeft", times, [Vector3(-10, 4, 12), Vector3(4, -2, -4), Vector3(-8, -4, 8), Vector3(5, 2, -5), Vector3(-10, 4, 12)])
	_rotation_track(animation, "MotionRoot/Hips/CoatRight", times, [Vector3(-8, -4, -8), Vector3(5, 2, 5), Vector3(-10, 4, -12), Vector3(4, -2, 4), Vector3(-8, -4, -8)])
	return animation


func _animation(length: float, looping: bool) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	return animation


func _position_track(
	animation: Animation,
	property_path: String,
	times: Array[float],
	values: Array[Vector3],
	interpolation: int = Animation.INTERPOLATION_CUBIC
) -> void:
	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath(property_path))
	animation.track_set_interpolation_type(track_index, interpolation)
	animation.track_set_interpolation_loop_wrap(track_index, false)
	for index: int in range(times.size()):
		animation.track_insert_key(track_index, times[index], values[index])


func _rotation_track(animation: Animation, node_path: String, times: Array[float], degrees_values: Array[Vector3]) -> void:
	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath(node_path + ":quaternion"))
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	animation.track_set_interpolation_loop_wrap(track_index, false)
	for index: int in range(times.size()):
		var rotation_quaternion := Basis.from_euler(_rad(degrees_values[index])).get_rotation_quaternion().normalized()
		animation.track_insert_key(track_index, times[index], rotation_quaternion)


func _solve_arms() -> void:
	if not _primary_grip or not _secondary_grip:
		return
	_solve_arm(_right_arm, _right_forearm, _primary_grip.global_position, 1.0)
	_solve_arm(_left_arm, _left_forearm, _secondary_grip.global_position, -1.0)


func _solve_arm(upper_arm: Node3D, forearm: Node3D, hand_target: Vector3, side: float) -> void:
	var shoulder := upper_arm.global_position
	var target_delta := hand_target - shoulder
	if target_delta.length_squared() < 0.000001:
		return
	var target_distance := clampf(target_delta.length(), 0.08, UPPER_ARM_LENGTH + LOWER_ARM_LENGTH - 0.015)
	var target_direction := target_delta.normalized()
	var along := (UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - LOWER_ARM_LENGTH * LOWER_ARM_LENGTH + target_distance * target_distance) / (2.0 * target_distance)
	var bend_height := sqrt(maxf(UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - along * along, 0.0))
	var hint_offset := _spine.global_transform.basis * Vector3(side * 0.38, -0.12, -0.36)
	var hint_direction := hint_offset - target_direction * hint_offset.dot(target_direction)
	if hint_direction.length_squared() < 0.000001:
		hint_direction = target_direction.cross(_spine.global_transform.basis.z)
	if hint_direction.length_squared() < 0.000001:
		hint_direction = target_direction.cross(Vector3.UP)
	var elbow := shoulder + target_direction * along + hint_direction.normalized() * bend_height
	var roll_reference := _spine.global_transform.basis.z
	upper_arm.global_transform = Transform3D(_basis_aiming_negative_y(elbow - shoulder, roll_reference), shoulder)
	forearm.global_transform = Transform3D(_basis_aiming_negative_y(hand_target - elbow, roll_reference), elbow)


func _basis_aiming_negative_y(direction: Vector3, roll_reference: Vector3) -> Basis:
	var y_axis := -direction.normalized()
	var z_axis := roll_reference - y_axis * roll_reference.dot(y_axis)
	if z_axis.length_squared() < 0.000001:
		z_axis = Vector3.FORWARD - y_axis * Vector3.FORWARD.dot(y_axis)
	z_axis = z_axis.normalized()
	var x_axis := y_axis.cross(z_axis).normalized()
	z_axis = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _pivot(parent: Node3D, node_name: String, local_position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = local_position
	parent.add_child(pivot)
	return pivot


func _rad(degrees: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


func _on_animation_finished(clip_name: StringName) -> void:
	if clip_name in ONE_SHOT_CLIPS:
		play_clip(&"idle")
