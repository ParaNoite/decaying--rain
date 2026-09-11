class_name RenderQualityDefinition
extends Resource

@export_enum("low", "medium", "high") var preset: String = "medium"
@export_range(0.5, 1.0, 0.05) var render_scale: float = 1.0
@export_range(0, 4096, 1) var rain_particles: int = 900
@export_range(0.0, 200.0, 1.0) var shadow_distance: float = 55.0
@export var ssao_enabled: bool = false
@export var fog_enabled: bool = false

func apply(viewport: Viewport, environment: Environment, sun: DirectionalLight3D, emitters: Array[GPUParticles3D]) -> void:
	viewport.scaling_3d_scale = render_scale
	sun.shadow_enabled = shadow_distance > 0.0
	sun.directional_shadow_max_distance = shadow_distance
	if environment:
		environment.ssao_enabled = ssao_enabled
		environment.fog_enabled = fog_enabled
	for emitter: GPUParticles3D in emitters:
		emitter.amount = rain_particles

static func medium() -> RenderQualityDefinition:
	var result := RenderQualityDefinition.new()
	return result
