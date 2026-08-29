extends Node3D

const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")
const DEFINITIONS: Array[EnemyDefinition] = [
	preload("res://resources/gameplay/enemies/ruptured.tres"),
	preload("res://resources/gameplay/enemies/doorbreaker.tres"),
	preload("res://resources/gameplay/enemies/armored_scavenger.tres"),
	preload("res://resources/gameplay/enemies/wet_gunner.tres"),
]
const ACTION_LABELS: Array[String] = [
	"HEAVY LEAP",
	"ATTACK WINDUP",
	"MELEE STRIKE",
	"RANGED AIM",
]

@onready var camera: Camera3D = $Camera3D
@onready var lineup: Node3D = $Lineup

var _enemies: Array[EnemyBase] = []
var _cycle_elapsed: float = 0.0
var _impact_triggered: bool = false
var _impact_capture_saved: bool = false


func _process(delta: float) -> void:
	if _enemies.size() != DEFINITIONS.size():
		return
	_cycle_elapsed += delta
	if not _impact_triggered and _cycle_elapsed >= 1.2:
		_impact_triggered = true
	if _impact_triggered and not _impact_capture_saved and _cycle_elapsed >= 1.36:
		_impact_capture_saved = true
		_save_capture("res://.codex_artifacts/enemy_heavy_impact.png", "ENEMY_ANIMATION_IMPACT_CAPTURE")
	if _cycle_elapsed >= 2.6:
		_start_live_cycle()


func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	for index: int in DEFINITIONS.size():
		var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
		enemy.definition = DEFINITIONS[index]
		enemy.position = Vector3(-4.2 + index * 2.8, 0.0, 0.0)
		enemy.rotation.y = PI + deg_to_rad(-18.0 + index * 12.0)
		lineup.add_child(enemy)
		enemy.set_physics_process(false)
		_enemies.append(enemy)
		_add_label(enemy, DEFINITIONS[index].display_name, ACTION_LABELS[index])

	_pose_lineup()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_save_capture("res://.codex_artifacts/enemy_heavy_windup.png", "ENEMY_ANIMATION_ACCEPTANCE_CAPTURE")
	_pose_reaction_lineup()
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://.codex_artifacts/enemy_reaction_acceptance.png", "ENEMY_REACTION_ACCEPTANCE_CAPTURE")
	print("ENEMY_ANIMATION_ACCEPTANCE_READY")
	_start_live_cycle()


func _save_capture(capture_path: String, log_prefix: String) -> void:
	var error: Error = get_viewport().get_texture().get_image().save_png(capture_path)
	if error == OK:
		print("%s: %s" % [log_prefix, ProjectSettings.globalize_path(capture_path)])
	else:
		push_error("EnemyAnimationAcceptance: failed to save viewport capture (%s)" % error_string(error))


func _pose_lineup() -> void:
	var heavy: EnemyAnimationController = _enemies[0].get_animation_controller()
	heavy.play_attack(DEFINITIONS[0].heavy_attack_timing, false, EnemyAnimationController.ATTACK_STYLE_HEAVY)
	heavy.set_heavy_lunge_amount(1.0)
	heavy._process(DEFINITIONS[0].heavy_attack_timing.windup_seconds * 0.30)

	var melee: EnemyAnimationController = _enemies[1].get_animation_controller()
	melee.play_attack(ActionTimingDefinition.from_phases(2.0, 0.2, 0.1, 0.4), false)
	melee._process(1.25)

	var armored: EnemyAnimationController = _enemies[2].get_animation_controller()
	armored.play_attack(ActionTimingDefinition.from_phases(2.0, 0.2, 0.1, 0.4), false)
	armored._process(1.25)

	var ranged: EnemyAnimationController = _enemies[3].get_animation_controller()
	ranged.play_attack(ActionTimingDefinition.from_phases(2.0, 0.2, 0.1, 0.4), true)
	ranged._process(1.25)


func _pose_reaction_lineup() -> void:
	var reaction_labels: Array[String] = ["HIT STAGGER", "SHOVE KNOCKBACK", "PARRY KNOCKBACK", "HIT STAGGER"]
	for index: int in _enemies.size():
		var label: Label3D = _enemies[index].find_child("ReactionLabel", true, false) as Label3D
		if label != null:
			label.text = "%s\n%s" % [DEFINITIONS[index].display_name.to_upper(), reaction_labels[index]]
	var hurt: EnemyAnimationController = _enemies[0].get_animation_controller()
	hurt.play_reaction(EnemyAnimationController.ACTION_HURT, DEFINITIONS[0].hurt_timing, 0.8)
	hurt._process(0.30)

	var shoved: EnemyAnimationController = _enemies[1].get_animation_controller()
	shoved.play_reaction(EnemyAnimationController.ACTION_SHOVED, DEFINITIONS[1].hurt_timing, 1.5)
	shoved._process(0.52)

	var parried: EnemyAnimationController = _enemies[2].get_animation_controller()
	parried.play_reaction(EnemyAnimationController.ACTION_PARRIED, DEFINITIONS[2].hurt_timing, 2.25)
	parried._process(0.72)

	var gunner_hurt: EnemyAnimationController = _enemies[3].get_animation_controller()
	gunner_hurt.play_reaction(EnemyAnimationController.ACTION_HURT, DEFINITIONS[3].hurt_timing, 0.8)
	gunner_hurt._process(0.30)


func _start_live_cycle() -> void:
	_cycle_elapsed = 0.0
	_impact_triggered = false
	var heavy_label: Label3D = _enemies[0].find_child("ReactionLabel", true, false) as Label3D
	if heavy_label != null:
		heavy_label.text = "RUPTURED\nHEAVY IMPACT"
	_enemies[0].get_animation_controller().play_attack(DEFINITIONS[0].heavy_attack_timing, false, EnemyAnimationController.ATTACK_STYLE_HEAVY)
	var cycle_timing := ActionTimingDefinition.from_phases(1.2, 0.12, 0.12, 0.7)
	_enemies[1].get_animation_controller().play_attack(cycle_timing, false)
	_enemies[2].get_animation_controller().play_attack(cycle_timing, false)
	_enemies[3].get_animation_controller().play_attack(cycle_timing, true)


func _add_label(enemy: EnemyBase, display_name: String, action_name: String) -> void:
	var label: Label3D = Label3D.new()
	label.position = Vector3(0.0, 3.05, 0.0)
	label.text = "%s\n%s" % [display_name.to_upper(), action_name]
	label.font_size = 23
	label.outline_size = 7
	label.modulate = Color(0.9, 0.95, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.name = "ReactionLabel"
	enemy.add_child(label)
