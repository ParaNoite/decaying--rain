extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const BODY_RENDER_LAYER: int = 2


func _ready() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	_check(player != null, "player scene must instantiate Player3DController")
	add_child(player)
	await get_tree().process_frame

	_check(player.get_node_or_null("Visuals/BodyMesh") == null, "legacy capsule BodyMesh must be removed")
	_check(player.get_node_or_null("Visuals/ForwardMarker") == null, "legacy forward marker must be removed")
	var body: Node3D = player.get_node_or_null("Visuals/PlayerBodyVisual") as Node3D
	_check(body != null, "player must instance the articulated body visual")
	_check(int(body.call("get_mesh_count")) >= 40, "player body must be a layered character model, not a primitive placeholder")
	_check(body.get_node_or_null("MotionRoot/Hips/Spine/LeftShoulder/LeftElbow") != null, "left arm must expose shoulder and elbow joints")
	_check(body.get_node_or_null("MotionRoot/Hips/Spine/RightShoulder/RightElbow") != null, "right arm must expose shoulder and elbow joints")
	_check(body.get_node_or_null("MotionRoot/Hips/LeftHip/LeftKnee") != null, "left leg must expose hip and knee joints")
	_check(body.get_node_or_null("MotionRoot/Hips/RightHip/RightKnee") != null, "right leg must expose hip and knee joints")
	_check((player.get_node("Head/Camera3D") as Camera3D).cull_mask == 1, "first-person camera must exclude the third-person body layer")
	_check(_all_meshes_use_body_layer(body), "all body meshes must use the isolated body render layer")

	body.call("update_locomotion", 4.5, false, 0.2)
	var left_hip: Node3D = body.get_node("MotionRoot/Hips/LeftHip") as Node3D
	var right_hip: Node3D = body.get_node("MotionRoot/Hips/RightHip") as Node3D
	_check(absf(left_hip.rotation.x - right_hip.rotation.x) > 0.05, "walking must drive distinct opposing leg poses")
	print("PLAYER_BODY_VISUAL_SMOKE: PASS")
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


func _all_meshes_use_body_layer(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).layers != BODY_RENDER_LAYER:
		return false
	for child: Node in node.get_children():
		if not _all_meshes_use_body_layer(child):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("PLAYER_BODY_VISUAL_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)
