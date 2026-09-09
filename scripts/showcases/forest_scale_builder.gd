@tool
extends RefCounted

## 固定布局的尺度样机。只输出新场景，不覆盖原来的两个美术展示。
const WORLD_PATH: String = "res://scenes/showcases/forest_world_scale.tscn"
const BUILDING_PATH: String = "res://scenes/showcases/substation_expanded.tscn"
const SAWMILL_PATH: String = "res://scenes/showcases/sawmill_multilevel.tscn"
const KIT = preload("res://scripts/showcases/pump_station_builder.gd")
var g: RefCounted
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var plots: Array[Dictionary] = [
	{"name":"基地北门", "p":Vector2(0,94), "size":Vector2(54,26), "h":1.0},
	{"name":"林务机库预留", "p":Vector2(-92,59), "size":Vector2(48,32), "h":2.0},
	{"name":"水库泵站", "p":Vector2(-63,-13), "size":Vector2(42,48), "h":-2.0},
	{"name":"废弃锯木厂", "p":Vector2(5,-71), "size":Vector2(64,38), "h":4.0},
	{"name":"高危堡垒预留", "p":Vector2(90,-74), "size":Vector2(54,44), "h":8.0},
	{"name":"变电站", "p":Vector2(48,17), "size":Vector2(52,54), "h":1.0},
	{"name":"附属建筑预留", "p":Vector2(-13,22), "size":Vector2(20,18), "h":0.0},
]
var routes: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0,81),Vector2(-20,64),Vector2(-46,42),Vector2(-63,14)]),
	PackedVector2Array([Vector2(0,81),Vector2(3,52),Vector2(6,17),Vector2(1,-24),Vector2(5,-52)]),
	PackedVector2Array([Vector2(0,81),Vector2(31,67),Vector2(48,48),Vector2(82,39),Vector2(98,6),Vector2(92,-27),Vector2(90,-52)]),
	PackedVector2Array([Vector2(-68,59),Vector2(-46,42),Vector2(3,52),Vector2(48,48)]),
	PackedVector2Array([Vector2(-63,14),Vector2(-63,20),Vector2(-34,20),Vector2(-30,-3),Vector2(1,-24),Vector2(40,-28),Vector2(92,-27)]),
	PackedVector2Array([Vector2(5,-52),Vector2(43,-46),Vector2(90,-52)]),
]

func build() -> String:
	rng.seed = 9072026
	var building: Node3D = expand_building()
	var building_result: Error = save_owned(building, BUILDING_PATH)
	building.free()
	if building_result != OK:
		return "扩建保存失败：%s" % building_result
	var sawmill: Node3D = build_sawmill()
	var sawmill_result: Error = save_owned(sawmill, SAWMILL_PATH)
	sawmill.free()
	if sawmill_result != OK:
		return "锯木厂保存失败：%s" % sawmill_result
	g = KIT.new()
	g.root = Node3D.new()
	g.root.name = "ForestWorldScale"
	g.root.set_script(load("res://scripts/showcases/forest_scale_review.gd"))
	materials()
	terrain()
	roads()
	plot_markers()
	forest()
	landmarks()
	lighting()
	place_building(BUILDING_PATH, Vector3(42,1,17), "Substation")
	place_building(SAWMILL_PATH, Vector3(5,4,-71), "Sawmill")
	place_building("res://scenes/showcases/pump_station_atmosphere.tscn", Vector3(-63,-2,-13), "PumpStation")
	var camera: Camera3D = Camera3D.new()
	camera.name = "OverviewCamera"
	camera.position = Vector3(155,180,195)
	camera.look_at_from_position(camera.position,Vector3(0,0,-8))
	camera.far = 700.0
	camera.fov = 45.0
	g.root.add_child(camera)
	g.assign_owners(g.root)
	var player: Node3D = load("res://scenes/characters/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0,2.0,79)
	g.root.add_child(player)
	player.owner = g.root
	var packed: PackedScene = PackedScene.new()
	var result: Error = packed.pack(g.root)
	if result == OK:
		result = ResourceSaver.save(packed,WORLD_PATH)
	var meshes: int = g.root.find_children("*","MeshInstance3D",true,false).size()
	g.root.free()
	return "林地尺度场景保存=%s；网格=%d；扩建保存=%s；锯木厂保存=%s" % [result,meshes,building_result,sawmill_result]

func materials() -> void:
	g.concrete = g.weather(Color(.34,.36,.33),Color(.10,.13,.11),0.0)
	g.floor_mat = g.weather(Color(.26,.28,.25),Color(.10,.12,.10),0.0,true)
	g.steel = g.plain(Color(.19,.24,.22),.64)
	g.rust = g.plain(Color(.32,.25,.17),.8)
	g.chalk = g.plain(Color(.65,.61,.43),.86)
	g.dark = g.plain(Color(.12,.15,.13),.9)

func save_owned(root: Node3D, path: String) -> Error:
	for n: Node in root.find_children("*","",true,false):
		n.owner = root
	for n: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if n.mesh == null or n.mesh.get_surface_count() == 0:
			push_error("空网格："+str(n.name))
			return ERR_INVALID_DATA
	var packed: PackedScene = PackedScene.new()
	var result: Error = packed.pack(root)
	return ResourceSaver.save(packed,path) if result == OK else result

func solid(mesh: MeshInstance3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Solid"
	mesh.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = mesh.mesh.get_aabb().size
	collision.shape = shape
	collision.position = mesh.mesh.get_aabb().get_center()
	body.add_child(collision)

func block(label: String, p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = g.box(label,p,size,material)
	solid(mesh)
	return mesh

func ramp(a: Vector3, b: Vector3, width: float) -> void:
	var mesh: MeshInstance3D = g.box("StairSmoothCollision",(a+b)*.5,Vector3(width,.1,a.distance_to(b)),g.concrete)
	mesh.look_at_from_position(mesh.position,b)
	mesh.position -= mesh.basis.y*.05
	solid(mesh)
	mesh.visible = false

func sign_text(text: String, p: Vector3, size: int = 48) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = p
	label.font_size = size
	label.pixel_size = .005
	label.modulate = Color(.84,.83,.69)
	label.outline_modulate = Color(.07,.09,.08)
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.part.add_child(label)

func doorway_x(x: float, z0: float, z1: float, door_z: float, height: float) -> void:
	block("Wall",Vector3(x,height*.5,(z0+door_z-1.1)*.5),Vector3(.3,height,door_z-1.1-z0),g.concrete)
	block("Wall",Vector3(x,height*.5,(door_z+1.1+z1)*.5),Vector3(.3,height,z1-door_z-1.1),g.concrete)
	block("DoorLintel",Vector3(x,(height+2.7)*.5,door_z),Vector3(.3,height-2.7,2.2),g.concrete)

func expand_building() -> Node3D:
	g = KIT.new()
	g.root = load("res://scenes/showcases/substation_atmosphere.tscn").instantiate()
	g.root.scene_file_path = ""
	g.root.name = "SubstationExpanded"
	g.root.set("capture_on_start",false)
	materials()
	# 只改新实例中的东墙，原始美术场景完全保留。
	for n: MeshInstance3D in g.root.get_node("BuildingShell").get_children():
		if str(n.name).begins_with("SideWall") and n.position.x > 0:
			n.free()
	g.group("AnnexShell")
	doorway_x(12.3,-17,17,12,11)
	block("AnnexFloor",Vector3(18.8,-.2,4.5),Vector3(12.4,.4,25),g.floor_mat)
	block("OuterEastWall",Vector3(25,1.75,4.5),Vector3(.3,3.5,25),g.concrete)
	block("OuterNorthWall",Vector3(18.8,1.75,-8),Vector3(12.4,3.5,.3),g.concrete)
	# 南端通往室外的第二出口，构成室内外环线。
	block("SouthWall",Vector3(20.65,1.75,17),Vector3(8.7,3.5,.3),g.concrete)
	block("SouthDoorPier",Vector3(12.8,1.75,17),Vector3(.4,3.5,.3),g.concrete)
	block("SouthDoorLintel",Vector3(14.6,3.1,17),Vector3(3.2,.8,.3),g.concrete)
	for z: float in [0,8]:
		block("RoomPartition",Vector3(20.2,1.75,z),Vector3(9.6,3.5,.25),g.concrete)
	for room: Dictionary in [{"a":-8.0,"b":0.0,"d":-3.5,"title":"03 维护间 / 楼梯  9.6 × 8 m"},{"a":0.0,"b":8.0,"d":4.0,"title":"02 检修工坊  9.6 × 8 m"},{"a":8.0,"b":17.0,"d":12.0,"title":"01 值班档案室  9.6 × 9 m"}]:
		doorway_x(15.4,room.a,room.b,room.d,3.5)
		sign_text(room.title,Vector3(17,2.8,room.d),28)
	# 屋顶板分成四块，留下真实楼梯洞口，避免楼梯撞天花板。
	block("RoofSouth",Vector3(18.8,3.65,8.5),Vector3(12.4,.3,17),g.floor_mat)
	block("RoofWest",Vector3(15.65,3.65,-4),Vector3(6.1,.3,8),g.floor_mat)
	block("RoofEast",Vector3(23.15,3.65,-4),Vector3(3.7,.3,8),g.floor_mat)
	block("RoofLanding",Vector3(20,3.65,-7.5),Vector3(2.6,.3,1),g.floor_mat)
	g.group("AnnexStairs")
	g.stairs(Vector3(20,0,-1.6),Vector3(20,3.8,-7),2.4,24)
	ramp(Vector3(20,0,-1.6),Vector3(20,3.8,-7),2.4)
	g.group("RoofTerrace")
	for edge: Array in [[Vector3(12.8,3.8,17),Vector3(25,3.8,17)],[Vector3(25,3.8,17),Vector3(25,3.8,-8)],[Vector3(25,3.8,-8),Vector3(12.8,3.8,-8)],[Vector3(18.7,3.8,0),Vector3(18.7,3.8,-6.6)],[Vector3(21.3,3.8,0),Vector3(21.3,3.8,-6.6)]]:
		g.rail(edge[0],edge[1])
		var d: Vector3 = edge[1]-edge[0]
		var barrier: MeshInstance3D = block("SafetyCollision",(edge[0]+edge[1])*.5+Vector3.UP*.55,Vector3(.12,1.1,d.length()),g.steel)
		barrier.look_at_from_position(barrier.position,barrier.position+d)
		barrier.visible = false
	sign_text("露天检修平台  标高 +3.8 m",Vector3(20,5,10))
	for p: Vector3 in [Vector3(23,.6,12),Vector3(23,.6,4),Vector3(17,.8,-6)]:
		block("WorkBench",p,Vector3(2.6,1.2,1),g.steel)
	for x: float in [17,19,21]:
		block("ArchiveShelf",Vector3(x,1.2,16),Vector3(1.5,2.4,.55),g.steel)
	for z: float in [-4,4,12]:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.position = Vector3(19,3,z)
		lamp.light_color = Color(.74,.81,.75)
		lamp.light_energy = 1.7
		lamp.omni_range = 9
		g.part.add_child(lamp)
	# 原大房间补主要碰撞，不把细碎装饰变成绊脚石。
	for group_name: String in ["BuildingShell","RearControlGallery","TransformerWest","TransformerEast","SwitchgearBanks"]:
		for mesh: MeshInstance3D in g.root.get_node(group_name).get_children():
			var n: String = str(mesh.name)
			if group_name == "RearControlGallery" and (n.begins_with("Console") or n.begins_with("Meter")):
				mesh.position.z -= .6
			if n.begins_with("GalleryParapet") or n.begins_with("WindowTransom"):
				mesh.free()
				continue
			if n.contains("Floor") or n.contains("Wall") or n.contains("Pier") or n.contains("Header") or n.contains("Apron") or n.begins_with("TransformerTank") or n.begins_with("SwitchgearCabinet") or n.begins_with("Console"):
				solid(mesh)
	g.group("HallWalkability")
	block("GalleryFront",Vector3(1.8,4.3,-10.7),Vector3(19.3,.9,.24),g.concrete)
	ramp(Vector3(-9,0,-2.8),Vector3(-9,3.825,-10.7),2.3)
	for z: float in [-15,-12,-9,-6,-3,0,3,12,15]:
		var grate: MeshInstance3D = block("GrateCollision",Vector3(0,-.015,z),Vector3(2,.04,3),g.steel)
		grate.visible = false
	# 将开口沟保留为视觉凹槽，薄安全格栅保证尺度验收不会困在沟底。
	block("TemporaryTrenchBridge",Vector3(0,-.03,7.5),Vector3(2,.06,6),g.steel)
	return g.root

func height_at(p: Vector2) -> float:
	var h: float = raw_height_at(p)
	var nearest: float = INF
	var road_height: float = h
	for route: PackedVector2Array in routes:
		for i: int in range(route.size()-1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i+1]
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p,a,b)
			var distance: float = p.distance_to(q)
			if distance < nearest:
				nearest = distance
				road_height = lerpf(raw_height_at(a),raw_height_at(b),a.distance_to(q)/a.distance_to(b))
	h = lerpf(road_height,h,smoothstep(3.5,9.0,nearest))
	# 地块外再留 3 m 平接带，避免 2 m 地形采样跨过基座边缘形成绊脚台阶。
	for plot: Dictionary in plots:
		var d: Vector2 = (p-Vector2(plot.p)).abs()-Vector2(plot.size)*.5
		var outside: float = Vector2(maxf(d.x,0),maxf(d.y,0)).length()
		h = lerpf(h,float(plot.h)-.08,1.0-smoothstep(3.0,10.0,outside))
	return h

func raw_height_at(p: Vector2) -> float:
	# 将小地图压缩到可跑尺度后，仍保留清楚的西脊、库盆、东侧断谷和北部台地。
	var h: float = 2.3*sin(p.x*.043)*cos(p.y*.031)+1.8*sin(p.y*.048)
	# 西侧花岗岩山脊：窄而高，避免整张图都是没有性格的缓坡。
	h += 27.0*exp(-pow((p.x+116.0)/15.0,2.0))*(.72+.28*cos(p.y*.045))
	h += 9.0*exp(-pow((p.x+84.0)/34.0,2.0)-pow((p.y+58.0)/52.0,2.0))
	# 干涸水库是一个实际低盆，四周形成可感知的山坳与堤岸。
	var basin: float = exp(-pow((p.x+62.0)/35.0,2.0)-pow((p.y+12.0)/39.0,2.0))
	h -= 12.0*basin
	h += 12.0*exp(-pow((sqrt(pow((p.x+62.0)/43.0,2.0)+pow((p.y+12.0)/47.0,2.0))-1.0)/.22,2.0))
	# 东侧溪沟与北部两级台地，给高危堡垒明确的高处压迫感。
	h -= 10.0*exp(-pow((p.x-105.0-6.0*sin(p.y*.04))/6.5,2.0))
	h += 16.0*exp(-pow((p.x-78.0)/38.0,2.0)-pow((p.y+72.0)/30.0,2.0))
	h += 9.0*exp(-pow((p.x-28.0)/48.0,2.0)-pow((p.y+72.0)/17.0,2.0))
	for plot: Dictionary in plots:
		var d: Vector2 = (p-Vector2(plot.p)).abs()-Vector2(plot.size)*.5
		var outside: float = Vector2(maxf(d.x,0),maxf(d.y,0)).length()
		h = lerpf(h,float(plot.h)-.08,1.0-smoothstep(0,14,outside))
	return h

func build_sawmill() -> Node3D:
	g = KIT.new()
	g.root = Node3D.new()
	g.root.name = "SawmillMultilevel"
	materials()
	g.group("GroundProductionHall")
	block("GroundSlab",Vector3(0,-.2,0),Vector3(30,.4,22),g.floor_mat)
	# 正面装卸口净宽 8 m；其余三面做实墙，形成明确的进出节奏。
	for x: float in [-11,-7,7,11]:
		block("FrontPier",Vector3(x,2,11),Vector3(2.8,4,.5),g.concrete)
	block("FrontHeader",Vector3(0,5.2,11),Vector3(30,1.6,.5),g.concrete)
	block("BackWall",Vector3(0,3,-11),Vector3(30,6,.5),g.concrete)
	for x: float in [-15,15]:
		block("OuterWall",Vector3(x,3,0),Vector3(.5,6,22),g.concrete)
	for x: float in [-13,-5,5,13]:
		block("MillColumn",Vector3(x,4,0),Vector3(.65,8,.65),g.steel)
	for z: float in [-7,0,7]:
		g.beam("OverheadRail",Vector3(-13,7,z),Vector3(13,7,z),.18,.2,g.rust)
		g.tube("HangingChain",Vector3(0,7,z),Vector3(0,3.6,z),.06,g.rust,10)
	block("SawLine",Vector3(0,.65,1),Vector3(4.5,1.3,11),g.steel)
	for z: float in [-3,1,5]:
		g.ring("SawBlade",Vector3(0,1.35,z),1.05,.09,g.chalk,Vector3.FORWARD)
	for x: float in [-9,9]:
		block("TimberStack",Vector3(x,.6,-2),Vector3(3.8,1.2,7),g.rust)
	g.group("MezzanineWalkway")
	# 二层是U形检修廊，中央完全挑空，能从楼上俯视生产线。
	# 楼梯洞口两侧及上下端分别铺板，保留完整净空。
	block("MezzanineWestOuter",Vector3(-13.625,4.1,0),Vector3(2.25,.35,20),g.floor_mat)
	block("MezzanineWestInner",Vector3(-7.375,4.1,0),Vector3(4.25,.35,20),g.floor_mat)
	block("MezzanineWestLanding",Vector3(-11,4.1,-4.5),Vector3(3,.35,11),g.floor_mat)
	block("MezzanineWestFront",Vector3(-11,4.1,9.5),Vector3(3,.35,1),g.floor_mat)
	block("MezzanineEast",Vector3(10,4.1,0),Vector3(9.5,.35,20),g.floor_mat)
	block("MezzanineRear",Vector3(0,4.1,-7.7),Vector3(10.5,.35,4.6),g.floor_mat)
	for edge: Array in [[Vector3(-5.25,4.3,9.8),Vector3(-5.25,4.3,-9.8)],[Vector3(5.25,4.3,9.8),Vector3(5.25,4.3,-9.8)],[Vector3(-5.25,4.3,-5.4),Vector3(5.25,4.3,-5.4)]]:
		g.rail(edge[0],edge[1])
	block("OfficeBox",Vector3(-12,6.15,-5),Vector3(4,3.8,4),g.concrete)
	block("OfficeWindow",Vector3(-9.98,6.35,-5),Vector3(.03,1.3,2.5),g.dark)
	g.group("UpperConveyorDeck")
	block("UpperDeckWest",Vector3(6,8.1,0),Vector3(7,.35,20),g.floor_mat)
	block("UpperDeckEast",Vector3(13.5,8.1,0),Vector3(2,.35,20),g.floor_mat)
	block("UpperDeckLanding",Vector3(11,8.1,4.5),Vector3(3,.35,11),g.floor_mat)
	block("UpperDeckRear",Vector3(11,8.1,-9.5),Vector3(3,.35,1),g.floor_mat)
	block("UpperControlBox",Vector3(6,10.1,-6),Vector3(4,3.7,4),g.concrete)
	for z: float in [-7,-2,3,8]:
		g.tube("BeltRoller",Vector3(-3.5,8.8,z),Vector3(1.5,8.8,z),.18,g.steel,12)
		g.beam("ConveyorFrame",Vector3(-3.5,8.6,z),Vector3(1.5,8.6,z),.14,.14,g.rust)
	g.rail(Vector3(2.5,8.3,9.8),Vector3(14.2,8.3,9.8))
	g.rail(Vector3(2.5,8.3,-9.8),Vector3(14.2,8.3,-9.8))
	g.group("RoofPlatform")
	block("RoofDeckWest",Vector3(-5.5,12.1,0),Vector3(18,.35,20),g.floor_mat)
	block("RoofDeckEast",Vector3(8.5,12.1,0),Vector3(4,.35,20),g.floor_mat)
	block("RoofDeckLanding",Vector3(5,12.1,-4.5),Vector3(3,.35,11),g.floor_mat)
	block("RoofDeckFront",Vector3(5,12.1,9.5),Vector3(3,.35,1),g.floor_mat)
	# 屋顶只覆盖部分厂房，保留东部传送带上方的天空缺口。
	for edge: Array in [[Vector3(-14,12.3,9.8),Vector3(10.5,12.3,9.8)],[Vector3(-14,12.3,-9.8),Vector3(10.5,12.3,-9.8)],[Vector3(-14,12.3,-9.8),Vector3(-14,12.3,9.8)],[Vector3(10.5,12.3,-9.8),Vector3(10.5,12.3,9.8)]]:
		g.rail(edge[0],edge[1])
	block("WaterTank",Vector3(-6,13.7,-4),Vector3(3,3,3),g.steel)
	g.tube("Chimney",Vector3(-10,12.2,4),Vector3(-10,19,4),.5,g.rust,16)
	# 两组相反方向楼梯，形成底层->二层->上层->屋顶的纵深回路。
	g.group("VerticalCirculation")
	g.stairs(Vector3(-11,0,8),Vector3(-11,4.3,1),2.5,24)
	ramp(Vector3(-11,0,8),Vector3(-11,4.3,1),2.5)
	g.stairs(Vector3(11,4.3,-8),Vector3(11,8.3,-1),2.5,22)
	ramp(Vector3(11,4.3,-8),Vector3(11,8.3,-1),2.5)
	g.stairs(Vector3(5,8.3,7),Vector3(5,12.3,1),2.5,22)
	ramp(Vector3(5,8.3,7),Vector3(5,12.3,1),2.5)
	sign_text("废弃锯木厂  三层生产线 + 屋顶平台",Vector3(0,15,12),34)
	g.assign_owners(g.root)
	return g.root

func terrain() -> void:
	g.group("Terrain")
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in range(-113,113,2):
		for x: int in range(-140,140,2):
			var a: Vector3 = Vector3(x,height_at(Vector2(x,z)),z)
			var b: Vector3 = Vector3(x+2,height_at(Vector2(x+2,z)),z)
			var c: Vector3 = Vector3(x,height_at(Vector2(x,z+2)),z+2)
			var d: Vector3 = Vector3(x+2,height_at(Vector2(x+2,z+2)),z+2)
			for v: Vector3 in [a,b,c,b,d,c]:
				st.set_uv(Vector2(v.x,v.z)*.1)
				var tint: float = .5+.5*sin(v.x*.13)*cos(v.z*.11)
				st.set_color(Color(.19,.235,.18).lerp(Color(.31,.30,.245),tint))
				st.add_vertex(v)
	st.generate_normals()
	var material: StandardMaterial3D = g.plain(Color(.60,.64,.55),.96)
	material.vertex_color_use_as_albedo = true
	var terrain_mesh: MeshInstance3D = g.mesh_at("HillsAndDryReservoir",st.commit(),Vector3.ZERO,material)
	terrain_mesh.create_trimesh_collision()
	# 可见边界路障，不用无限地板掩盖地形缺口。
	for x: float in [-141,141]:
		block("Boundary",Vector3(x,10,0),Vector3(1,45,228),g.dark).visible = false
	for z: float in [-114,114]:
		block("Boundary",Vector3(0,10,z),Vector3(284,45,1),g.dark).visible = false

func road_distance(p: Vector2) -> float:
	var best: float = INF
	for route: PackedVector2Array in routes:
		for i: int in range(route.size()-1):
			best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,route[i],route[i+1])))
	return best

func roads() -> void:
	g.group("RoadNetwork")
	var material: Material = g.plain(Color(.31,.30,.26),.93)
	for route: PackedVector2Array in routes:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in range(route.size()-1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i+1]
			var side: Vector2 = (b-a).normalized().orthogonal()*2.5
			var steps: int = ceili(a.distance_to(b))
			for j: int in range(steps):
				var p: Vector2 = a.lerp(b,float(j)/steps)
				var q: Vector2 = a.lerp(b,float(j+1)/steps)
				for v: Vector2 in [p-side,q-side,p+side,q-side,q+side,p+side]:
					st.add_vertex(Vector3(v.x,height_at(v)+.05,v.y))
		st.generate_normals()
		var mesh: MeshInstance3D = g.mesh_at("FiveMeterGravelRoad",st.commit(),Vector3.ZERO,material)
		mesh.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 50 米刻度提供直观的距离参照。
	for z: float in [75,25,-25,-75]:
		var p: Vector2 = Vector2(10,z)
		g.box("DistancePost",Vector3(p.x,height_at(p)+.65,p.y),Vector3(.18,1.3,.18),g.chalk)
		sign_text("距北门纵深 %d m" % int(81-z),Vector3(p.x,height_at(p)+1.8,p.y),32)

func plot_markers() -> void:
	g.group("BuildingPlots")
	for plot: Dictionary in plots:
		var p: Vector2 = plot.p
		var size: Vector2 = plot.size
		var h: float = plot.h
		block("BuildingPad",Vector3(p.x,h-.22,p.y),Vector3(size.x,.3,size.y),g.floor_mat)
		for x: float in [-.5,.5]:
			for z: float in [-.5,.5]:
				g.box("PlotCorner",Vector3(p.x+size.x*x,h+.6,p.y+size.y*z),Vector3(.18,1.2,.18),g.chalk)
		sign_text("%s\n占地预留 %d × %d m" % [plot.name,size.x,size.y],Vector3(p.x,h+3,p.y+size.y*.5+2))

func forest() -> void:
	g.group("ForestBelts")
	var positions: Array[Vector3] = []
	for i: int in range(2100):
		var p: Vector2 = Vector2(rng.randf_range(-137,137),rng.randf_range(-110,110))
		if road_distance(p)<5.4:
			continue
		var excluded: bool = false
		for plot: Dictionary in plots:
			var d: Vector2 = (p-Vector2(plot.p)).abs()-Vector2(plot.size)*.5
			if d.x < 4.5 and d.y < 4.5:
				excluded = true
		if excluded or (p.distance_to(Vector2(-65,-13))<30):
			continue
		positions.append(Vector3(p.x,height_at(p),p.y))
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = .18
	trunk.bottom_radius = .34
	trunk.height = 8
	trunk.radial_segments = 6
	var crown: CylinderMesh = CylinderMesh.new()
	crown.top_radius = 0
	crown.bottom_radius = 2.4
	crown.height = 6
	crown.radial_segments = 7
	for tier: int in range(4):
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if tier == 0:
			mm.mesh = trunk
		else:
			mm.mesh = crown
		mm.instance_count = positions.size()
		for i: int in range(positions.size()):
			var s: float = .8+float(i%11)*.055
			var transform: Transform3D = Transform3D(Basis(Vector3.UP,float(i)*.7).scaled(Vector3(s,s,s)),positions[i]+Vector3.UP*(4.0 if tier==0 else 4.5+tier*1.5)*s)
			mm.set_instance_transform(i,transform)
		var trees: MultiMeshInstance3D = MultiMeshInstance3D.new()
		trees.name = "Trunks" if tier==0 else "CanopyTier%d" % tier
		trees.multimesh = mm
		trees.material_override = g.rust if tier==0 else g.plain(Color(.105+tier*.014,.17+tier*.014,.14+tier*.012),.95)
		g.part.add_child(trees)
	# 树干有碰撞，树冠不堵住穿林路线。
	var trunks: StaticBody3D = StaticBody3D.new()
	trunks.name = "TreeTrunkCollision"
	g.part.add_child(trunks)
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = .28
	shape.height = 7
	for p: Vector3 in positions:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = shape
		cs.position = p+Vector3.UP*3.5
		trunks.add_child(cs)

func landmarks() -> void:
	g.group("CoarseLandmarks")
	# 基地北门与两侧围墙，保持中间出口净宽 8 m。
	for x: float in [-17,17]:
		block("BaseWall",Vector3(x,3,81),Vector3(26,4,.6),g.concrete)
	for x: float in [-5,5]:
		block("GatePost",Vector3(x,4,81),Vector3(1,6,1),g.rust)
	# 未完成建筑仅放边缘轮廓架，不把预留地块填成不可进入的盒子。
	for index: int in [1,4,6]:
		var plot: Dictionary = plots[index]
		var p: Vector2 = plot.p
		var size: Vector2 = Vector2(plot.size)-Vector2(8,8)
		var height: float = 10 if index==4 else 6
		for x: float in [-.5,.5]:
			for z: float in [-.5,.5]:
				block("FutureBuildingColumn",Vector3(p.x+size.x*x,plot.h+height*.5,p.y+size.y*z),Vector3(.6,height,.6),g.concrete)
		for z: float in [-.5,.5]:
			g.box("FutureRoofOutline",Vector3(p.x,plot.h+height,p.y+size.y*z),Vector3(size.x,.25,.3),g.rust)
		if index==4:
			for x: float in [-21,21]:
				block("FortressTower",Vector3(p.x+x,plot.h+8,p.y-17),Vector3(5,16,5),g.concrete)
	# 溪沟浅水只在低处，过路点是宽阔的混凝土桥面。
	for z: int in range(-105,105,5):
		var x: float = 106+5*sin(z*.035)
		var p: Vector2 = Vector2(x,z)
		if road_distance(p)<6:
			continue
		g.box("CreekWater",Vector3(x,height_at(p)+.035,z),Vector3(3,.025,5.2),g.plain(Color(.17,.23,.22),.16))

func place_building(path: String, p: Vector3, label: String) -> void:
	var building: Node3D = load(path).instantiate()
	building.scene_file_path = ""
	building.set_script(null)
	building.name = label
	building.position = p
	for n: Node in building.find_children("*","",true,false):
		if n is Camera3D or n is WorldEnvironment or n is DirectionalLight3D:
			n.free()
	# 泵站原展示未带行走碰撞；新实例增加静态三角网格，不改源文件。
	if label == "PumpStation":
		building.get_node("SpillwayAndDistantSilhouettes").free()
		for n: MeshInstance3D in building.find_children("*","MeshInstance3D",true,false):
			if n.mesh.get_aabb().size.length() > 2.0:
				n.create_trimesh_collision()
	g.root.add_child(building)

func lighting() -> void:
	g.group("OvercastWorld")
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(.28,.35,.38)
	sky_material.sky_horizon_color = Color(.56,.61,.61)
	sky_material.ground_horizon_color = Color(.35,.4,.37)
	sky_material.ground_bottom_color = Color(.14,.17,.15)
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.63,.71,.72)
	env.ambient_light_energy = .55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(.46,.54,.54)
	env.fog_density = .0018
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = env
	g.part.add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_color = Color(.81,.87,.88)
	sun.light_energy = .8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 130
	g.part.add_child(sun)
