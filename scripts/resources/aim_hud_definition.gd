class_name AimHudDefinition
extends Resource

@export var color: Color = Color(0.94, 0.97, 1.0, 0.9)
@export var outline_color: Color = Color(0.01, 0.02, 0.03, 0.8)
@export_range(0.5, 4.0) var dot_radius: float = 1.5
@export_range(1.0, 3.0) var line_width: float = 1.5
@export_range(2.0, 16.0) var line_length: float = 6.0
@export_range(2.0, 20.0) var minimum_gap: float = 8.0
@export_range(2.0, 12.0) var interaction_radius: float = 5.0
@export_range(0.0, 1.0) var recoil_follow: float = 0.3
@export_range(0.0, 30.0) var recoil_limit_pixels: float = 7.0
@export_range(0.01, 0.3) var response_seconds: float = 0.045
@export var hit_color: Color = Color.WHITE
@export var headshot_color: Color = Color(1.0, 0.76, 0.24)
@export var kill_color: Color = Color(1.0, 0.24, 0.2)
@export var hit_display_seconds: float = 0.12
@export var headshot_display_seconds: float = 0.2
@export var kill_display_seconds: float = 0.3
