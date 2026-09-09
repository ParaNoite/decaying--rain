extends "res://scripts/showcases/pump_station_viewer.gd"
## 复用已有展示相机输入；独立镜位与截图输出，不修改原展示脚本。
func _ready() -> void:
	super._ready()
	print("山脊堡垒：1 远景 / 2 鸟瞰 / 3 半山 / 4 山顶；右键+WASD 飞行，Q/E 升降，F12 截图。")
	await get_tree().create_timer(3).timeout
	for i: int in range(1,5):
		set_view(i)
		await get_tree().create_timer(.5).timeout
		await capture("ridge_fortress_%d" % i)
	set_view(1)

func set_view(index: int) -> void:
	match index:
		1:
			camera.transform = home_transform
		2:
			camera.look_at_from_position(Vector3(110,110,125),Vector3(0,23,-10))
		3:
			camera.look_at_from_position(Vector3(0,23,15),Vector3(0,42,-48))
		4:
			camera.look_at_from_position(Vector3(0,37,-32),Vector3(0,10,90))

func capture(filename: String = "ridge_fortress_manual") -> void:
	if capturing:
		return
	capturing = true
	await RenderingServer.frame_post_draw
	var directory: String = "res://output/showcases/ridge_fortress"
	DirAccess.make_dir_recursive_absolute(directory)
	var result: Error = get_viewport().get_texture().get_image().save_png(directory+"/"+filename+".png")
	print("RIDGE_CAPTURE ",filename," result=",result)
	capturing = false
