@tool
extends "res://scripts/showcases/forest_scale_builder.gd"
## 原东北占位改造；原地图保留为回退，覆盖的是此前错误整合副本。
const DESTINATION: String = "res://scenes/showcases/forest_world_fortress.tscn"
const ORIGIN: Vector3 = Vector3(100,0,-85)
var original: RefCounted
var fortress: RefCounted
var link_points: PackedVector3Array = PackedVector3Array()

func configure() -> void:
	link_points.clear()
	original = load("res://scripts/showcases/forest_scale_builder.gd").new()
	original.plots.remove_at(4)
	fortress = load("res://scripts/showcases/ridge_fortress_builder.gd").new()
	plots[4] = {"name":"山脊大本营", "p":Vector2(100,-85), "size":Vector2(110,140), "h":0.0}
	routes[2] = PackedVector2Array([Vector2(0,81),Vector2(31,67),Vector2(48,48),Vector2(82,39),Vector2(98,20),Vector2(100,9)])
	routes[4] = PackedVector2Array([Vector2(-63,14),Vector2(-63,20),Vector2(-34,20),Vector2(-30,-3),Vector2(1,-24),Vector2(30,-36),Vector2(45,-16),Vector2(82,-16),Vector2(98,20),Vector2(100,9)])
	routes[5] = PackedVector2Array([Vector2(5,-52),Vector2(30,-36),Vector2(45,-16),Vector2(82,-16),Vector2(98,20),Vector2(100,9)])
	for p: Vector2 in routes[2]:
		link_points.append(Vector3(p.x,height_at(p),p.y))

func height_at(p: Vector2) -> float:
	var q: Vector2 = p-Vector2(ORIGIN.x,ORIGIN.z)
	var weight: float = (1.0-smoothstep(58,90,absf(q.x)))*(1.0-smoothstep(105,140,-q.y))*(1.0-smoothstep(65,105,q.y))
	var h: float = lerpf(original.height_at(p),fortress.terrain_height(q),weight)
	h -= 4.0*exp(-pow((p.x-177)/5.0,2.0))*(1.0-smoothstep(-5,25,p.y))
	return lerpf(h,-.08,1.0-smoothstep(5,15,p.distance_to(Vector2(100,9))))

func forest() -> void:
	super.forest()
	# 入口净空与基地视线走廊：同步裁掉树冠、树干及其碰撞。
	for source: MultiMeshInstance3D in g.root.get_node("ForestBelts").find_children("*","MultiMeshInstance3D",true,false):
		var kept: Array[Transform3D] = []
		for i: int in range(source.multimesh.instance_count):
			var t: Transform3D = source.multimesh.get_instance_transform(i)
			if not blocks_fortress_view(Vector2(t.origin.x,t.origin.z)):
				kept.append(t)
		source.multimesh.instance_count = kept.size()
		for i: int in range(kept.size()):
			source.multimesh.set_instance_transform(i,kept[i])
	for trunk: CollisionShape3D in g.root.get_node("ForestBelts/TreeTrunkCollision").get_children():
		if blocks_fortress_view(Vector2(trunk.position.x,trunk.position.z)):
			trunk.free()
	var positions: Array[Vector3] = []
	for i: int in range(800):
		var p: Vector2 = Vector2(rng.randf_range(-137,189),rng.randf_range(-199,109))
		if (p.x<137 and p.y>-110) or road_distance(p)<6:
			continue
		if absf(p.x-100)<61 and absf(p.y+85)<79:
			continue
		if absf(p.x-177)<6:
			continue
		positions.append(Vector3(p.x,height_at(p),p.y))
	for source: MultiMeshInstance3D in g.root.get_node("ForestBelts").find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = source.multimesh.mesh
		mm.instance_count = positions.size()
		var tier: int = 0 if source.name == "Trunks" else int(str(source.name).right(1))
		for i: int in range(positions.size()):
			mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,positions[i]+Vector3.UP*(4.0 if tier==0 else 4.5+tier*1.5)))
		var trees: MultiMeshInstance3D = MultiMeshInstance3D.new()
		trees.name = "Extended"+str(source.name)
		trees.multimesh = mm
		trees.material_override = source.material_override
		g.root.get_node("ForestBelts").add_child(trees)

func blocks_fortress_view(p: Vector2) -> bool:
	if absf(p.x-100)<11 and p.y > -25 and p.y < 27:
		return true
	var a: Vector2 = Vector2(0,78)
	var b: Vector2 = Vector2(100,-95)
	var t: float = clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
	return p.distance_to(a.lerp(b,t))<9.0

func terrain() -> void:
	g.group("Terrain")
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in range(-205,113,2):
		for x: int in range(-140,194,2):
			for p: Vector2 in [Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]:
				st.set_uv(p*.1)
				st.add_vertex(Vector3(p.x,height_at(p),p.y))
	st.generate_normals()
	var mesh: MeshInstance3D = g.mesh_at("UnifiedForestAndFortressSlope",st.commit(),Vector3.ZERO,g.plain(Color(.27,.31,.25),.95))
	mesh.create_trimesh_collision()
	for x: float in [-141,195]:
		block("Boundary",Vector3(x,25,-46),Vector3(1,100,320),g.dark).visible = false
	for z: float in [-206,114]:
		block("Boundary",Vector3(27,25,z),Vector3(338,100,1),g.dark).visible = false

func build() -> String:
	configure()
	rng.seed = 9072026
	g = KIT.new()
	g.root = ResourceLoader.load("res://scenes/showcases/forest_world_scale.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	g.root.scene_file_path = ""
	g.root.name = "ForestWorldFortress"
	for group_name: String in ["Terrain","RoadNetwork","ForestBelts"]:
		g.root.get_node(group_name).free()
	for node: Node in g.root.get_node("BuildingPlots").get_children():
		if node is Node3D and node.position.x>60 and node.position.z < -45:
			node.free()
	for node: Node in g.root.get_node("CoarseLandmarks").get_children():
		if node is Node3D and ((node.position.x>60 and node.position.z < -40) or str(node.name).begins_with("CreekWater")):
			node.free()
	materials()
	terrain()
	roads()
	forest()
	g.group("RegradedCreek")
	for z: int in range(-190,100,5):
		var x: float = 177.0 if z < 10 else 106+5*sin(z*.035)
		var p: Vector2 = Vector2(x,z)
		if road_distance(p)>6:
			g.box("CreekWater",Vector3(x,height_at(p)+.03,z),Vector3(2.5,.03,5.1),g.plain(Color(.12,.19,.18),.23))
	var asset: Node3D = ResourceLoader.load("res://scenes/showcases/ridge_fortress.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	asset.position = ORIGIN
	var mountain: Node3D = asset.get_node("RockyHillside/Mountain")
	mountain.visible = false
	for body: StaticBody3D in mountain.find_children("*","StaticBody3D",true,false):
		body.collision_layer = 0
		body.collision_mask = 0
	asset.get_node("SlopeForest").visible = false
	g.root.add_child(asset)
	asset.owner = g.root
	g.root.set_editable_instance(asset,true)
	for node: Node in g.root.get_children():
		node.owner = g.root
		if node != asset and node.name != "Player":
			for child: Node in node.find_children("*","",true,false):
				child.owner = g.root
	g.root.set_script(load("res://scripts/showcases/ridge_fortress_world_review.gd"))
	var packed: PackedScene = PackedScene.new()
	var result: Error = packed.pack(g.root)
	if result == OK:
		result = ResourceSaver.save(packed,DESTINATION)
	g.root.free()
	return "原东北占位改造保存=%s；统一地形334×318m；堡垒中心(100,-85)；无外接桥" % result
