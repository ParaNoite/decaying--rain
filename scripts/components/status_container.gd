class_name StatusContainer
extends Node

signal status_applied(status_id: StringName)
signal status_removed(status_id: StringName)

var active_statuses: Dictionary[StringName, float] = {}


func _process(delta: float) -> void:
	var expired_statuses: Array[StringName] = []

	for status_id: StringName in active_statuses.keys():
		var remaining: float = active_statuses[status_id]
		if remaining < 0.0:
			continue
		remaining -= delta
		active_statuses[status_id] = remaining
		if remaining <= 0.0:
			expired_statuses.append(status_id)

	for status_id: StringName in expired_statuses:
		remove_status(status_id)


func apply_status(status: StatusEffectDefinition, duration_override: float = -1.0) -> void:
	if status == null:
		return

	var duration: float = duration_override if duration_override >= 0.0 else status.duration_seconds
	if status.is_permanent_until_removed:
		duration = -1.0

	active_statuses[status.status_id] = duration
	status_applied.emit(status.status_id)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.status_applied.emit(get_instance_id(), status.status_id)


func remove_status(status_id: StringName) -> void:
	if not active_statuses.has(status_id):
		return

	active_statuses.erase(status_id)
	status_removed.emit(status_id)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.status_removed.emit(get_instance_id(), status_id)


func has_status(status_id: StringName) -> bool:
	return active_statuses.has(status_id)
