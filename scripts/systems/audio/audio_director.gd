extends Node

const ACTION_CUES: Dictionary[StringName, StringName] = {
	&"reload": &"player.weapon.reload.finish",
	&"shove": &"player.combat.shove",
}

var _event_bus: Node
var _audio: Node
var _last_hit_audio_usec: int = 0


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	_audio = get_node_or_null("/root/AudioManager")
	if _event_bus == null:
		return
	_event_bus.phase_changed.connect(_on_phase_changed)
	_event_bus.player_footstep.connect(_on_player_footstep)
	_event_bus.player_footstep_stopped.connect(_on_player_footstep_stopped)
	_event_bus.player_action_audio.connect(_on_player_action_audio)
	_event_bus.player_firearm_shot.connect(_on_player_firearm_shot)
	_event_bus.enemy_action_audio.connect(_on_enemy_action_audio)
	_event_bus.combat_audio.connect(_on_combat_audio)
	_event_bus.interaction_audio.connect(_on_interaction_audio)
	_event_bus.ui_audio.connect(_on_ui_audio)
	_event_bus.player_died.connect(_on_player_died)
	_event_bus.enemy_died.connect(_on_enemy_died)
	_event_bus.world_item_picked_up.connect(_on_item_picked_up)
	_event_bus.resource_looted.connect(_on_resource_looted)
	_event_bus.loot_container_opened.connect(_on_loot_opened)
	_event_bus.item_used.connect(_on_item_used)


func _exit_tree() -> void:
	if _event_bus == null:
		return
	if _event_bus.player_firearm_shot.is_connected(_on_player_firearm_shot):
		_event_bus.player_firearm_shot.disconnect(_on_player_firearm_shot)
	for signal_name: StringName in [&"phase_changed", &"player_footstep", &"player_footstep_stopped", &"player_action_audio", &"enemy_action_audio", &"combat_audio", &"interaction_audio", &"ui_audio", &"player_died", &"enemy_died", &"world_item_picked_up", &"resource_looted", &"loot_container_opened", &"item_used"]:
		var callback: Callable = Callable(self, "_on_" + String(signal_name))
		if _event_bus.has_signal(signal_name) and _event_bus.is_connected(signal_name, callback):
			_event_bus.disconnect(signal_name, callback)


func _on_phase_changed(_previous: StringName, current: StringName, _wave: int) -> void:
	if _audio == null:
		return
	if current == &"rain":
		_audio.play_global_sfx(&"environment.rain.loop")
	else:
		_audio.stop_sfx(&"environment.rain.loop")
	_audio.stop_music(1.0)


func _on_player_footstep(position: Vector3, sprinting: bool) -> void:
	_play_3d(&"player.footstep.sprint" if sprinting else &"player.footstep.walk", position)


func _on_player_footstep_stopped(_position: Vector3) -> void:
	if _audio != null:
		_audio.stop_sfx(&"player.footstep.walk")
		_audio.stop_sfx(&"player.footstep.sprint")


func _on_player_action_audio(action_id: StringName, phase: StringName, position: Vector3) -> void:
	if phase == &"impact":
		_play_3d(ACTION_CUES.get(action_id, &""), position)
	elif phase == &"release":
		if action_id == &"reload":
			_play_3d(&"player.weapon.reload.start", position)


func _on_player_firearm_shot(cue_id: StringName, position: Vector3) -> void:
	_play_3d(cue_id, position)


func _on_enemy_action_audio(_enemy_id: StringName, _action_id: StringName, _phase: StringName, _position: Vector3) -> void:
	return


func _on_combat_audio(kind: StringName, position: Vector3, _intensity: float) -> void:
	if kind in [&"hit", &"hurt"]:
		var now_usec: int = Time.get_ticks_usec()
		if now_usec - _last_hit_audio_usec < 70000:
			return
		_last_hit_audio_usec = now_usec
	var cue_id: StringName = {
		&"hit": _random_hit_cue(),
		&"parry": &"",
		&"hurt": _random_hit_cue(),
		&"death": &"",
	}.get(kind, &"")
	if cue_id.is_empty():
		return
	_play_3d(cue_id, position)


func _on_interaction_audio(_kind: StringName, _position: Vector3) -> void:
	return


func _on_ui_audio(kind: StringName) -> void:
	if _audio != null:
		_audio.play_global_sfx(StringName("ui." + String(kind)))


func _on_player_died(_reason: StringName) -> void:
	return


func _on_enemy_died(_enemy_id: StringName, _instance_id: int, _wave: int) -> void:
	return


func _on_item_picked_up(_item_id: StringName, _quantity: int) -> void:
	return


func _on_resource_looted(_resource_id: StringName, _payload: Dictionary) -> void:
	return


func _on_loot_opened(_container_id: StringName, _payload: Dictionary) -> void:
	return


func _on_item_used(item_id: StringName, _quantity: int) -> void:
	if item_id == &"food_ration" and _audio != null:
		_audio.play_global_sfx(&"interaction.food.eat")


func _random_hit_cue() -> StringName:
	return StringName("combat.hit.%02d" % (randi_range(1, 3)))


func _play_3d(cue_id: StringName, position: Vector3, _intensity: float = 1.0) -> void:
	if _audio == null or cue_id.is_empty():
		return
	_audio.play_3d_sfx(cue_id, position)


func _player_position() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player != null else Vector3.ZERO
