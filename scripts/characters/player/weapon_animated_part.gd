@tool
class_name WeaponAnimatedPart
extends Node3D
## Offset is authored in this node's coordinate frame, independent of GLB units.
@export var target_path: NodePath
@export var offset: Vector3 = Vector3.ZERO
var _target: Node3D
var _rest: Transform3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		_rest = _target.transform


func _process(_delta: float) -> void:
	apply_pose()


func apply_pose() -> void:
	if not is_instance_valid(_target):
		return
	var parent: Node3D = _target.get_parent() as Node3D
	_target.transform = _rest
	_target.position += parent.global_basis.inverse() * global_basis * offset


func reset_pose() -> void:
	offset = Vector3.ZERO
	apply_pose()
