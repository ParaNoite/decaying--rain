extends Node3D

@onready var player: Player3DController = %Player
@onready var status_label: Label = %StatusLabel

var _arms: PlayerFirstPersonArms
var _sprint_preview: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_arms = player.get_node("Head/Camera3D/FirstPersonArms") as PlayerFirstPersonArms
	print("PLAYER_ARMS_ACCEPTANCE_READY")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_1:
			_play_attack(1, "LIGHT 1 / RIGHT JAB")
		KEY_2:
			_play_attack(2, "LIGHT 2 / RIGHT HOOK")
		KEY_3:
			_play_attack(3, "LIGHT 3 / OVERHEAD")
		KEY_4:
			_play(&"play_heavy_attack", [player.combat_definition.heavy_attack_timing], "HEAVY ATTACK")
		KEY_5:
			_play(&"play_shove", [player.combat_definition.shove_timing], "SHOVE")
		KEY_6:
			_play(&"play_parry", [player.combat_definition.parry_timing], "PARRY")
		KEY_7:
			_play(&"play_interact", [player.combat_definition.interact_timing], "INTERACT")
		KEY_8:
			_play(&"play_jump", [player.movement_definition.jump_timing], "JUMP")
		KEY_9:
			_play(&"play_slide", [player.movement_definition.slide_timing], "SLIDE")
		KEY_0:
			_sprint_preview = not _sprint_preview
			_arms.set_sprinting(_sprint_preview)
			status_label.text = "SPRINT" if _sprint_preview else "IDLE"
		KEY_Q:
			player.play_parry_success_feedback()
			status_label.text = "PARRY SUCCESS"
		_:
			return


func _play_attack(combo: int, label_text: String) -> void:
	_sprint_preview = false
	_arms.set_sprinting(false)
	_arms.play_attack(combo, player.combat_driver.get_primary_timing())
	status_label.text = label_text


func _play(method_name: StringName, args: Array, label_text: String) -> void:
	_sprint_preview = false
	_arms.set_sprinting(false)
	_arms.callv(method_name, args)
	status_label.text = label_text
