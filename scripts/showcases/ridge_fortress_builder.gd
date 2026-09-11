@tool
extends RefCounted
## 独立建筑源场景与展示容器分别保存；不写入大世界。
const KIT = preload("res://scripts/showcases/pump_station_builder.gd")
const ASSET: String = "res://scenes/showcases/ridge_fortress.tscn"
const SHOWCASE: String = "res://scenes/showcases/ridge_fortress_showcase.tscn"
var g: RefCounted
var stone: Material
var concrete: Material
var metal: Material
var asphalt: Material
var window: Material
var warm: Material
var road: PackedVector3Array = PackedVector3Array([Vector3(0,0,94),Vector3(0,8,62),Vector3(0,8,57),Vector3(0,8,42),Vector3(-38,8,42),Vector3(-52,11,32),Vector3(-53,15,15),Vector3(-44,21,-1),Vector3(-32,21,-8),Vector3(0,21,-8)])
var upper_road: PackedVector3Array = PackedVector3Array([Vector3(-32,21,-8),Vector3(-46,23,-19),Vector3(-51,27,-35),Vector3(-45,31,-48),Vector3(-36,35,-35),Vector3(-28,35,-35),Vector3(0,35,-35)])

func build() -> String:
	g = KIT.new()
	g.rng.seed = 9082601
	g.root = Node3D.new()
	g.root.name = "RidgeFortress"
	concrete = g.weather(Color(.31,.335,.32),Color(.035,.048,.04),0.0)
	stone = g.plain(Color(.19,.215,.19),.96)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 90826
	noise.frequency = .035
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0,Color(.3,.34,.32))
	gradient.set_color(1,Color(.9,.88,.8))
	texture.color_ramp = gradient
	stone.albedo_texture = texture
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3.ONE*.13
	metal = g.plain(Color(.12,.15,.14),.6)
	asphalt = g.plain(Color(.115,.135,.13),.82)
	window = g.plain(Color(.055,.09,.095),.24)
	warm = g.plain(Color(.48,.39,.22),.45)
	warm.emission_enabled = true
	warm.emission = Color(.65,.43,.19)
	warm.emission_energy_multiplier = .8
	g.steel = metal
	g.rust = g.plain(Color(.25,.16,.10),.75)
	g.concrete = concrete
	g.floor_mat = concrete
	g.dark = window
	g.chalk = warm
	terrain()
	g.group("RetainedTerraces")
	terrace(Vector3(0,8,46),Vector2(72,25),8)
	terrace(Vector3(0,21,-2),Vector2(70,43),16)
	terrace(Vector3(0,35,-48),Vector2(68,40),18)
	g.group("WestSwitchbackRoad")
	road_mesh(road,6.5)
	road_mesh(upper_road,6.5)
	g.group("LowerGatehouse")
	for x: float in [-10,10]:
		building(Vector3(x,8,49),Vector2(11,10),2,false)
		box("GateTowerCrown",Vector3(x,16.5,49),Vector3(12,.6,11),concrete)
	box("GateBridge",Vector3(0,14.6,49),Vector3(9,2.2,9),concrete)
	box("GateSoffit",Vector3(0,13.4,49),Vector3(9,.25,10),metal)
	for x: float in [-4.3,4.3]:
		box("RecessedGateTrack",Vector3(x,10.5,49),Vector3(.18,5,8),metal,false)
	label("北岭管制区",Vector3(0,15,54.05),60)
	lamp(Vector3(0,12.8,52))
	g.group("MidBarracksAndWorkshops")
	building(Vector3(-20,21,-2),Vector2(14,28),2,true)
	building(Vector3(20,21,-2),Vector2(14,28),2,true)
	g.group("SummitCommand")
	building(Vector3(-3,35,-51),Vector2(42,18),4,true)
	building(Vector3(23,35,-53),Vector2(9,11),6,false)
	box("ObservationCab",Vector3(23,60,-53),Vector3(12,3.5,13),window)
	box("ObservationRoof",Vector3(23,62,-53),Vector3(13,.5,14),concrete)
	for x: float in [17.2,20,23,26,28.8]:
		box("ObservationMullion",Vector3(x,60,-46.45),Vector3(.14,3.5,.12),metal,false)
	g.tube("RadioMast",Vector3(23,62.3,-53),Vector3(23,71,-53),.12,metal)
	for y: float in [65,67,69]:
		g.tube("Antenna",Vector3(21,y,-53),Vector3(25,y,-53),.045,metal)
	g.group("EastServiceStair")
	box("LowerStairLanding",Vector3(37,7.8,44),Vector3(8,.4,5),concrete)
	stair(Vector3(39,8,43),Vector3(39,21,22),2.8)
	box("MidStairLanding",Vector3(37,20.8,19),Vector3(7,.4,6),concrete)
	box("EastWalkway",Vector3(38,20.8,-2),Vector3(4,.4,38),concrete)
	stair(Vector3(38,21,-19),Vector3(38,35,-45),2.8)
	box("UpperStairLanding",Vector3(35.5,34.8,-49),Vector3(8,.4,8),concrete)
	g.group("YardDressing")
	for p: Vector3 in [Vector3(-29,21,11),Vector3(28,21,10),Vector3(-28,35,-31),Vector3(18,35,-31)]:
		box("CargoCase",p+Vector3(0,.6,0),Vector3(2.8,1.2,1.5),metal)
		for x: float in [-1,1]:
			box("CargoStrap",p+Vector3(x,.65,0),Vector3(.1,1.35,1.55),g.rust,false)
	for z: float in [-17,-7,3,13]:
		box("YardMarking",Vector3(0,21.015,z),Vector3(.12,.015,3),warm,false)
	for p: Vector3 in [Vector3(-30,8,54),Vector3(30,8,54),Vector3(-31,21,14),Vector3(31,21,14),Vector3(-30,35,-32),Vector3(30,35,-32)]:
		g.tube("YardLightPost",p,p+Vector3.UP*6,.09,metal)
		lamp(p+Vector3.UP*6)
	vegetation()
	var result: Error = save(g.root,ASSET)
	g.root.free()
	if result != OK:
		return "堡垒保存失败 %s" % result
	g.root = Node3D.new()
	g.root.name = "RidgeFortressShowcase"
	var asset: Node = ResourceLoader.load(ASSET,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	g.root.add_child(asset)
	asset.owner = g.root
	var lighting_kit: RefCounted = load("res://scripts/showcases/forest_scale_builder.gd").new()
	lighting_kit.g = g
	lighting_kit.lighting()
	var environment: Environment = g.root.find_children("*","WorldEnvironment",true,false)[0].environment
	environment.fog_density = .0008
	environment.ambient_light_energy = .38
	environment.fog_light_color = Color(.27,.32,.34)
	var sky_mat: ProceduralSkyMaterial = environment.sky.sky_material
	sky_mat.sky_top_color = Color(.09,.13,.18)
	sky_mat.sky_horizon_color = Color(.31,.36,.39)
	var camera: Camera3D = Camera3D.new()
	camera.name = "ReferenceCamera"
	camera.position = Vector3(52,7,108)
	camera.look_at_from_position(camera.position,Vector3(0,30,-12))
	camera.far = 700
	camera.fov = 58
	camera.current = true
	g.root.add_child(camera)
	g.root.set_script(load("res://scripts/showcases/ridge_fortress_viewer.gd"))
	for child: Node in g.root.get_children():
		child.owner = g.root
		if child != asset:
			for n: Node in child.find_children("*","",true,false):
				n.owner = g.root
	var packed: PackedScene = PackedScene.new()
	result = packed.pack(g.root)
	if result == OK:
		result = ResourceSaver.save(packed,SHOWCASE)
	g.root.free()
	return "堡垒实体与独立展示已保存 result=%s" % result

func save(root: Node3D, path: String) -> Error:
	g.assign_owners(root)
	for m: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if m.mesh == null or m.mesh.get_surface_count() == 0:
			return ERR_INVALID_DATA
	var packed: PackedScene = PackedScene.new()
	var result: Error = packed.pack(root)
	return ResourceSaver.save(packed,path) if result == OK else result

func box(n: String, p: Vector3, size: Vector3, mat: Material, collision: bool = true) -> MeshInstance3D:
	var m: MeshInstance3D = g.box(n,p,size,mat)
	if collision:
		m.create_trimesh_collision()
	return m

func terrace(p: Vector3, size: Vector2, depth: float) -> void:
	box("TerraceFoundation",p-Vector3.UP*(depth*.5+.08),Vector3(size.x,depth,size.y),concrete)
	for x: float in range(int(-size.x*.5),int(size.x*.5),4):
		box("RetainingButtress",p+Vector3(x,-depth*.5,size.y*.5+.15),Vector3(.45,depth,1),concrete)
		for y: float in range(2,int(depth),3):
			box("FormworkJoint",p+Vector3(x,-y,size.y*.5+.66),Vector3(3.9,.035,.025),metal,false)
	for x: float in [-size.x*.5,size.x*.5]:
		g.rail(p+Vector3(x,0,-size.y*.5),p+Vector3(x,0,size.y*.5))

func building(p: Vector3, size: Vector2, floors: int, enterable: bool) -> void:
	var height: float = floors*3.8
	box("BuildingRear",p+Vector3(0,height*.5,-size.y*.5),Vector3(size.x,height,.45),concrete)
	for x: float in [-size.x*.5,size.x*.5]:
		box("BuildingSide",p+Vector3(x,height*.5,0),Vector3(.45,height,size.y),concrete)
	if enterable:
		for side: float in [-1,1]:
			box("EntryFacade",p+Vector3(side*(size.x*.25+1),height*.5,size.y*.5),Vector3(size.x*.5-2,height,.45),concrete)
		box("EntryHeader",p+Vector3(0,(height+3)*.5,size.y*.5),Vector3(4,height-3,.45),concrete)
	else:
		box("FrontFacade",p+Vector3(0,height*.5,size.y*.5),Vector3(size.x,height,.45),concrete)
	box("InteriorFloor",p-Vector3.UP*.1,Vector3(size.x,.2,size.y),concrete)
	box("RoofCap",p+Vector3.UP*(height+.1),Vector3(size.x+.8,.4,size.y+.8),concrete)
	box("RoofMembrane",p+Vector3.UP*(height+.32),Vector3(size.x-.3,.04,size.y-.3),asphalt,false)
	for z: float in [-size.y*.5,size.y*.5]:
		box("RoofParapet",p+Vector3(0,height+.65,z),Vector3(size.x,.7,.2),metal)
	for x: float in [-size.x*.5,size.x*.5]:
		box("RoofParapet",p+Vector3(x,height+.65,0),Vector3(.2,.7,size.y),metal)
		for z: int in range(int(-size.y*.5+2),int(size.y*.5-1),3):
			for level: int in range(floors):
				box("SideWindow",p+Vector3(x+signf(x)*.24,level*3.8+2,z),Vector3(.06,1.4,2.1),window,false)
	for level: int in range(floors):
		var y: float = level*3.8+2.1
		for x: int in range(int(-size.x*.5+2),int(size.x*.5-1),3):
			if level == 0 and abs(x)<3 and enterable:
				continue
			box("WindowRecess",p+Vector3(x,y,size.y*.5+.24),Vector3(2.3,1.5,.08),window,false)
			box("WindowSill",p+Vector3(x,y-.8,size.y*.5+.4),Vector3(2.55,.12,.45),metal,false)
			box("WindowMullion",p+Vector3(x,y,size.y*.5+.3),Vector3(.07,1.5,.08),metal,false)
			if (x+level)%5 == 0:
				box("OccupiedWindow",p+Vector3(x+.55,y,size.y*.5+.29),Vector3(.9,1.25,.04),warm,false)
		box("FacadeBand",p+Vector3(0,level*3.8+.25,size.y*.5+.25),Vector3(size.x,.17,.3),metal,false)
	for x: float in [-size.x*.5+.5,size.x*.5-.5]:
		g.tube("RainDownpipe",p+Vector3(x,.3,size.y*.5+.4),p+Vector3(x,height,size.y*.5+.4),.075,g.rust)
	for x: float in [-size.x*.25,size.x*.25]:
		box("RoofVent",p+Vector3(x,height+.7,0),Vector3(2.3,1.2,2),metal)
		for y: float in [.3,.55,.8]:
			box("VentLouvre",p+Vector3(x,height+y,1.03),Vector3(2.1,.07,.1),window,false)
	if enterable:
		lamp(p+Vector3(0,2.9,size.y*.5-1))
		for x: float in [-size.x*.25,size.x*.25]:
			box("InteriorEquipment",p+Vector3(x,.6,-size.y*.25),Vector3(3,1.2,1.3),metal)

func lamp(p: Vector3) -> void:
	box("LampHousing",p,Vector3(.8,.22,.45),metal,false)
	box("LampLens",p-Vector3.UP*.13,Vector3(.65,.05,.32),warm,false)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = p-Vector3.UP*.3
	light.light_color = Color(.95,.69,.38)
	light.light_energy = 1.8
	light.omni_range = 9
	g.part.add_child(light)

func label(value: String, p: Vector3, font_size: int) -> void:
	var node: Label3D = Label3D.new()
	node.text = value
	node.position = p
	node.font_size = font_size
	node.pixel_size = .025
	node.modulate = Color(.73,.72,.61)
	g.part.add_child(node)

func road_mesh(points: PackedVector3Array, width: float) -> void:
	for i: int in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var side: Vector3 = Vector3(b.z-a.z,0,a.x-b.x).normalized()*width*.5
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v: Vector3 in [a-side,a+side,b-side,b-side,a+side,b+side]:
			st.add_vertex(v)
		st.generate_normals()
		var m: MeshInstance3D = g.mesh_at("RoadSurface",st.commit(),Vector3.ZERO,asphalt)
		m.create_trimesh_collision()
		for sign_side: float in [-1,1]:
			g.rail(a+side*sign_side,b+side*sign_side)

func stair(a: Vector3, b: Vector3, width: float) -> void:
	var steps: int = ceili((b.y-a.y)/.18)
	var thickness: float = .24
	for i: int in range(steps):
		var t: float = float(i+1)/steps
		var p: Vector3 = a.lerp(b,t)
		box("SteelStairTread",p-Vector3.UP*(thickness*.5),Vector3(width,thickness,absf(b.z-a.z)/steps+.04),metal)
	for x: float in [-width*.5,width*.5]:
		g.beam("StairStringer",a+Vector3(x,-.12,0),b+Vector3(x,-.12,0),.12,.22,metal)
		var rail_a: Vector3 = a+Vector3(x,1,0)
		var rail_b: Vector3 = b+Vector3(x,1,0)
		g.tube("Handrail",rail_a,rail_b,.036,g.rust,12)
		for j: int in range(6):
			var post: Vector3 = a.lerp(b,float(j)/5.0)+Vector3(x,0,0)
			g.tube("StairBaluster",post,post+Vector3.UP,.027,g.rust,10)
	road_mesh(PackedVector3Array([a+Vector3.UP*.03,b+Vector3.UP*.03]),width)

func terrain_height(p: Vector2) -> float:
	var z: float = p.y
	var h: float = 37.0*smoothstep(67,-59,z)
	h *= 1.0-smoothstep(40,82,absf(p.x))
	h *= 1.0-smoothstep(68,104,-z)
	h += sin(p.x*.23)*cos(z*.17)*1.3
	var nearest: float = INF
	var road_h: float = h
	for route: PackedVector3Array in [road,upper_road]:
		for i: int in range(route.size()-1):
			var a: Vector2 = Vector2(route[i].x,route[i].z)
			var b: Vector2 = Vector2(route[i+1].x,route[i+1].z)
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p,a,b)
			var d: float = p.distance_to(q)
			if d < nearest:
				nearest = d
				road_h = lerpf(route[i].y,route[i+1].y,a.distance_to(q)/a.distance_to(b))-.6
	h = lerpf(road_h,h,smoothstep(5,10,nearest))
	if p.x > 35 and p.x < 42:
		if z >= 22 and z <= 44:
			h = minf(h,lerpf(8,21,clampf((43-z)/21,0,1))-.5)
		elif z > -19 and z < 22:
			h = minf(h,20.5)
		elif z >= -45 and z <= -19:
			h = minf(h,lerpf(21,35,(-19-z)/26)-.5)
		elif z > -54 and z < -45:
			h = minf(h,34.5)
	# 台地内山体低于建筑底板，防止土坡穿过室内。
	for t: Vector3 in [Vector3(8,46,25),Vector3(21,-2,43),Vector3(35,-48,40)]:
		if absf(p.x)<35 and absf(z-t.y)<t.z*.5:
			h = minf(h,t.x-.2)
	return h

func terrain() -> void:
	g.group("RockyHillside")
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in range(-110,140,2):
		for x: int in range(-110,110,2):
			for p: Vector2 in [Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]:
				st.add_vertex(Vector3(p.x,terrain_height(p),p.y))
	st.generate_normals()
	var m: MeshInstance3D = g.mesh_at("Mountain",st.commit(),Vector3.ZERO,stone)
	m.create_trimesh_collision()
	# 岩壁体块只布置在东侧陡坡，避免侵入道路或建筑。
	for i: int in range(95):
		var x: float = g.rng.randf_range(45,73)
		var z: float = g.rng.randf_range(-71,43)
		var rock: SphereMesh = SphereMesh.new()
		rock.radius = g.rng.randf_range(2,4)
		rock.height = g.rng.randf_range(5,10)
		rock.radial_segments = 6
		rock.rings = 3
		var node: MeshInstance3D = g.mesh_at("ExposedRock",rock,Vector3(x,terrain_height(Vector2(x,z)),z),stone)
		node.rotation = Vector3(g.rng.randf_range(-.3,.3),g.rng.randf_range(-3,3),g.rng.randf_range(-.25,.25))

func vegetation() -> void:
	g.group("SlopeForest")
	for i: int in range(140):
		var x: float = g.rng.randf_range(65,105)*(1 if i%2==0 else -1)
		var z: float = g.rng.randf_range(-95,105)
		var p: Vector3 = Vector3(x,terrain_height(Vector2(x,z)),z)
		g.tube("FirTrunk",p,p+Vector3.UP*11,.18,g.rust,6)
		for tier: int in range(4):
			var mesh: CylinderMesh = CylinderMesh.new()
			mesh.top_radius = 0
			mesh.bottom_radius = 3.1-tier*.5
			mesh.height = 5
			mesh.radial_segments = 9
			g.mesh_at("FirCrown",mesh,p+Vector3.UP*(5+tier*2),metal)
