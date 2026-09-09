class_name WatchProjectionOverlay
extends Control

const GRID_COLOR: Color = Color(0.10, 0.82, 0.74, 0.14)
const FRAME_COLOR: Color = Color(0.30, 1.0, 0.88, 0.60)


func _draw() -> void:
	var viewport_rect := Rect2(Vector2.ZERO, size)
	for index: int in range(1, 13):
		var x: float = size.x * float(index) / 13.0
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_COLOR, 1.0)
	for index: int in range(1, 8):
		var y: float = size.y * float(index) / 8.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
	draw_rect(viewport_rect.grow(-22.0), FRAME_COLOR, false, 1.0)
