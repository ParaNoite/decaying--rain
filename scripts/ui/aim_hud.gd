class_name AimHud
extends Control

@export var definition: AimHudDefinition = preload("res://resources/ui/aim_hud.tres")
@onready var hit_marker: HitMarker = $HitMarker
@onready var prompt_label: Label = $PromptLabel

var player: Player3DController
var center_visible: bool = true
var outer_visible: bool = false
var interaction_active: bool = false
var spread_radius: float = 8.0
var outer_offset: Vector2 = Vector2.ZERO
var _enabled: bool = true
var _event_bus: Node


func _ready() -> void:
	process_priority = 100
	hit_marker.definition = definition
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null:
		_event_bus.damage_resolved.connect(_on_damage_resolved)
		_event_bus.interaction_prompt_changed.connect(set_prompt)
	update_from_player(0.0)
	if is_instance_valid(player) and player.interaction_driver.has_valid_focus():
		set_prompt(player.interaction_driver.focused_interactable.prompt)


func _exit_tree() -> void:
	if is_instance_valid(_event_bus):
		_event_bus.damage_resolved.disconnect(_on_damage_resolved)
		_event_bus.interaction_prompt_changed.disconnect(set_prompt)


func _process(delta: float) -> void:
	update_from_player(delta)


func set_gameplay_visible(value: bool) -> void:
	_enabled = value
	if not value:
		hit_marker.clear()
	update_from_player(0.0)


func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = center_visible and not text.is_empty()


func update_from_player(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player3DController
	visible = _enabled and is_instance_valid(player)
	if not visible:
		hit_marker.clear()
		return
	visible = player.health.is_alive() and not player.watch_state_machine.is_active()
	if not visible:
		hit_marker.clear()
		return
	var driver: PlayerCombatDriver = player.combat_driver
	var firearm: bool = driver.is_current_firearm() and player.first_person_arms.held_item_id == &""
	var reload: bool = player.combat_state_machine.current_state == PlayerCombatStateMachine.STATE_RELOAD
	var sprint: bool = player.locomotion_state_machine.current_state == PlayerLocomotionStateMachine.STATE_SPRINT
	center_visible = not firearm or driver.aim_fraction < 0.5 or reload or sprint
	outer_visible = firearm and center_visible and not reload and not sprint
	interaction_active = player.interaction_driver.has_valid_focus()
	prompt_label.visible = center_visible and not prompt_label.text.is_empty()
	var radius: float = definition.minimum_gap
	var offset: Vector2 = Vector2.ZERO
	if firearm:
		var camera: Camera3D = player.camera_rig.camera
		var viewport_size: Vector2 = get_viewport_rect().size
		var focal_length: float = (viewport_size.y if camera.keep_aspect == Camera3D.KEEP_HEIGHT else viewport_size.x) * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
		radius = maxf(definition.minimum_gap, focal_length * tan(deg_to_rad(clampf(driver.get_current_spread(), 0.0, 80.0))))
		var recoil: Vector2 = player.first_person_arms.get_visual_recoil_degrees()
		offset = Vector2(-tan(deg_to_rad(recoil.y)), -tan(deg_to_rad(recoil.x))) * focal_length * definition.recoil_follow
		offset = offset.limit_length(definition.recoil_limit_pixels)
	var blend: float = 1.0 - exp(-maxf(0.0, delta) / maxf(0.001, definition.response_seconds))
	spread_radius = lerpf(spread_radius, radius, blend)
	outer_offset = outer_offset.lerp(offset, blend) if outer_visible else Vector2.ZERO
	queue_redraw()


func _on_damage_resolved(result: DamageResolutionData) -> void:
	if not _enabled or not is_visible_in_tree() or not is_instance_valid(player) or not player.health.is_alive() or player.watch_state_machine.is_active():
		return
	if result == null or not result.applied or result.blocked or result.event == null:
		return
	if result.event.attacker_id != player.get_instance_id() or not is_instance_valid(result.target):
		return
	if not result.target.is_in_group("enemy") and not result.target.is_in_group("firearm_target"):
		return
	var tags: Array[StringName] = result.event.source_tags
	if not (tags.has(&"firearm") or tags.has(&"melee") or tags.has(&"shove")):
		return
	if result.final_amount <= 0.0 and not (tags.has(&"shove") and result.event.stagger > 0.0):
		return
	var kind: int = HitMarker.Kind.KILL if result.killed else (HitMarker.Kind.HEADSHOT if tags.has(&"headshot") else HitMarker.Kind.HIT)
	hit_marker.show_hit(kind)


func _draw() -> void:
	if not center_visible:
		return
	var center: Vector2 = size * 0.5
	if interaction_active:
		draw_arc(center, definition.interaction_radius, 0.0, TAU, 40, definition.outline_color, definition.line_width + 2.0, true)
		draw_arc(center, definition.interaction_radius, 0.0, TAU, 40, definition.color, definition.line_width, true)
	else:
		draw_circle(center, definition.dot_radius + 1.0, definition.outline_color)
		draw_circle(center, definition.dot_radius, definition.color)
	if outer_visible:
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var start: Vector2 = center + outer_offset + direction * spread_radius
			var end: Vector2 = start + direction * definition.line_length
			draw_line(start, end, definition.outline_color, definition.line_width + 2.0, true)
			draw_line(start, end, definition.color, definition.line_width, true)
