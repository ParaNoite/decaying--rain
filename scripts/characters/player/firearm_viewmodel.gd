class_name FirearmViewmodel
extends Node3D
## Presentation only. The combat driver remains the authority for action timing.
## Local -Z is forward, +Y is up; root origin is the right-hand grip.

@export var aim_point: Marker3D
@export var muzzle: Marker3D
@export var muzzle_flash: GeometryInstance3D
@export var animation_player: AnimationPlayer
@export var muzzle_light: OmniLight3D
var _flash_frame: int = -1
var _clip: StringName = &""
var _animated_parts: Array[WeaponAnimatedPart] = []


func _ready() -> void:
	assert(aim_point != null and muzzle != null, "Viewmodel requires AimPoint and Muzzle")
	_disable_shadows(self)
	set_muzzle_flash(false)
	for part: Node in find_children("*", "WeaponAnimatedPart", true, false):
		_animated_parts.append(part as WeaponAnimatedPart)


func set_muzzle_flash(active: bool) -> void:
	active = active or (_flash_frame >= 0 and Engine.get_frames_drawn() <= _flash_frame)
	if muzzle_flash != null:
		muzzle_flash.visible = active
	if muzzle_light != null:
		muzzle_light.visible = active


func confirm_shot() -> void:
	# A short impact phase may fall between render frames. Show the confirmed shot.
	_flash_frame = Engine.get_frames_drawn()
	set_muzzle_flash(true)


func sample_action(action: StringName, timing: ActionTimingDefinition, elapsed: float) -> void:
	if animation_player == null:
		return
	if timing == null or not animation_player.has_animation(action) or elapsed >= timing.total_seconds():
		reset_action()
		return
	if _clip != action:
		var confirmed_flash_frame: int = _flash_frame
		reset_action()
		_flash_frame = confirmed_flash_frame
		_clip = action
		animation_player.play(action)
		animation_player.pause()
	var phase: ActionTimingDefinition.Phase = timing.phase_at(elapsed)
	var duration: float = timing.phase_duration(phase)
	var progress: float = clampf((elapsed - timing.phase_start_seconds(phase)) / maxf(duration, 0.000001), 0.0, 1.0)
	# Clip units 0..4 are phase coordinates, never gameplay seconds.
	animation_player.seek(float(phase) + progress, true)
	for part: WeaponAnimatedPart in _animated_parts:
		part.apply_pose()


func reset_action() -> void:
	_flash_frame = -1
	_clip = &""
	if animation_player != null:
		animation_player.stop()
	for part: WeaponAnimatedPart in _animated_parts:
		part.reset_pose()
	set_muzzle_flash(false)


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_disable_shadows(child)
