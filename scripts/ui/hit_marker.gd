class_name HitMarker
extends Control

enum Kind { HIT, HEADSHOT, KILL }

@export var definition: AimHudDefinition = preload("res://resources/ui/aim_hud.tres")
var kind: int = Kind.HIT
var _duration: float = 0.12
const LINE_WIDTH: float = 2.0
const INNER_RADIUS: float = 8.0
const OUTER_RADIUS: float = 14.0

var _remaining_seconds: float = 0.0


func _ready() -> void:
	visible = false
	queue_redraw()


func show_hit(value: int = Kind.HIT) -> void:
	if is_active() and value < kind:
		return
	kind = clampi(value, Kind.HIT, Kind.KILL)
	_duration = [definition.hit_display_seconds, definition.headshot_display_seconds, definition.kill_display_seconds][kind]
	_remaining_seconds = maxf(0.001, _duration)
	visible = true
	queue_redraw()


func clear() -> void:
	_remaining_seconds = 0.0
	kind = Kind.HIT
	hide()
	queue_redraw()


func is_active() -> bool:
	return visible and _remaining_seconds > 0.0


func _process(delta: float) -> void:
	if _remaining_seconds <= 0.0:
		return
	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta))
	if _remaining_seconds <= 0.0:
		visible = false
	queue_redraw()


func _draw() -> void:
	if _remaining_seconds <= 0.0:
		return
	var progress: float = 1.0 - _remaining_seconds / maxf(0.001, _duration)
	var alpha: float = clampf(_remaining_seconds / maxf(0.001, _duration) * 2.0, 0.0, 1.0)
	var inner_radius: float = lerpf(INNER_RADIUS, INNER_RADIUS + 2.0, progress)
	var outer_radius: float = lerpf(OUTER_RADIUS, OUTER_RADIUS + 3.0, progress)
	var color: Color = [definition.hit_color, definition.headshot_color, definition.kill_color][kind]
	color.a *= alpha
	var center: Vector2 = size * 0.5
	for direction: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		var normalized_direction: Vector2 = direction.normalized()
		draw_line(
			center + normalized_direction * inner_radius,
			center + normalized_direction * outer_radius,
			color,
			LINE_WIDTH,
			true
		)
		if kind == Kind.KILL:
			draw_line(center + normalized_direction * (inner_radius + 4.0), center + normalized_direction * (outer_radius + 5.0), color, LINE_WIDTH + 1.0, true)
	if kind == Kind.HEADSHOT:
		draw_arc(center, 4.0, 0.0, TAU, 24, color, 1.5, true)
	elif kind == Kind.KILL:
		draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), color, LINE_WIDTH, true)
		draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), color, LINE_WIDTH, true)
