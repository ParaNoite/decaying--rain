class_name UnlockRegistry
extends RefCounted

var unlocked_ids: Array[StringName] = []


func unlock(unlock_id: StringName) -> void:
	if unlock_id == &"" or unlocked_ids.has(unlock_id):
		return
	unlocked_ids.append(unlock_id)


func is_unlocked(unlock_id: StringName) -> bool:
	return unlocked_ids.has(unlock_id)


func to_dictionary() -> Dictionary:
	return {"unlocked_ids": unlocked_ids.duplicate()}


func load_dictionary(data: Dictionary) -> void:
	unlocked_ids.clear()
	for value: Variant in data.get("unlocked_ids", []):
		unlocked_ids.append(StringName(value))
