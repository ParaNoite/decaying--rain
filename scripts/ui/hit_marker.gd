class_name HitMarker
extends Control

const DISPLAY_SECONDS: float = 0.12
const LINE_WIDTH: float = 2.0
const INNER_RADIUS: float = 8.0
const OUTER_RADIUS: float = 14.0

var _remaining_seconds: float = 0.0


func _ready() -> void:
	visible = false
	queue_redraw()


func show_hit() -> void:
	_remaining_seconds = DISPLAY_SECONDS
	visible = true
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
	var progress: float = 1.0 - _remaining_seconds / DISPLAY_SECONDS
	var alpha: float = clampf(_remaining_seconds / DISPLAY_SECONDS, 0.0, 1.0)
	var inner_radius: float = lerpf(INNER_RADIUS, INNER_RADIUS + 2.0, progress)
	var outer_radius: float = lerpf(OUTER_RADIUS, OUTER_RADIUS + 3.0, progress)
	var color: Color = Color(1.0, 1.0, 1.0, alpha)
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
