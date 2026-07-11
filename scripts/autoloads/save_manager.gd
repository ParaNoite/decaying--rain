extends Node

const SAVE_DIR: String = "user://saves"
const SAVE_EXTENSION: String = ".json"


func save_run_snapshot(slot_id: StringName, payload: Dictionary) -> Error:
	var data: Dictionary = payload.duplicate(true)
	data["version"] = VersionInfo.SAVE_SCHEMA_VERSION
	data["game_version"] = VersionInfo.GAME_VERSION
	data["saved_at_unix"] = Time.get_unix_time_from_system()

	var dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	if dir_error != OK:
		push_error("Failed to create save directory: %s" % error_string(dir_error))
		return dir_error

	var file := FileAccess.open(_slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("Failed to open save file: %s" % error_string(open_error))
		return open_error

	file.store_string(JSON.stringify(data, "\t"))
	return OK


func load_run_snapshot(slot_id: StringName) -> Dictionary:
	var path: String = _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file: %s" % error_string(FileAccess.get_open_error()))
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save file is not a dictionary: %s" % path)
		return {}

	return _migrate(parsed as Dictionary)


func get_save_slots() -> Array[StringName]:
	var slots: Array[StringName] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return slots

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
			slots.append(StringName(file_name.trim_suffix(SAVE_EXTENSION)))
		file_name = dir.get_next()

	return slots


func delete_save(slot_id: StringName) -> Error:
	var absolute_path: String = ProjectSettings.globalize_path(_slot_path(slot_id))
	if not FileAccess.file_exists(_slot_path(slot_id)):
		return OK
	return DirAccess.remove_absolute(absolute_path)


func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))

	while version < VersionInfo.SAVE_SCHEMA_VERSION:
		match version:
			0:
				data["version"] = 1
				version = 1
			_:
				push_error("Unsupported save version: %d" % version)
				return {}

	return data


func _slot_path(slot_id: StringName) -> String:
	return "%s/%s%s" % [SAVE_DIR, String(slot_id), SAVE_EXTENSION]
