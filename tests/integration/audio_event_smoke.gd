extends Node


func _ready() -> void:
	var event_bus: Node = get_tree().root.get_node_or_null("EventBus")
	var audio: Node = get_tree().root.get_node_or_null("AudioManager")
	var director: Node = get_tree().root.get_node_or_null("AudioDirector")
	_check(event_bus != null, "EventBus autoload missing")
	_check(audio != null, "AudioManager autoload missing")
	_check(director != null, "AudioDirector autoload missing")
	event_bus.phase_changed.emit(&"daylight", &"rain", 1)
	event_bus.player_footstep.emit(Vector3(1.0, 0.0, 2.0), false)
	event_bus.player_action_audio.emit(&"light_attack", &"impact", Vector3.ZERO)
	event_bus.enemy_action_audio.emit(&"test.enemy", &"attack", &"windup", Vector3(2.0, 0.0, 0.0))
	event_bus.combat_audio.emit(&"hit", Vector3.ZERO, 1.0)
	event_bus.interaction_audio.emit(&"start", Vector3.ZERO)
	event_bus.ui_audio.emit(&"watch.open")
	await get_tree().process_frame
	print("AUDIO_EVENT_SMOKE: PASS")
	get_tree().quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("AUDIO_EVENT_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
