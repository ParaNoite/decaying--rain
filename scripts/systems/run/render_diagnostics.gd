class_name RenderDiagnostics
extends Node

@export var sample_interval: float = 1.0
var _elapsed: float = 0.0
var _min_fps: float = INF

func _process(delta: float) -> void:
	_elapsed += delta
	_min_fps = minf(_min_fps, Engine.get_frames_per_second())
	if _elapsed < sample_interval:
		return
	print("MVP_RENDER fps=%.1f min_fps=%.1f frame_ms=%.2f draw_calls=%d primitives=%d" % [Engine.get_frames_per_second(), _min_fps, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	_elapsed = 0.0
	_min_fps = INF
