extends "res://scripts/showcases/ridge_fortress_viewer.gd"
var routes: Array[PackedVector3Array] = []
var probe: CharacterBody3D
var route_id: int = 0
var point_id: int = 1
var ticks: int = 0
var report: Array[String] = []
@export var start_at_route: int = 0

func _ready() -> void:
	super._ready()
	var builder: RefCounted = load("res://scripts/showcases/ridge_fortress_builder.gd").new()
	var main: PackedVector3Array = builder.road.duplicate()
	main.resize(main.size()-1)
	for i: int in range(1,builder.upper_road.size()):
		main.append(builder.upper_road[i])
	routes.append(main)
	var back: PackedVector3Array = main.duplicate()
	back.reverse()
	routes.append(back)
	var stairs: PackedVector3Array = PackedVector3Array([Vector3(30,8,44),Vector3(39,8,43),Vector3(39,21,17),Vector3(38,21,15),Vector3(38,21,-19),Vector3(38,35,-47),Vector3(38,35,-49),Vector3(32,35,-49),Vector3(32,35,-35),Vector3(0,35,-35),Vector3(-3,35,-39),Vector3(-3,35,-46)])
	routes.append(stairs)
	var down: PackedVector3Array = stairs.duplicate()
	down.reverse()
	routes.append(down)
	probe = CharacterBody3D.new()
	probe.collision_layer = 0
	probe.collision_mask = 1
	probe.floor_snap_length = .3
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = .35
	capsule.height = 1.8
	collision.shape = capsule
	probe.add_child(collision)
	add_child(probe)
	route_id = start_at_route
	start_route()

func start_route() -> void:
	probe.position = routes[route_id][0]+Vector3.UP*.95
	probe.velocity = Vector3.ZERO
	probe.reset_physics_interpolation()
	point_id = 1
	ticks = 0

func _physics_process(delta: float) -> void:
	if probe == null:
		return
	var target: Vector3 = routes[route_id][point_id]+Vector3.UP*.9
	var d: Vector3 = target-probe.position
	var flat: Vector3 = Vector3(d.x,0,d.z)
	if flat.length()<.35 and absf(d.y)<.5:
		point_id += 1
		ticks = 0
		if point_id == routes[route_id].size():
			finish(true)
		return
	probe.velocity.x = flat.normalized().x*5.4
	probe.velocity.z = flat.normalized().z*5.4
	probe.velocity.y -= 18*delta
	probe.move_and_slide()
	ticks += 1
	if ticks>1200 or probe.position.y < -10:
		finish(false)

func finish(passed: bool) -> void:
	var line: String = "路线 %d %s 节点 %d 位置 %s" % [route_id+1,"PASS" if passed else "FAIL",point_id,probe.position]
	report.append(line)
	print("RIDGE_AUDIT ",line)
	route_id += 1
	if route_id < routes.size():
		start_route()
	else:
		probe.queue_free()
		probe = null
		var file: FileAccess = FileAccess.open("res://output/showcases/ridge_fortress/collision_audit.txt",FileAccess.WRITE)
		file.store_string("0.35 m 半径 / 1.8 m 高胶囊；主路往返、检修梯与指挥楼入口往返\n"+"\n".join(report))
		print("RIDGE_AUDIT COMPLETE")
