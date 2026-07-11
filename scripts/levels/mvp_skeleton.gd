extends Node3D

@export var auto_start_run: bool = true
@onready var phase_controller: PhaseController = %PhaseController


func _ready() -> void:
	if auto_start_run:
		phase_controller.begin_run()
