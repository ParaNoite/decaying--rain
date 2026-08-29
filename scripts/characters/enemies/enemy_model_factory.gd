class_name EnemyModelFactory
extends RefCounted


static func material(
	name: String,
	color: Color,
	metallic: float,
	roughness: float,
	emission_color: Color = Color.TRANSPARENT,
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.resource_name = name
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.rim_enabled = true
	result.rim = 0.16
	result.rim_tint = 0.42
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


static func box(
	parent: Node3D,
	name: String,
	size: Vector3,
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material
) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh_instance(parent, name, mesh, position, rotation_degrees, mesh_material)


static func cylinder(
	parent: Node3D,
	name: String,
	top_radius: float,
	bottom_radius: float,
	height: float,
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material,
	radial_segments: int = 14
) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = 2
	return _mesh_instance(parent, name, mesh, position, rotation_degrees, mesh_material)


static func capsule(
	parent: Node3D,
	name: String,
	radius: float,
	height: float,
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material,
	radial_segments: int = 14
) -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = radial_segments
	mesh.rings = 6
	return _mesh_instance(parent, name, mesh, position, rotation_degrees, mesh_material)


static func sphere(
	parent: Node3D,
	name: String,
	radius: float,
	height: float,
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material,
	radial_segments: int = 18
) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = 10
	return _mesh_instance(parent, name, mesh, position, rotation_degrees, mesh_material)


static func torus(
	parent: Node3D,
	name: String,
	inner_radius: float,
	outer_radius: float,
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material
) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 20
	mesh.ring_segments = 8
	return _mesh_instance(parent, name, mesh, position, rotation_degrees, mesh_material)


static func tapered_box(
	parent: Node3D,
	name: String,
	top_half_size: Vector2,
	bottom_half_size: Vector2,
	height: float,
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material
) -> MeshInstance3D:
	var y_top: float = height * 0.5
	var y_bottom: float = -height * 0.5
	var vertices: Array[Vector3] = [
		Vector3(-top_half_size.x, y_top, -top_half_size.y),
		Vector3(top_half_size.x, y_top, -top_half_size.y),
		Vector3(top_half_size.x, y_top, top_half_size.y),
		Vector3(-top_half_size.x, y_top, top_half_size.y),
		Vector3(-bottom_half_size.x, y_bottom, -bottom_half_size.y),
		Vector3(bottom_half_size.x, y_bottom, -bottom_half_size.y),
		Vector3(bottom_half_size.x, y_bottom, bottom_half_size.y),
		Vector3(-bottom_half_size.x, y_bottom, bottom_half_size.y),
	]
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([7, 6, 5, 4]),
		PackedInt32Array([0, 4, 5, 1]), PackedInt32Array([1, 5, 6, 2]),
		PackedInt32Array([2, 6, 7, 3]), PackedInt32Array([3, 7, 4, 0]),
	]
	return _surface_mesh(parent, name, vertices, faces, position, rotation_degrees, mesh_material)


static func scrap_blade(
	parent: Node3D,
	name: String,
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material
) -> MeshInstance3D:
	var vertices: Array[Vector3] = [
		Vector3(-0.055, -0.36, -0.028), Vector3(0.055, -0.36, -0.028),
		Vector3(0.25, -0.10, -0.028), Vector3(0.31, 0.30, -0.028),
		Vector3(0.10, 0.40, -0.028), Vector3(-0.055, 0.27, -0.028),
		Vector3(-0.055, -0.36, 0.028), Vector3(0.055, -0.36, 0.028),
		Vector3(0.25, -0.10, 0.028), Vector3(0.31, 0.30, 0.028),
		Vector3(0.10, 0.40, 0.028), Vector3(-0.055, 0.27, 0.028),
	]
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, 2, 3, 4, 5]), PackedInt32Array([11, 10, 9, 8, 7, 6]),
		PackedInt32Array([0, 6, 7, 1]), PackedInt32Array([1, 7, 8, 2]),
		PackedInt32Array([2, 8, 9, 3]), PackedInt32Array([3, 9, 10, 4]),
		PackedInt32Array([4, 10, 11, 5]), PackedInt32Array([5, 11, 6, 0]),
	]
	return _surface_mesh(parent, name, vertices, faces, position, rotation_degrees, mesh_material)


static func _surface_mesh(
	parent: Node3D,
	name: String,
	vertices: Array[Vector3],
	faces: Array[PackedInt32Array],
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material
) -> MeshInstance3D:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: PackedInt32Array in faces:
		for index: int in range(1, face.size() - 1):
			surface.set_uv(Vector2(0.0, 0.0))
			surface.add_vertex(vertices[face[0]])
			surface.set_uv(Vector2(1.0, 0.0))
			surface.add_vertex(vertices[face[index]])
			surface.set_uv(Vector2(1.0, 1.0))
			surface.add_vertex(vertices[face[index + 1]])
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	return _mesh_instance(parent, name, mesh, position, rotation_degrees, mesh_material)


static func _mesh_instance(
	parent: Node3D,
	name: String,
	mesh: Mesh,
	position: Vector3,
	rotation_degrees: Vector3,
	mesh_material: Material
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	instance.material_override = mesh_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance
