@tool
extends RefCounted
## 确定性离线场景生成器。通过 19080 的 execute_editor_script 调用 build()，
## 生成独立 PackedScene；运行时无需生成器，不引用旧灰盒或正式玩家。
const DESTINATION: String = "res://scenes/showcases/pump_station_atmosphere.tscn"
var root: Node3D
var part: Node3D
var rng := RandomNumberGenerator.new()
var concrete: Material
var steel: Material
var rust: Material
var floor_mat: Material
var dark: Material
var glass: Material
var chalk: Material

func build(destination: String = DESTINATION) -> String:
	rng.seed = 9062601
	root = Node3D.new()
	root.name = "PumpStationAtmosphere"
	root.set_script(load("res://scripts/showcases/pump_station_viewer.gd"))
	root.set("capture_on_start", true)
	concrete = weather(Color(0.36,0.375,0.355), Color(0.058,0.073,0.059), 0.0)
	steel = weather(Color(0.14,0.155,0.145), Color(0.052,0.040,0.028), 0.72)
	rust = weather(Color(0.32,0.24,0.14), Color(0.08,0.057,0.037), 0.55)
	floor_mat = weather(Color(0.27,0.285,0.265), Color(0.074,0.08,0.067), 0.0, true)
	dark = plain(Color(0.022,0.027,0.024), 0.85)
	chalk = plain(Color(0.36,0.35,0.29), 0.85)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22,0.27,0.27,0.32)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.roughness = 0.38
	gm.metallic = 0.0
	gm.metallic_specular = 0.2
	glass = gm
	architecture()
	control_room()
	pit()
	roof()
	group("MainPumpingMachinery")
	pump(Vector3(0.4,0,-1.5),1.0)
	turn_pump(Vector3(0.4,0,-1.5),-0.38)
	group("MezzaninePumpingMachinery")
	pump(Vector3(-10.0,0,-2.0),0.64)
	turn_pump(Vector3(-10.0,0,-2.0),0.5)
	group("RearPumpingMachinery")
	pump(Vector3(5.5,0,-12.5),0.73)
	pipework()
	dressing()
	decay_details()
	exterior()
	lighting()
	var camera := Camera3D.new()
	camera.name = "ReferenceCamera"
	camera.position = Vector3(4.2,2.7,17.2)
	camera.basis = Basis.looking_at(Vector3(-1.3,1.9,-5.0)-camera.position)
	camera.fov = 64.0
	camera.near = 0.08
	camera.far = 180.0
	camera.current = true
	root.add_child(camera)
	assign_owners(root)
	# 网格生成异常时拒绝覆盖场景，避免保存只有节点、没有面片的地板。
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or node.mesh.get_surface_count() == 0:
			var failure: String = "场景未保存：空网格 %s" % root.get_path_to(node)
			root.free()
			return failure
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/showcases"))
	var packed := PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, destination)
	var result: String = "scene=%s result=%s nodes=%d" % [destination,error,root.find_children("*","",true,false).size()]
	root.free()
	return result

func assign_owners(node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		assign_owners(child)

func weather(color: Color, stain: Color, metallic: float, is_floor: bool=false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/showcases/pump_weathered.gdshader")
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("stain_color",stain)
	mat.set_shader_parameter("metal",metallic)
	mat.set_shader_parameter("floor_surface",1.0 if is_floor else 0.0)
	mat.set_shader_parameter("concrete_scan",load("res://assets/textures/showcases/pump_station/weathered_concrete.png"))
	return mat

func plain(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func group(label: String) -> void:
	part = Node3D.new()
	part.name = label
	root.add_child(part)

func mesh_at(label: String, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	part.add_child(node)
	return node

func box(label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: Mesh
	if minf(size.x,minf(size.y,size.z)) > 0.32:
		mesh = chamfered_box(size,0.025)
	else:
		var primitive := BoxMesh.new()
		primitive.size = size
		mesh = primitive
	return mesh_at(label,mesh,pos,mat)

func chamfered_box(size: Vector3, bevel: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector3 = size*0.5
	var core: Vector3 = half-Vector3.ONE*bevel
	for axis: int in range(3):
		var a: int = (axis+1)%3
		var b: int = (axis+2)%3
		for sign_axis: float in [-1,1]:
			var corners: Array[Vector3] = []
			for signs: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var v := Vector3.ZERO
				v[axis] = half[axis]*sign_axis
				v[a] = core[a]*signs.x
				v[b] = core[b]*signs.y
				corners.append(v)
			emit_face(st,corners)
		for sa: float in [-1,1]:
			for sb: float in [-1,1]:
				var corners: Array[Vector3] = []
				for pair: Vector2 in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var v := Vector3.ZERO
					v[axis] = core[axis]*pair.x
					v[a] = (half[a]-bevel*pair.y)*sa
					v[b] = (core[b]+bevel*pair.y)*sb
					corners.append(v)
				emit_face(st,corners)
	for x: float in [-1,1]:
		for y: float in [-1,1]:
			for z: float in [-1,1]:
				var c: Vector3 = core*Vector3(x,y,z)
				emit_face(st,[c+Vector3(x*bevel,0,0),c+Vector3(0,y*bevel,0),c+Vector3(0,0,z*bevel)])
	return st.commit()

func emit_face(st: SurfaceTool, points: Array[Vector3]) -> void:
	var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
	var reverse_winding: bool = normal.dot(points[0]) > 0
	if not reverse_winding:
		normal = -normal
	for i: int in range(1,points.size()-1):
		# 条件表达式会产生无类型 Array；逐项写入保留 Vector3 数组类型。
		var triangle: Array[Vector3] = [points[0]]
		triangle.append(points[i+1] if reverse_winding else points[i])
		triangle.append(points[i] if reverse_winding else points[i+1])
		for point: Vector3 in triangle:
			st.set_normal(normal)
			st.add_vertex(point)

func tube(label: String, a: Vector3, b: Vector3, radius: float, mat: Material, sides: int=20) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = sides
	mesh.rings = 1
	var node: MeshInstance3D = mesh_at(label,mesh,(a+b)*0.5,mat)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return node

func beam(label: String, a: Vector3, b: Vector3, width: float, depth: float, mat: Material) -> void:
	if a.distance_squared_to(b) < 0.000001:
		return
	var node: MeshInstance3D = box(label,(a+b)*0.5,Vector3(width,a.distance_to(b),depth),mat)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func ring(label: String, pos: Vector3, radius: float, thickness: float, mat: Material, axis: Vector3=Vector3.FORWARD) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-thickness
	mesh.outer_radius = radius+thickness
	mesh.rings = 48
	mesh.ring_segments = 10
	var node: MeshInstance3D = mesh_at(label,mesh,pos,mat)
	node.quaternion = Quaternion(Vector3.UP,axis)

func architecture() -> void:
	group("ConcreteShell")
	# True pit opening x[-7,1], z[7,14]. Floor surfaces end at y=0.
	box("FloorWest",Vector3(-10,-0.3,0),Vector3(6,0.6,38),floor_mat)
	box("FloorEast",Vector3(7,-0.3,0),Vector3(12,0.6,38),floor_mat)
	box("FloorRear",Vector3(-3,-0.3,-6),Vector3(8,0.6,26),floor_mat)
	box("ThresholdFloor",Vector3(-3,-0.3,16.5),Vector3(8,0.6,5),floor_mat)
	box("WestWall",Vector3(-13,6,0),Vector3(0.65,12,38),concrete)
	box("EastWall",Vector3(13,6,0),Vector3(0.65,12,38),concrete)
	box("RearWest",Vector3(-5.5,6,-19),Vector3(15,12,0.65),concrete)
	box("RearEast",Vector3(10.3,6,-19),Vector3(5.4,12,0.65),concrete)
	box("RearLintel",Vector3(4.8,9.0,-19),Vector3(5.6,6,0.65),concrete)
	box("EntranceLeftPier",Vector3(-10,6,18.7),Vector3(6,12,0.7),concrete)
	box("EntranceRightPier",Vector3(11.2,6,18.7),Vector3(3.6,12,0.7),concrete)
	box("EntranceLintel",Vector3(1.2,10.8,18.7),Vector3(16.4,2.4,0.7),concrete)
	for z: float in [-15.0,-8.0,-1.0,6.0,13.0]:
		for x: float in [-12.4,8.5]:
			box("ConcreteColumn",Vector3(x,5.9,z),Vector3(0.88,11.8,0.95),concrete)
			box("ColumnFoot",Vector3(x,0.23,z),Vector3(1.12,0.46,1.22),concrete)
		for y: float in [2.8,6.0,9.2]:
			box("FormworkJoint",Vector3(-12.66,y,z),Vector3(0.024,0.028,6.9),dark)
	for x: float in [-10.0,-6.0,-2.0,9.0,12.0]:
		box("RearWallSeam",Vector3(x,6,-18.66),Vector3(0.027,12,0.018),dark)
	for y: float in [2.8,6.0,9.2]:
		box("RearConstructionJoint",Vector3(-5.5,y,-18.65),Vector3(14.8,0.036,0.02),dark)
	# Close-set right corridor frame, with two portals rather than a solid wall.
	box("ServiceSill",Vector3(9.65,0.24,-3),Vector3(0.45,0.48,21),concrete)
	box("ServiceHeader",Vector3(9.65,7.9,0),Vector3(0.6,0.5,36),steel)

func control_room() -> void:
	group("ControlRoomMezzanine")
	box("MezzanineSlab",Vector3(-9.65,3.45,1.8),Vector3(6.0,0.5,19.6),concrete)
	box("WindowSillWall",Vector3(-6.65,4.12,2.8),Vector3(0.36,0.84,17.6),concrete)
	box("WindowHeader",Vector3(-6.65,6.7,1.8),Vector3(0.36,1.0,19.6),concrete)
	box("ControlCeiling",Vector3(-9.6,7.08,1.8),Vector3(6.1,0.26,19.6),concrete)
	box("UpperControlFace",Vector3(-6.65,9.5,1.8),Vector3(0.4,5.0,19.6),concrete)
	box("ControlEndWall",Vector3(-9.6,5.4,-8.0),Vector3(6.1,3.4,0.3),concrete)
	for z: float in [-7.8,-5.85,-3.9,-1.95,0,1.95,3.9,5.85,7.8,9.75,11.55]:
		box("WindowMullion",Vector3(-6.43,5.42,z),Vector3(0.075,1.78,0.075),rust)
		if z < 10 and z > -6:
			glass_shards(z)
	for y: float in [4.55,5.43,6.3]:
		box("WindowTransom",Vector3(-6.42,y,1.8),Vector3(0.08,0.065,19.6),rust)
	for z: float in [-6,0,6,11]:
		box("MezzanineSupport",Vector3(-6.9,1.62,z),Vector3(0.5,3.24,0.55),concrete)
	for z: float in [-5,-1,3,7]:
		box("ControlDesk",Vector3(-8.0,4.18,z),Vector3(1.0,0.94,2.3),steel)
		box("DeadInstrumentPanel",Vector3(-8.0,4.77,z),Vector3(0.8,0.16,1.9),dark)
		for j: int in range(5):
			box("Indicator",Vector3(-7.9,4.87,z-0.7+j*0.32),Vector3(0.13,0.015,0.12),chalk)
	stairs(Vector3(-5.0,0,-13.4),Vector3(-5.0,3.7,-6.8),2.6,22)
	box("ControlLanding",Vector3(-6.4,3.56,-7.0),Vector3(3.8,0.28,2.0),steel)
	# Leave side wall opening at the stair landing.
	box("LowerElectricalCabinet",Vector3(-11.8,1.1,6.0),Vector3(1.1,2.2,2.3),steel)
	box("CabinetDoorInset",Vector3(-11.23,1.2,6.0),Vector3(0.03,1.6,1.95),dark)

func glass_shards(z: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outside: Array[Vector3] = []
	var inside: Array[Vector3] = []
	var center := Vector3(-6.4,5.43,z+0.95)
	for i: int in range(20):
		var angle: float = TAU*i/20.0
		var direction := Vector3(0,sin(angle),cos(angle))
		var extent: float = minf(0.82/maxf(absf(direction.y),0.001),0.87/maxf(absf(direction.z),0.001))
		outside.append(center+direction*extent)
		inside.append(center+direction*extent*rng.randf_range(0.50,0.94))
	for i: int in range(20):
		var next: int = (i+1)%20
		for v: Vector3 in [outside[i],outside[next],inside[next],outside[i],inside[next],inside[i]]:
			st.set_normal(Vector3.RIGHT)
			st.add_vertex(v)
	mesh_at("BrokenGlass",st.commit(),Vector3.ZERO,glass)

func stairs(start: Vector3, end: Vector3, width: float, steps: int) -> void:
	for i: int in range(steps):
		var t: float = float(i+1)/steps
		var p: Vector3 = start.lerp(end,t)
		box("SteelStairTread",p-Vector3(0,0.065,0),Vector3(width,0.13,absf(end.z-start.z)/steps+0.04),steel)
	for x: float in [-width*0.5,width*0.5]:
		beam("StairStringer",start+Vector3(x,-0.12,0),end+Vector3(x,-0.12,0),0.12,0.22,steel)
		var a: Vector3 = start+Vector3(x,1.0,0)
		var b: Vector3 = end+Vector3(x,1.0,0)
		tube("Handrail",a,b,0.036,rust,12)
		for j: int in range(6):
			var p: Vector3 = start.lerp(end,float(j)/5.0)+Vector3(x,0,0)
			tube("StairBaluster",p,p+Vector3.UP,0.027,rust,10)

func rail(a: Vector3, b: Vector3) -> void:
	for h: float in [0.5,1.02]:
		tube("GuardRail",a+Vector3.UP*h,b+Vector3.UP*h,0.034,rust,12)
	var count: int = maxi(2,int(a.distance_to(b)/1.45))
	for i: int in range(count+1):
		var p: Vector3 = a.lerp(b,float(i)/count)
		tube("GuardPost",p,p+Vector3.UP*1.06,0.039,rust,12)
		box("RailShoe",p+Vector3(0,0.025,0),Vector3(0.18,0.05,0.18),steel)

func pit() -> void:
	group("SunkenInspectionPit")
	box("PitFloor",Vector3(-3,-3.5,10.5),Vector3(8,0.5,7),floor_mat)
	box("PitWestWall",Vector3(-7.15,-1.6,10.5),Vector3(0.3,3.2,7),concrete)
	box("PitEastWall",Vector3(1.15,-1.6,10.5),Vector3(0.3,3.2,7),concrete)
	box("PitNorthWall",Vector3(-3,-1.6,6.85),Vector3(8,3.2,0.3),concrete)
	box("PitSouthWall",Vector3(-3,-1.6,14.15),Vector3(8,3.2,0.3),concrete)
	rail(Vector3(-7,0,7),Vector3(1,0,7))
	rail(Vector3(-7,0,7),Vector3(-7,0,14))
	rail(Vector3(1,0,7),Vector3(1,0,14))
	rail(Vector3(-7,0,14),Vector3(-2.3,0,14))
	stairs(Vector3(-0.55,0,14),Vector3(-0.55,-3.23,8.0),2.05,19)
	for y: float in [-2.6,-1.8]:
		tube("PitServicePipe",Vector3(-6.6,y,7.2),Vector3(-6.6,y,13.7),0.13,rust)

func roof() -> void:
	group("DamagedRoofAndTrusses")
	for z: float in [-17,-11,-5,1,7,13,18]:
		beam("BottomChord",Vector3(-12.8,10.3,z),Vector3(12.8,10.3,z),0.16,0.19,steel)
		beam("RoofChordWest",Vector3(-12.8,10.3,z),Vector3(0,13.3,z),0.20,0.23,steel)
		beam("RoofChordEast",Vector3(0,13.3,z),Vector3(12.8,10.3,z),0.20,0.23,steel)
		for i: int in range(8):
			var x: float = -12.8+i*3.2
			var xa: float = x+3.2
			var y: float = 13.3-absf(xa)*3.0/12.8
			beam("TrussDiagonal",Vector3(x,10.3,z),Vector3(xa,y,z),0.075,0.09,steel)
			beam("TrussVertical",Vector3(xa,10.3,z),Vector3(xa,y,z),0.07,0.08,steel)
	for x: float in [-12,-9,-6,-3,0,3,6,9,12]:
		var y: float = 13.3-absf(x)*3.0/12.8
		beam("LongitudinalPurlin",Vector3(x,y,-19),Vector3(x,y,19),0.11,0.12,steel)
		for z: float in [-16,-10,-4,2,8,14]:
			if rng.randf() < 0.37:
				continue
			var panel: MeshInstance3D = box("SurvivingRoofSheet",Vector3(x,y+0.12,z),Vector3(2.85,0.07,5.55),steel)
			panel.rotation.z = atan(3.0/12.8)*(1.0 if x < 0 else -1.0)
	# Wall-top bridge-crane rails.
	for x: float in [-11.5,8.8]:
		box("CraneRunway",Vector3(x,8.8,0),Vector3(0.22,0.45,37),rust)
	box("OverheadGantry",Vector3(-1.35,8.95,-7),Vector3(20.3,0.45,0.65),rust)
	tube("HangingCable",Vector3(0,8.8,-7),Vector3(0,6.8,-7),0.018,steel,8)
	ring("CraneHook",Vector3(0,6.6,-7),0.20,0.055,rust)

func pump(origin: Vector3, s: float) -> void:
	box("PumpPlinth",origin+Vector3(0,0.22,0),Vector3(3.7,0.44,4.8)*s,concrete)
	var c: Vector3 = origin+Vector3(0,1.85,0)*s
	tube("CastIronPumpCasing",c+Vector3(0,0,-0.8)*s,c+Vector3(0,0,0.55)*s,1.46*s,steel,64)
	tube("FrontCover",c+Vector3(0,0,0.54)*s,c+Vector3(0,0,0.72)*s,1.25*s,steel,64)
	for r: float in [1.42,1.23,0.91,0.53]:
		ring("CastCasingRib",c+Vector3(0,0,0.73)*s,r*s,0.065*s,rust)
	tube("ShaftBearing",c+Vector3(0,0,0.72)*s,c+Vector3(0,0,1.18)*s,0.45*s,steel,40)
	tube("DriveShaft",c+Vector3(0,0,1.14)*s,c+Vector3(0,0,1.72)*s,0.16*s,rust,24)
	for i: int in range(16):
		var angle: float = TAU*i/16.0
		var bolt: Vector3 = c+Vector3(cos(angle)*1.33,sin(angle)*1.33,0.79)*s
		tube("CasingHexBolt",bolt,bolt+Vector3(0,0,0.12)*s,0.075*s,rust,6)
	for x: float in [-1.1,1.1]:
		box("CastFoot",origin+Vector3(x,0.69,0)*s,Vector3(0.38,0.95,1.8)*s,steel)
		for z: float in [-0.75,0.75]:
			tube("AnchorBolt",origin+Vector3(x,0.44,z)*s,origin+Vector3(x,0.60,z)*s,0.07*s,rust,6)
	tube("MotorHousing",c+Vector3(0,0,-1.15)*s,c+Vector3(0,0,-2.15)*s,0.84*s,steel,48)
	for i: int in range(16):
		var a: float = TAU*i/16
		beam("MotorCoolingFin",c+Vector3(cos(a)*0.86,sin(a)*0.86,-1.13)*s,c+Vector3(cos(a)*0.86,sin(a)*0.86,-2.1)*s,0.035*s,0.055*s,steel)
	var points: Array[Vector3] = [Vector3(1.13,1.5,0),Vector3(2.43,1.5,0),Vector3(2.43,4.3,0),Vector3(-0.5,4.3,0),Vector3(-0.5,3.1,0)]
	var rounded: Array[Vector3] = [origin+points[0]*s]
	for i: int in range(1,points.size()-1):
		var p: Vector3 = points[i]
		var a: Vector3 = p+(points[i-1]-p).normalized()*0.48
		var b: Vector3 = p+(points[i+1]-p).normalized()*0.48
		for step: int in range(9):
			var t: float = step/8.0
			rounded.append(origin+(a*(1.0-t)*(1.0-t)+p*2.0*t*(1.0-t)+b*t*t)*s)
	rounded.append(origin+points[-1]*s)
	smooth_pipe("RoundedCastOutlet",rounded,0.23*s,steel)
	for y: float in [2.0,3.55]:
		ring("OutletFlange",origin+Vector3(2.43,y,0)*s,0.31*s,0.055*s,rust,Vector3.UP)
	tube("GaugeStem",origin+Vector3(0.9,2.8,0.8)*s,origin+Vector3(0.9,3.35,0.8)*s,0.035*s,rust)
	tube("Gauge",origin+Vector3(0.9,3.35,0.8)*s,origin+Vector3(0.9,3.35,0.92)*s,0.16*s,steel)
	tube("GaugeFace",origin+Vector3(0.9,3.35,0.923)*s,origin+Vector3(0.9,3.35,0.927)*s,0.125*s,chalk)
	for i: int in range(9):
		var angle: float = -0.5+float(i)*0.5
		var v := Vector3(cos(angle),sin(angle),0)
		tube("GaugeTick",origin+(Vector3(0.9,3.35,0.932)+v*0.095)*s,origin+(Vector3(0.9,3.35,0.932)+v*0.115)*s,0.003*s,dark,5)
	tube("GaugeNeedle",origin+Vector3(0.9,3.35,0.94)*s,origin+Vector3(0.96,3.41,0.94)*s,0.006*s,dark,6)

func turn_pump(origin: Vector3, angle: float) -> void:
	var rotation_basis := Basis(Vector3.UP,angle)
	for node: Node3D in part.get_children():
		node.position = origin+rotation_basis*(node.position-origin)
		node.basis = rotation_basis*node.basis

func pipework() -> void:
	group("RightServicePipeGallery")
	for data: Vector3 in [Vector3(11.8,7.9,0.38),Vector3(12.35,6.6,0.21),Vector3(12.25,5.8,0.16),Vector3(12.2,1.3,0.25)]:
		tube("LongServicePipe",Vector3(data.x,data.y,-18),Vector3(data.x,data.y,18),data.z,steel,32)
		for z: float in [-16,-12,-8,-4,0,4,8,12,16]:
			ring("PipeFlange",Vector3(data.x,data.y,z),data.z*1.3,0.038,rust)
			beam("PipeBracket",Vector3(12.8,data.y-0.25,z),Vector3(11.4,data.y-0.25,z),0.065,0.075,steel)
	for z: float in [-13,-4,5,13]:
		tube("DownPipe",Vector3(11.75,0.3,z),Vector3(11.75,7.9,z),0.09,rust)
		ring("ValveWheel",Vector3(11.48,1.9,z),0.29,0.035,rust,Vector3.RIGHT)
		for i: int in range(4):
			var a: float = i*PI/2.0
			tube("ValveSpoke",Vector3(11.48,1.9,z),Vector3(11.48,1.9+cos(a)*0.27,z+sin(a)*0.27),0.015,rust,8)
	group("WestConduits")
	for x: float in [-12.45,-12.2,-11.95]:
		tube("EntryVerticalConduit",Vector3(x,0,14.0),Vector3(x,10.8,14.0),0.06,steel)
	for y: float in [7.8,8.1]:
		tube("WallConduit",Vector3(-12.55,y,-18),Vector3(-12.55,y,18),0.038,rust,12)

func dressing() -> void:
	group("ToolsAndAbandonedFurniture")
	box("ToolChest",Vector3(3.1,0.33,6.0),Vector3(1.18,0.66,0.78),steel)
	box("ToolChestLid",Vector3(3.1,0.69,6.0),Vector3(1.24,0.09,0.84),rust)
	for x: float in [2.7,3.5]:
		box("ChestLatch",Vector3(x,0.47,6.40),Vector3(0.1,0.18,0.035),chalk)
	for y: float in [0.25,0.87]:
		box("TrolleyShelf",Vector3(4.25,y,3.4),Vector3(1.3,0.09,0.75),steel)
	for x: float in [3.63,4.87]:
		for z: float in [3.08,3.72]:
			tube("TrolleyLeg",Vector3(x,0.13,z),Vector3(x,1.15,z),0.025,rust,10)
			ring("Castor",Vector3(x,0.12,z),0.09,0.035,steel,Vector3.RIGHT)
	box("TrolleyMotor",Vector3(4.15,1.05,3.4),Vector3(0.45,0.28,0.45),steel)
	for z: float in [-13.5,-15.0]:
		tube("OilDrum",Vector3(7.7,0,z),Vector3(7.7,1.0,z),0.38,rust)
		for y: float in [0.06,0.3,0.7,0.97]:
			ring("DrumHoop",Vector3(7.7,y,z),0.39,0.025,steel,Vector3.UP)
	box("BenchSeat",Vector3(-10.5,0.53,10),Vector3(2.5,0.11,0.5),rust)
	for x: float in [-11.5,-9.5]:
		box("BenchLeg",Vector3(x,0.25,10),Vector3(0.08,0.5,0.4),steel)
	# Deterministic multimesh debris, shared geometry and material.
	group("FloorFragments")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var shard := SphereMesh.new()
	shard.radius = 0.5
	shard.height = 1.0
	shard.radial_segments = 5
	shard.rings = 2
	mm.mesh = shard
	mm.instance_count = 800
	for i: int in range(800):
		var x: float = rng.randf_range(-12.2,12.2)
		var z: float = rng.randf_range(-18,18)
		var y: float = -3.18 if x>-7 and x<1 and z>7 and z<14 else 0.02
		var size: Vector3 = Vector3(rng.randf_range(0.035,0.22),rng.randf_range(0.015,0.08),rng.randf_range(0.04,0.26))
		var basis: Basis = Basis(Vector3.UP,rng.randf()*TAU).scaled(size)
		mm.set_instance_transform(i,Transform3D(basis,Vector3(x,y,z)))
		mm.set_instance_color(i,Color(0.4,0.4,0.36)*rng.randf_range(0.4,1.0))
	var debris := MultiMeshInstance3D.new()
	debris.name = "ConcreteFragments800"
	debris.multimesh = mm
	var debris_mat := StandardMaterial3D.new()
	debris_mat.vertex_color_use_as_albedo = true
	debris_mat.roughness = 0.93
	debris.material_override = debris_mat
	part.add_child(debris)

func smooth_pipe(label: String, points: Array[Vector3], radius: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 24
	for i: int in range(points.size()-1):
		for side: int in range(sides):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
				var index: int = i+corner.x
				var tangent: Vector3 = (points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]).normalized()
				var cross_axis: Vector3 = tangent.cross(Vector3.FORWARD).normalized()
				var angle: float = TAU*(side+corner.y)/sides
				var normal: Vector3 = cross_axis*cos(angle)+Vector3.FORWARD*sin(angle)
				st.set_normal(normal)
				st.add_vertex(points[index]+normal*radius)
	mesh_at(label,st.commit(),Vector3.ZERO,mat)

func decay_details() -> void:
	group("FracturesAndNeglect")
	var cracks := SurfaceTool.new()
	cracks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(110):
		var p := Vector3(rng.randf_range(-12,12),0.012,rng.randf_range(-18,18))
		if p.x>-7 and p.x<1 and p.z>7 and p.z<14:
			continue
		var angle: float = rng.randf()*TAU
		for segment: int in range(rng.randi_range(4,12)):
			angle += rng.randf_range(-0.75,0.75)
			var q: Vector3 = p+Vector3(cos(angle),0,sin(angle))*rng.randf_range(0.12,0.5)
			var width: Vector3 = Vector3(-sin(angle),0,cos(angle))*rng.randf_range(0.003,0.014)
			for v: Vector3 in [p-width,p+width,q+width,p-width,q+width,q-width]:
				cracks.set_normal(Vector3.UP)
				cracks.add_vertex(v)
			p = q
	mesh_at("BranchingFloorCracks",cracks.commit(),Vector3.ZERO,dark)
	# Roof skin remnants hang in irregular strips from the exposed steel frame.
	for i: int in range(38):
		var pos := Vector3(rng.randf_range(-5.8,10),rng.randf_range(10.4,12.2),rng.randf_range(-18,15))
		var skin := SurfaceTool.new()
		skin.begin(Mesh.PRIMITIVE_TRIANGLES)
		var width: float = rng.randf_range(0.1,0.8)
		var length: float = rng.randf_range(0.25,1.6)
		for v: Vector3 in [Vector3.ZERO,Vector3(width,0,0.12),Vector3(width*0.7,-length,0.6)]:
			skin.set_normal(Vector3.FORWARD)
			skin.add_vertex(v)
		mesh_at("TornRoofRemnant",skin.commit(),pos,steel)
	# Thin vines and moss around damp joints, assembled into a single instanced draw.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var leaf := SphereMesh.new()
	leaf.radius = 1
	leaf.height = 2
	leaf.radial_segments = 6
	leaf.rings = 3
	mm.mesh = leaf
	mm.instance_count = 1400
	for i: int in range(1400):
		var z: float = rng.randf_range(-17.8,17.8)
		var edge: float = [-7.1,1.16,8.5,12.5][i%4] if z>7 and z<14 else [-12.4,12.5][i%2]
		var x: float = edge+rng.randf_range(-0.35,0.35)
		var s := Vector3(rng.randf_range(0.018,0.055),rng.randf_range(0.005,0.035),rng.randf_range(0.02,0.07))
		mm.set_instance_transform(i,Transform3D(Basis().scaled(s),Vector3(x,0.018,z)))
		mm.set_instance_color(i,Color(0.08,0.105,0.042)*rng.randf_range(0.45,1.15))
	var moss := MultiMeshInstance3D.new()
	moss.name = "DampJointMoss1400"
	moss.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.93
	moss.material_override = mat
	part.add_child(moss)
	# Corroded side braces, wall conduits and a dangling cable at the control room.
	for z: float in [-6,-2,2,6,10]:
		beam("MezzanineCorbel",Vector3(-6.94,2.35,z),Vector3(-5.95,3.4,z),0.16,0.23,concrete)
	var cable: Array[Vector3] = []
	for i: int in range(21):
		var t: float = i/20.0
		cable.append(Vector3(-6.2,7.2-sin(t*PI)*1.5,-6.0+t*15.0))
	# Cable is in the YZ plane, use thin individual segments.
	for i: int in range(cable.size()-1):
		tube("SaggingCable",cable[i],cable[i+1],0.016,dark,8)

func exterior() -> void:
	group("SpillwayAndDistantSilhouettes")
	box("ExteriorApron",Vector3(0,-0.36,-27),Vector3(38,0.6,18),floor_mat)
	for x: float in [-1,9]:
		box("SpillwayWall",Vector3(x,0.5,-29),Vector3(0.8,1.0,18),concrete)
	for i: int in range(22):
		var x: float = rng.randf_range(-25,26)
		var z: float = rng.randf_range(-58,-39)
		var h: float = rng.randf_range(5,13)
		tube("DistantTreeTrunk",Vector3(x,-0.4,z),Vector3(x,h,z),0.13,steel,8)
		for j: int in range(7):
			var mesh := SphereMesh.new()
			mesh.radius = rng.randf_range(0.9,1.6)
			mesh.height = mesh.radius*1.6
			mesh.radial_segments = 9
			mesh.rings = 5
			mesh_at("DistantFoliage",mesh,Vector3(x+rng.randf_range(-1.2,1.2),h*0.65+rng.randf_range(-1,2),z+rng.randf_range(-1,1)),dark)
	for i: int in range(16):
		var rock := SphereMesh.new()
		rock.radius = rng.randf_range(2.0,4.5)
		rock.height = rock.radius*rng.randf_range(1.7,2.7)
		rock.radial_segments = 9
		rock.rings = 5
		var boulder: MeshInstance3D = mesh_at("SpillwayRockFace",rock,Vector3(rng.randf_range(-5,4),rng.randf_range(0,3),rng.randf_range(-38,-30)),concrete)
		boulder.rotation = Vector3(rng.randf(),rng.randf(),rng.randf())

func lighting() -> void:
	group("OvercastLighting")
	var world := WorldEnvironment.new()
	world.name = "PumpStationEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.70,0.74,0.76)
	sky_mat.sky_horizon_color = Color(0.77,0.79,0.80)
	sky_mat.ground_bottom_color = Color(0.035,0.045,0.04)
	sky_mat.ground_horizon_color = Color(0.25,0.29,0.3)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46,0.52,0.55)
	env.ambient_light_energy = 0.17
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.2
	env.ssil_enabled = true
	env.ssil_intensity = 1.0
	env.ssr_enabled = true
	env.ssr_max_steps = 128
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.6,0.66,0.68)
	env.volumetric_fog_length = 80
	env.volumetric_fog_ambient_inject = 0.3
	world.environment = env
	part.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "RoofDaylight"
	sun.rotation_degrees = Vector3(-58,-28,0)
	sun.light_color = Color(0.79,0.87,0.94)
	sun.light_energy = 0.32
	sun.light_specular = 0.15
	sun.light_angular_distance = 8.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	part.add_child(sun)
	for z: float in [-11,0,10]:
		var light := OmniLight3D.new()
		light.name = "SkylightBounce"
		light.position = Vector3(1.5,9.3,z)
		light.light_color = Color(0.74,0.83,0.88)
		light.light_energy = 2.4
		light.omni_range = 19.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = true
		light.light_size = 2.0
		light.light_specular = 0.0
		part.add_child(light)
	var doorway := SpotLight3D.new()
	doorway.name = "RearDoorSky"
	doorway.position = Vector3(5,5.0,-20)
	doorway.rotation_degrees = Vector3(-12,180,0)
	doorway.light_energy = 5.0
	doorway.light_specular = 0.0
	doorway.light_color = Color(0.7,0.79,0.86)
	doorway.spot_range = 35
	doorway.spot_angle = 65
	doorway.shadow_enabled = true
	part.add_child(doorway)
	var pump_fill := OmniLight3D.new()
	pump_fill.name = "SoftPumpBounce"
	pump_fill.position = Vector3(-1,5,4)
	pump_fill.light_color = Color(0.75,0.79,0.8)
	pump_fill.light_energy = 3.0
	pump_fill.omni_range = 14
	pump_fill.light_specular = 0.0
	pump_fill.light_size = 1.5
	pump_fill.shadow_enabled = true
	part.add_child(pump_fill)
	var probe := ReflectionProbe.new()
	probe.name = "HallReflection"
	probe.position = Vector3(0,4,0)
	probe.size = Vector3(27,18,40)
	# 破顶厂房必须保留天空；interior=true 会把屋顶洞口的反射变黑。
	probe.interior = false
	probe.intensity = 1.0
	probe.box_projection = true
	probe.max_distance = 65
	part.add_child(probe)
