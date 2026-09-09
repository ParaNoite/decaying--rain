class_name MeleeImpactEffects
extends RefCounted

const BLOOD_LIFETIME_SECONDS: float = 0.62
const ENVIRONMENT_LIFETIME_SECONDS: float = 0.42


static func spawn_blood(parent: Node, impact_position: Vector3, spray_direction: Vector3) -> void:
	var direction: Vector3 = _safe_direction(spray_direction, Vector3.UP)
	_spawn_particle_burst(
		parent,
		impact_position,
		direction,
		30,
		BLOOD_LIFETIME_SECONDS,
		0.18,
		2.8,
		5.4,
		Vector3(0.0, -8.0, 0.0),
		Color(0.72, 0.012, 0.02, 1.0),
		Color(0.16, 0.002, 0.006, 0.0)
	)


static func spawn_environment_impact(parent: Node, impact_position: Vector3, surface_normal: Vector3) -> void:
	var direction: Vector3 = _safe_direction(surface_normal, Vector3.UP)
	_spawn_particle_burst(
		parent,
		impact_position + direction * 0.02,
		direction,
		18,
		ENVIRONMENT_LIFETIME_SECONDS,
		0.10,
		1.8,
		3.6,
		Vector3(0.0, -8.0, 0.0),
		Color(1.0, 0.72, 0.28, 0.92),
		Color(0.34, 0.24, 0.16, 0.0)
	)


static func _spawn_particle_burst(
	parent: Node,
	impact_position: Vector3,
	direction: Vector3,
	amount: int,
	lifetime_seconds: float,
	particle_size: float,
	minimum_velocity: float,
	maximum_velocity: float,
	gravity: Vector3,
	start_color: Color,
	end_color: Color
) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# 无渲染设备的自动化环境只验证命中数据，不能初始化 GPU 粒子。
	if OS.has_feature("headless"):
		return
	var impact: GPUParticles3D = GPUParticles3D.new()
	impact.amount = amount
	impact.lifetime = lifetime_seconds
	impact.one_shot = true
	impact.explosiveness = 1.0
	impact.local_coords = false
	impact.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	impact.emitting = false

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.045
	process_material.direction = direction
	process_material.spread = 58.0
	process_material.initial_velocity_min = minimum_velocity
	process_material.initial_velocity_max = maximum_velocity
	process_material.gravity = gravity
	process_material.damping_min = 1.5
	process_material.damping_max = 3.0
	process_material.scale_min = 0.8
	process_material.scale_max = 1.35
	process_material.color_ramp = _create_color_ramp(start_color, end_color)
	impact.process_material = process_material

	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(particle_size, particle_size)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	impact.draw_pass_1 = mesh

	parent.add_child(impact)
	impact.global_position = impact_position
	impact.finished.connect(impact.queue_free, CONNECT_ONE_SHOT)
	impact.restart()
	impact.emitting = true


static func _create_color_ramp(start_color: Color, end_color: Color) -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, start_color)
	gradient.add_point(0.45, start_color.lerp(end_color, 0.35))
	gradient.set_color(1, end_color)
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _safe_direction(direction: Vector3, fallback: Vector3) -> Vector3:
	if direction.length_squared() <= 0.0001:
		return fallback.normalized()
	return direction.normalized()
