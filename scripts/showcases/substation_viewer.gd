extends "res://scripts/showcases/pump_station_viewer.gd"

func capture(filename: String = "substation_showcase") -> void:
	await super.capture(filename)

func set_view(index: int) -> void:
	match index:
		1:
			camera.transform = home_transform
		2:
			camera.look_at_from_position(Vector3(-1.7,2.6,2.7),Vector3(-4.7,2.4,-3))
		3:
			camera.look_at_from_position(Vector3(6.7,2.1,10),Vector3(10.2,1.7,-2))
		4:
			camera.look_at_from_position(Vector3(-8,5.3,-13),Vector3(5,4.9,-11.8))

func validate_showcase() -> void:
	for n: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		assert(n.mesh != null and n.mesh.get_surface_count()>0)
	print("SUBSTATION_AUDIT PASS: 所有展示网格均包含面片。")
