extends "res://scripts/showcases/ridge_fortress_world_review.gd"
var link_probe: CharacterBody3D
var link_route: PackedVector3Array
var link_target: int = 1
var link_ticks: int = 0
var returning: bool = false
var link_report: Array[String] = []
var stairs_phase: bool = false

func _ready() -> void:
	super._ready()
	set_overhead(true)
	overhead = true
	var builder: RefCounted = load("res://scripts/showcases/ridge_fortress_world_builder.gd").new()
	builder.configure()
	link_route = builder.link_points.duplicate()
	for i: int in range(1,builder.fortress.road.size()-1):
		link_route.append(builder.fortress.road[i]+builder.ORIGIN)
	for i: int in range(1,builder.fortress.upper_road.size()):
		link_route.append(builder.fortress.upper_road[i]+builder.ORIGIN)
	link_probe = CharacterBody3D.new()
	link_probe.collision_layer = 0
	link_probe.collision_mask = 1
	link_probe.floor_snap_length = .3
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = .35
	shape.height = 1.8
	cs.shape = shape
	link_probe.add_child(cs)
	add_child(link_probe)
	link_probe.position = link_route[0]+Vector3.UP*.95
	capture("fortress_world_overview")

func _physics_process(delta: float) -> void:
	if link_probe == null:
		return
	var difference: Vector3 = link_route[link_target]+Vector3.UP*.9-link_probe.position
	var flat: Vector3 = Vector3(difference.x,0,difference.z)
	if flat.length()<.35 and absf(difference.y)<.6:
		link_target += 1
		link_ticks = 0
		if link_target == link_route.size():
			complete_link(true)
		return
	link_probe.velocity.x = flat.normalized().x*5.4
	link_probe.velocity.z = flat.normalized().z*5.4
	link_probe.velocity.y -= 18*delta
	link_probe.move_and_slide()
	link_ticks += 1
	if link_ticks > 1500 or link_probe.position.y < -15:
		complete_link(false)

func complete_link(passed: bool) -> void:
	var label: String = "整合地图检修梯与指挥楼入口" if stairs_phase else "基地沿原东线到山顶"
	var line: String = "%s %s %s 节点 %d 位置 %s" % [label,"返程" if returning else "去程","PASS" if passed else "FAIL",link_target,link_probe.position]
	print("FORTRESS_LINK ",line)
	link_report.append(line)
	if not returning:
		returning = true
		link_route.reverse()
		link_target = 1
		link_ticks = 0
		link_probe.position = link_route[0]+Vector3.UP*.95
		link_probe.velocity = Vector3.ZERO
		link_probe.reset_physics_interpolation()
	elif not stairs_phase:
		stairs_phase = true
		returning = false
		link_route = PackedVector3Array([Vector3(30,8,44),Vector3(39,8,43),Vector3(39,21,17),Vector3(38,21,15),Vector3(38,21,-19),Vector3(38,35,-47),Vector3(38,35,-49),Vector3(32,35,-49),Vector3(32,35,-35),Vector3(0,35,-35),Vector3(-3,35,-39),Vector3(-3,35,-46)])
		for i: int in range(link_route.size()):
			link_route[i] += Vector3(100,0,-85)
		link_target = 1
		link_ticks = 0
		link_probe.position = link_route[0]+Vector3.UP*.95
		link_probe.velocity = Vector3.ZERO
		link_probe.reset_physics_interpolation()
	else:
		link_probe.queue_free()
		link_probe = null
		var file: FileAccess = FileAccess.open("res://output/showcases/ridge_fortress/link_audit.txt",FileAccess.WRITE)
		file.store_string("\n".join(link_report))
		capture_views()
