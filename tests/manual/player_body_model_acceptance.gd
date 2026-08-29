extends Node3D

@onready var body: Node3D = $PlayerBodyVisual
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.look_at(Vector3(0.0, 0.85, 0.0))


func _process(delta: float) -> void:
	var turn: float = Input.get_axis("ui_left", "ui_right")
	body.rotation.y += turn * delta * 1.8
