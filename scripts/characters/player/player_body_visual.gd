class_name PlayerBodyVisual
extends Node3D

const BODY_RENDER_LAYER: int = 2

var motion_root: Node3D
var hips: Node3D
var spine: Node3D
var head: Node3D
var left_shoulder: Node3D
var left_elbow: Node3D
var right_shoulder: Node3D
var right_elbow: Node3D
var left_hip: Node3D
var left_knee: Node3D
var right_hip: Node3D
var right_knee: Node3D

var _phase: float = 0.0
var _motion_root_base: Transform3D
var _spine_base: Transform3D
var _left_shoulder_base: Transform3D
var _right_shoulder_base: Transform3D
var _left_hip_base: Transform3D
var _right_hip_base: Transform3D

var _coat: StandardMaterial3D
var _coat_dark: StandardMaterial3D
var _cloth: StandardMaterial3D
var _leather: StandardMaterial3D
var _armor: StandardMaterial3D
var _rubber: StandardMaterial3D
var _skin: StandardMaterial3D
var _accent: StandardMaterial3D
var _glass: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_model()
	_capture_base_pose()


func update_locomotion(horizontal_speed: float, sprinting: bool, delta: float) -> void:
	if motion_root == null:
		return
	var movement_amount: float = clampf(horizontal_speed / 4.5, 0.0, 1.0)
	var cadence: float = 9.0 if sprinting else 6.2
	_phase += delta * cadence * maxf(0.25, movement_amount)
	var stride: float = sin(_phase) * movement_amount
	var stride_degrees: float = stride * (46.0 if sprinting else 30.0)
	var arm_degrees: float = stride * (34.0 if sprinting else 22.0)
	var weight: float = clampf(delta * 12.0, 0.0, 1.0)

	left_hip.rotation.x = lerpf(left_hip.rotation.x, _left_hip_base.basis.get_euler().x + deg_to_rad(stride_degrees), weight)
	right_hip.rotation.x = lerpf(right_hip.rotation.x, _right_hip_base.basis.get_euler().x - deg_to_rad(stride_degrees), weight)
	left_shoulder.rotation.x = lerpf(left_shoulder.rotation.x, _left_shoulder_base.basis.get_euler().x - deg_to_rad(arm_degrees), weight)
	right_shoulder.rotation.x = lerpf(right_shoulder.rotation.x, _right_shoulder_base.basis.get_euler().x + deg_to_rad(arm_degrees), weight)

	var breathing: float = sin(_phase * 0.45) * 0.012
	var step_bob: float = absf(sin(_phase)) * movement_amount * 0.025
	motion_root.position = _motion_root_base.origin + Vector3(0.0, breathing + step_bob, 0.0)
	var lean_degrees: float = -7.0 if sprinting and movement_amount > 0.1 else 0.0
	spine.rotation.x = lerpf(spine.rotation.x, _spine_base.basis.get_euler().x + deg_to_rad(lean_degrees), weight)


func get_mesh_count() -> int:
	return _count_meshes(self)


func _build_materials() -> void:
	_coat = _material("DeserterCoat", Color(0.18, 0.24, 0.22), 0.0, 0.92)
	_coat_dark = _material("WetCoatDark", Color(0.07, 0.10, 0.105), 0.0, 0.96)
	_cloth = _material("UniformCloth", Color(0.26, 0.30, 0.27), 0.0, 0.88)
	_leather = _material("WornLeather", Color(0.19, 0.115, 0.07), 0.0, 0.84)
	_armor = _material("ScrapArmor", Color(0.29, 0.32, 0.31), 0.62, 0.63)
	_rubber = _material("BlackRubber", Color(0.025, 0.032, 0.035), 0.0, 0.78)
	_skin = _material("WeatheredSkin", Color(0.40, 0.27, 0.22), 0.0, 0.9)
	_accent = _material("WarningCloth", Color(0.72, 0.49, 0.10), 0.0, 0.8)
	_glass = _material("RainGlass", Color(0.10, 0.48, 0.55), 0.32, 0.22, Color(0.05, 0.34, 0.42), 0.55)


func _build_model() -> void:
	motion_root = _pivot(self, "MotionRoot", Vector3.ZERO)
	hips = _pivot(motion_root, "Hips", Vector3(0.0, -0.10, 0.0))
	_build_torso()
	_build_head()
	_build_arm(true)
	_build_arm(false)
	_build_leg(true)
	_build_leg(false)


func _build_torso() -> void:
	_tapered_box(hips, "Pelvis", Vector2(0.28, 0.18), Vector2(0.24, 0.16), 0.28, Vector3(0.0, 0.08, 0.0), Vector3.ZERO, _cloth)
	_box(hips, "Belt", Vector3(0.58, 0.10, 0.35), Vector3(0.0, 0.19, 0.0), Vector3.ZERO, _leather)
	_box(hips, "BeltBuckle", Vector3(0.12, 0.10, 0.05), Vector3(0.0, 0.19, -0.205), Vector3.ZERO, _accent)
	_box(hips, "LeftUtilityPouch", Vector3(0.17, 0.20, 0.13), Vector3(-0.33, 0.08, 0.0), Vector3(0.0, 0.0, 5.0), _leather)
	_box(hips, "RightUtilityPouch", Vector3(0.17, 0.20, 0.13), Vector3(0.33, 0.08, 0.0), Vector3(0.0, 0.0, -5.0), _leather)

	spine = _pivot(hips, "Spine", Vector3(0.0, 0.22, 0.0))
	_tapered_box(spine, "CoatTorso", Vector2(0.40, 0.21), Vector2(0.29, 0.18), 0.66, Vector3(0.0, 0.34, 0.0), Vector3.ZERO, _coat)
	_tapered_box(spine, "ShoulderCape", Vector2(0.49, 0.24), Vector2(0.38, 0.20), 0.22, Vector3(0.0, 0.61, 0.04), Vector3.ZERO, _coat_dark)
	_box(spine, "ChestArmor", Vector3(0.54, 0.36, 0.09), Vector3(0.0, 0.39, -0.225), Vector3(-3.0, 0.0, 0.0), _armor)
	_box(spine, "LeftHarness", Vector3(0.07, 0.57, 0.055), Vector3(-0.21, 0.38, -0.285), Vector3(0.0, 0.0, -13.0), _leather)
	_box(spine, "RightHarness", Vector3(0.07, 0.57, 0.055), Vector3(0.21, 0.38, -0.285), Vector3(0.0, 0.0, 13.0), _leather)
	_box(spine, "DeserterMark", Vector3(0.08, 0.25, 0.025), Vector3(-0.14, 0.40, -0.287), Vector3(0.0, 0.0, -8.0), _accent)
	_box(spine, "Backpack", Vector3(0.50, 0.57, 0.20), Vector3(0.0, 0.37, 0.25), Vector3(2.0, 0.0, 0.0), _coat_dark)
	_box(spine, "Bedroll", Vector3(0.55, 0.16, 0.17), Vector3(0.0, 0.69, 0.27), Vector3(0.0, 0.0, 0.0), _cloth)
	_cylinder(spine, "LeftCanister", 0.07, 0.08, 0.34, Vector3(-0.35, 0.28, 0.25), Vector3.ZERO, _armor, 12)
	_tapered_box(hips, "LeftCoatTail", Vector2(0.20, 0.10), Vector2(0.24, 0.13), 0.66, Vector3(-0.17, -0.35, 0.10), Vector3(0.0, 0.0, 4.0), _coat)
	_tapered_box(hips, "RightCoatTail", Vector2(0.20, 0.10), Vector2(0.23, 0.13), 0.58, Vector3(0.17, -0.31, 0.10), Vector3(0.0, 0.0, -5.0), _coat)


func _build_head() -> void:
	head = _pivot(spine, "Head", Vector3(0.0, 0.84, 0.0))
	_sphere(head, "Hood", 0.27, 0.51, Vector3(0.0, 0.0, 0.025), Vector3.ZERO, _coat_dark, 20)
	_sphere(head, "Face", 0.19, 0.34, Vector3(0.0, -0.025, -0.07), Vector3.ZERO, _skin, 18)
	_box(head, "Respirator", Vector3(0.30, 0.17, 0.13), Vector3(0.0, -0.09, -0.225), Vector3(7.0, 0.0, 0.0), _rubber)
	_box(head, "RespiratorVent", Vector3(0.16, 0.065, 0.035), Vector3(0.0, -0.11, -0.31), Vector3.ZERO, _armor)
	_sphere(head, "LeftGoggle", 0.065, 0.095, Vector3(-0.095, 0.055, -0.245), Vector3.ZERO, _glass, 12)
	_sphere(head, "RightGoggle", 0.065, 0.095, Vector3(0.095, 0.055, -0.245), Vector3.ZERO, _glass, 12)
	_cylinder(head, "LeftFilter", 0.055, 0.065, 0.11, Vector3(-0.17, -0.10, -0.21), Vector3(90.0, 0.0, 0.0), _armor, 12)
	_cylinder(head, "RightFilter", 0.055, 0.065, 0.11, Vector3(0.17, -0.10, -0.21), Vector3(90.0, 0.0, 0.0), _armor, 12)
	_box(head, "HoodPeak", Vector3(0.38, 0.07, 0.22), Vector3(0.0, 0.24, -0.08), Vector3(-8.0, 0.0, 0.0), _coat)


func _build_arm(left: bool) -> void:
	var side: float = -1.0 if left else 1.0
	var prefix: String = "Left" if left else "Right"
	var shoulder: Node3D = _pivot(spine, prefix + "Shoulder", Vector3(side * 0.47, 0.60, 0.0))
	if left:
		left_shoulder = shoulder
	else:
		right_shoulder = shoulder
	_sphere(shoulder, prefix + "Pauldron", 0.17, 0.23, Vector3.ZERO, Vector3(0.0, 0.0, side * 7.0), _armor, 14)
	_capsule(shoulder, prefix + "UpperArm", 0.115, 0.40, Vector3(0.0, -0.21, 0.0), Vector3.ZERO, _coat, 14)
	_box(shoulder, prefix + "UpperPlate", Vector3(0.17, 0.22, 0.085), Vector3(0.0, -0.17, -0.105), Vector3(2.0, 0.0, 0.0), _armor)
	var elbow: Node3D = _pivot(shoulder, prefix + "Elbow", Vector3(0.0, -0.39, 0.0))
	if left:
		left_elbow = elbow
	else:
		right_elbow = elbow
	_capsule(elbow, prefix + "Forearm", 0.10, 0.36, Vector3(0.0, -0.18, 0.0), Vector3.ZERO, _coat_dark, 14)
	_box(elbow, prefix + "Bracer", Vector3(0.16, 0.22, 0.11), Vector3(0.0, -0.18, -0.08), Vector3(-3.0, 0.0, 0.0), _armor)
	_sphere(elbow, prefix + "Glove", 0.105, 0.17, Vector3(0.0, -0.38, -0.01), Vector3.ZERO, _rubber, 12)


func _build_leg(left: bool) -> void:
	var side: float = -1.0 if left else 1.0
	var prefix: String = "Left" if left else "Right"
	var hip: Node3D = _pivot(hips, prefix + "Hip", Vector3(side * 0.19, -0.09, 0.0))
	if left:
		left_hip = hip
	else:
		right_hip = hip
	_capsule(hip, prefix + "Thigh", 0.145, 0.50, Vector3(0.0, -0.26, 0.0), Vector3.ZERO, _cloth, 16)
	_box(hip, prefix + "ThighPlate", Vector3(0.20, 0.28, 0.10), Vector3(0.0, -0.22, -0.13), Vector3(2.0, 0.0, 0.0), _armor)
	var knee: Node3D = _pivot(hip, prefix + "Knee", Vector3(0.0, -0.49, 0.0))
	if left:
		left_knee = knee
	else:
		right_knee = knee
	_box(knee, prefix + "KneePad", Vector3(0.21, 0.16, 0.11), Vector3(0.0, -0.02, -0.13), Vector3.ZERO, _armor)
	_capsule(knee, prefix + "Shin", 0.115, 0.46, Vector3(0.0, -0.24, 0.0), Vector3.ZERO, _coat_dark, 14)
	_box(knee, prefix + "Boot", Vector3(0.25, 0.20, 0.42), Vector3(0.0, -0.50, -0.09), Vector3.ZERO, _rubber)
	_box(knee, prefix + "BootCap", Vector3(0.24, 0.10, 0.18), Vector3(0.0, -0.48, -0.25), Vector3.ZERO, _armor)


func _capture_base_pose() -> void:
	_motion_root_base = motion_root.transform
	_spine_base = spine.transform
	_left_shoulder_base = left_shoulder.transform
	_right_shoulder_base = right_shoulder.transform
	_left_hip_base = left_hip.transform
	_right_hip_base = right_hip.transform


func _material(name_value: String, color: Color, metallic: float, roughness: float, emission: Color = Color.TRANSPARENT, emission_energy: float = 0.0) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.resource_name = name_value
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission
		result.emission_energy_multiplier = emission_energy
	return result


func _pivot(parent: Node3D, node_name: String, local_position: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = node_name
	pivot.position = local_position
	parent.add_child(pivot)
	return pivot


func _box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, rotation_degrees_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, mesh, local_position, rotation_degrees_value, material)


func _capsule(parent: Node3D, node_name: String, radius: float, height: float, local_position: Vector3, rotation_degrees_value: Vector3, material: Material, segments: int) -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = segments
	mesh.rings = 6
	return _mesh(parent, node_name, mesh, local_position, rotation_degrees_value, material)


func _sphere(parent: Node3D, node_name: String, radius: float, height: float, local_position: Vector3, rotation_degrees_value: Vector3, material: Material, segments: int) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 10
	return _mesh(parent, node_name, mesh, local_position, rotation_degrees_value, material)


func _cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, local_position: Vector3, rotation_degrees_value: Vector3, material: Material, segments: int) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	return _mesh(parent, node_name, mesh, local_position, rotation_degrees_value, material)


func _tapered_box(parent: Node3D, node_name: String, top_half_size: Vector2, bottom_half_size: Vector2, height: float, local_position: Vector3, rotation_degrees_value: Vector3, material: Material) -> MeshInstance3D:
	var y_top: float = height * 0.5
	var y_bottom: float = -height * 0.5
	var vertices: Array[Vector3] = [
		Vector3(-top_half_size.x, y_top, -top_half_size.y), Vector3(top_half_size.x, y_top, -top_half_size.y),
		Vector3(top_half_size.x, y_top, top_half_size.y), Vector3(-top_half_size.x, y_top, top_half_size.y),
		Vector3(-bottom_half_size.x, y_bottom, -bottom_half_size.y), Vector3(bottom_half_size.x, y_bottom, -bottom_half_size.y),
		Vector3(bottom_half_size.x, y_bottom, bottom_half_size.y), Vector3(-bottom_half_size.x, y_bottom, bottom_half_size.y),
	]
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([7, 6, 5, 4]),
		PackedInt32Array([0, 4, 5, 1]), PackedInt32Array([1, 5, 6, 2]),
		PackedInt32Array([2, 6, 7, 3]), PackedInt32Array([3, 7, 4, 0]),
	]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: PackedInt32Array in faces:
		for index: int in range(1, face.size() - 1):
			surface.add_vertex(vertices[face[0]])
			surface.add_vertex(vertices[face[index]])
			surface.add_vertex(vertices[face[index + 1]])
	surface.generate_normals()
	var array_mesh: ArrayMesh = surface.commit()
	return _mesh(parent, node_name, array_mesh, local_position, rotation_degrees_value, material)


func _mesh(parent: Node3D, node_name: String, mesh_value: Mesh, local_position: Vector3, rotation_degrees_value: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh_value
	instance.position = local_position
	instance.rotation_degrees = rotation_degrees_value
	instance.material_override = material
	instance.layers = BODY_RENDER_LAYER
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _count_meshes(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_meshes(child)
	return count
