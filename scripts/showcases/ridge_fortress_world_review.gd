extends "res://scripts/showcases/forest_scale_review.gd"

func _ready() -> void:
	super._ready()
	checkpoints[7] = Vector3(100,1,9)
	checkpoints.append(Vector3(100,9,-28))
	checkpoints.append(Vector3(100,22,-87))
	checkpoints.append(Vector3(100,36,-120))
	overview.look_at_from_position(Vector3(230,240,240),Vector3(20,12,-45))
	overview.far = 900
	print("原东北占位改造：F6 可到山脚、半山和山顶；统一地形，无外接新区。")

func _process(delta: float) -> void:
	super._process(delta)
	hud.text = hud.text.replace("280 × 225 m","334 × 318 m")

func begin_audit() -> void:
	super.begin_audit()
	var builder: RefCounted = load("res://scripts/showcases/ridge_fortress_world_builder.gd").new()
	builder.configure()
	for i: int in range(6):
		var points: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in builder.routes[i]:
			points.append(Vector3(p.x,builder.height_at(p)+.99,p.y))
		audit_routes[i] = points
	start_route()

func capture_views() -> void:
	set_overhead(true)
	overhead = true
	overview.fov = 65
	world_environment.fog_enabled = true
	for item: Dictionary in [{"name":"fortress_base_sightline","p":Vector3(0,3.2,78),"target":Vector3(100,35,-95)},{"name":"fortress_approach","p":Vector3(100,3.2,20),"target":Vector3(100,33,-110)}]:
		overview.look_at_from_position(item.p,item.target)
		await get_tree().create_timer(.5).timeout
		await capture(item.name)
	world_environment.fog_enabled = false
	overview.fov = 45
	overview.look_at_from_position(Vector3(230,240,240),Vector3(20,12,-45))
	await capture("fortress_world_overview")
	player.position = checkpoints[0]
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	overhead = false
	set_overhead(false)
