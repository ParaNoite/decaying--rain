class_name WatchTacticalMap
extends Control

const WORLD_MIN_X: float = -24.0
const WORLD_MAX_X: float = 24.0
const WORLD_MIN_Z: float = -70.0
const WORLD_MAX_Z: float = 32.0
const HOLOGRAM: Color = Color(0.22, 0.95, 0.82, 0.92)
const DIM_HOLOGRAM: Color = Color(0.12, 0.46, 0.43, 0.78)
const MAP_FILL: Color = Color(0.03, 0.18, 0.19, 0.86)

var _player: Node3D


func set_player(player: Node3D) -> void:
	_player = player
	queue_redraw()


func get_region_name() -> String:
	if _player == null or not is_instance_valid(_player):
		return "LOCATION UNKNOWN"
	return "SCAVENGE AREA" if _player.global_position.z < -31.5 else "BASE COURTYARD"


func get_player_map_position() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2(-1.0, -1.0)
	return Vector2(
		clampf(inverse_lerp(WORLD_MIN_X, WORLD_MAX_X, _player.global_position.x), 0.0, 1.0),
		clampf(inverse_lerp(WORLD_MIN_Z, WORLD_MAX_Z, _player.global_position.z), 0.0, 1.0)
	)


func get_player_heading() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.UP
	var forward_3d: Vector3 = -_player.global_transform.basis.z
	var forward := Vector2(forward_3d.x, forward_3d.z).normalized()
	return Vector2.UP if forward.is_zero_approx() else forward


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return
	draw_rect(map_rect, MAP_FILL, true)
	draw_rect(map_rect, HOLOGRAM, false, 1.5)
	_draw_grid(map_rect)
	_draw_regions(map_rect)
	_draw_player(map_rect)


func _draw_grid(map_rect: Rect2) -> void:
	for index: int in range(1, 5):
		var horizontal: float = map_rect.position.y + map_rect.size.y * float(index) / 5.0
		var vertical: float = map_rect.position.x + map_rect.size.x * float(index) / 5.0
		draw_line(Vector2(map_rect.position.x, horizontal), Vector2(map_rect.end.x, horizontal), DIM_HOLOGRAM, 1.0)
		draw_line(Vector2(vertical, map_rect.position.y), Vector2(vertical, map_rect.end.y), DIM_HOLOGRAM, 1.0)


func _draw_regions(map_rect: Rect2) -> void:
	var base_top_left: Vector2 = _to_map(Vector3(WORLD_MIN_X, 0.0, -31.5), map_rect)
	var base_bottom_right: Vector2 = _to_map(Vector3(WORLD_MAX_X, 0.0, WORLD_MAX_Z), map_rect)
	var scavenge_top_left: Vector2 = _to_map(Vector3(WORLD_MIN_X, 0.0, WORLD_MIN_Z), map_rect)
	var scavenge_bottom_right: Vector2 = _to_map(Vector3(WORLD_MAX_X, 0.0, -31.5), map_rect)
	draw_rect(Rect2(scavenge_top_left, scavenge_bottom_right - scavenge_top_left), Color(0.08, 0.34, 0.31, 0.28), true)
	draw_rect(Rect2(base_top_left, base_bottom_right - base_top_left), Color(0.18, 0.52, 0.45, 0.30), true)
	var north_gate: Vector2 = _to_map(Vector3(0.0, 0.0, -31.5), map_rect)
	var south_gate: Vector2 = _to_map(Vector3(0.0, 0.0, 31.4), map_rect)
	draw_circle(north_gate, 4.0, HOLOGRAM)
	draw_circle(south_gate, 4.0, HOLOGRAM)


func _draw_player(map_rect: Rect2) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var center: Vector2 = _to_map(_player.global_position, map_rect)
	var forward: Vector2 = get_player_heading()
	var right := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		center + forward * 9.0,
		center - forward * 6.0 + right * 5.0,
		center - forward * 6.0 - right * 5.0,
	])
	draw_colored_polygon(points, Color(0.94, 1.0, 0.98, 1.0))
	draw_arc(center, 13.0, 0.0, TAU, 24, HOLOGRAM, 1.0)


func _to_map(world_position: Vector3, map_rect: Rect2) -> Vector2:
	var x_ratio: float = inverse_lerp(WORLD_MIN_X, WORLD_MAX_X, world_position.x)
	var z_ratio: float = inverse_lerp(WORLD_MIN_Z, WORLD_MAX_Z, world_position.z)
	return Vector2(
		map_rect.position.x + clampf(x_ratio, 0.0, 1.0) * map_rect.size.x,
		map_rect.position.y + clampf(z_ratio, 0.0, 1.0) * map_rect.size.y
	)
