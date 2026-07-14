class_name StatusContainer
extends Node

signal status_applied(status_id: StringName)
signal status_removed(status_id: StringName)
signal status_changed(status_id: StringName, remaining_seconds: float)
signal status_tick(status_id: StringName, health_delta: float, stamina_delta: float, hunger_delta: float)

@export_group("Definitions")
@export var status_definitions: Array[StatusEffectDefinition] = []
@export var initial_statuses: Array[StatusEffectDefinition] = []

var active_statuses: Dictionary[StringName, Dictionary] = {}
var _event_bus: Node


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	for status: StatusEffectDefinition in initial_statuses:
		apply_status(status)


func _process(delta: float) -> void:
	var expired_statuses: Array[StringName] = []

	for status_id: StringName in active_statuses.keys():
		var active: Dictionary = active_statuses[status_id]
		var definition: StatusEffectDefinition = active["definition"] as StatusEffectDefinition
		var remaining: float = float(active["remaining_seconds"])
		if remaining < 0.0:
			_tick_status(active, definition, status_id, delta)
			continue

		remaining = maxf(0.0, remaining - delta)
		active["remaining_seconds"] = remaining
		_tick_status(active, definition, status_id, delta)
		status_changed.emit(status_id, remaining)
		_emit_status_list_event()
		if remaining <= 0.0:
			expired_statuses.append(status_id)

	for status_id: StringName in expired_statuses:
		remove_status(status_id)


func apply_status(status: StatusEffectDefinition, duration_override: float = -1.0) -> bool:
	if status == null or status.status_id == &"":
		return false

	var duration: float = duration_override if duration_override >= 0.0 else status.duration_seconds
	if status.is_permanent_until_removed:
		duration = -1.0

	if active_statuses.has(status.status_id):
		return _refresh_existing_status(status, duration)

	active_statuses[status.status_id] = {
		"definition": status,
		"remaining_seconds": duration,
		"tick_elapsed": 0.0,
	}
	status_applied.emit(status.status_id)
	status_changed.emit(status.status_id, duration)
	_emit_status_event(status.status_id, true)
	return true


func apply_status_by_id(status_id: StringName, duration_override: float = -1.0) -> bool:
	for definition: StatusEffectDefinition in status_definitions:
		if definition != null and definition.status_id == status_id:
			return apply_status(definition, duration_override)
	return false


func remove_status(status_id: StringName) -> void:
	if not active_statuses.has(status_id):
		return

	active_statuses.erase(status_id)
	status_removed.emit(status_id)
	_emit_status_event(status_id, false)


func clear_statuses() -> void:
	var status_ids: Array[StringName] = []
	for status_id: StringName in active_statuses.keys():
		status_ids.append(status_id)
	for status_id: StringName in status_ids:
		remove_status(status_id)


func has_status(status_id: StringName) -> bool:
	return active_statuses.has(status_id)


func get_status_definition(status_id: StringName) -> StatusEffectDefinition:
	if not active_statuses.has(status_id):
		return null
	return active_statuses[status_id]["definition"] as StatusEffectDefinition


func get_status_remaining(status_id: StringName) -> float:
	if not active_statuses.has(status_id):
		return 0.0
	return float(active_statuses[status_id]["remaining_seconds"])


func get_active_statuses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for status_id: StringName in active_statuses.keys():
		var active: Dictionary = active_statuses[status_id]
		var definition: StatusEffectDefinition = active["definition"] as StatusEffectDefinition
		result.append({
			"status_id": status_id,
			"display_name": definition.display_name,
			"description": definition.description,
			"category": definition.category,
			"remaining_seconds": float(active["remaining_seconds"]),
		})
	return result


func get_constraints() -> Dictionary:
	var constraints: Dictionary = {
		"movement_disabled": false,
		"combat_blocked": false,
		"interaction_blocked": false,
		"mobility_blocked": false,
		"outgoing_damage_multiplier": 1.0,
		"incoming_damage_multiplier": 1.0,
		"stamina_recovery_multiplier": 1.0,
		"movement_speed_multiplier": 1.0,
	}

	for active: Dictionary in active_statuses.values():
		var definition: StatusEffectDefinition = active["definition"] as StatusEffectDefinition
		constraints["movement_disabled"] = constraints["movement_disabled"] or definition.movement_disabled
		constraints["combat_blocked"] = constraints["combat_blocked"] or definition.combat_blocked
		constraints["interaction_blocked"] = constraints["interaction_blocked"] or definition.interaction_blocked
		constraints["mobility_blocked"] = constraints["mobility_blocked"] or definition.mobility_blocked
		constraints["outgoing_damage_multiplier"] *= definition.outgoing_damage_multiplier
		constraints["incoming_damage_multiplier"] *= definition.incoming_damage_multiplier
		constraints["stamina_recovery_multiplier"] *= definition.stamina_recovery_multiplier
		constraints["movement_speed_multiplier"] *= definition.movement_speed_multiplier

	return constraints


func _refresh_existing_status(status: StatusEffectDefinition, duration: float) -> bool:
	var active: Dictionary = active_statuses[status.status_id]
	active["definition"] = status
	active["remaining_seconds"] = duration
	active["tick_elapsed"] = 0.0
	active_statuses[status.status_id] = active
	status_changed.emit(status.status_id, duration)
	_emit_status_list_event()
	return true


func _tick_status(
	active: Dictionary,
	definition: StatusEffectDefinition,
	status_id: StringName,
	delta: float,
) -> void:
	if definition.tick_interval_seconds <= 0.0:
		return

	var tick_elapsed: float = float(active["tick_elapsed"]) + delta
	while tick_elapsed >= definition.tick_interval_seconds:
		tick_elapsed -= definition.tick_interval_seconds
		status_tick.emit(
			status_id,
			definition.health_delta_per_tick,
			definition.stamina_delta_per_tick,
			definition.hunger_delta_per_tick
		)
	active["tick_elapsed"] = tick_elapsed


func _emit_status_event(status_id: StringName, applied: bool) -> void:
	if _event_bus == null:
		return
	var target_id: int = _get_target_id()
	if applied:
		_event_bus.status_applied.emit(target_id, status_id)
	else:
		_event_bus.status_removed.emit(target_id, status_id)
	_emit_status_list_event()


func _emit_status_list_event() -> void:
	if _event_bus == null:
		return
	var target_id: int = _get_target_id()
	_event_bus.status_list_changed.emit(target_id, get_active_statuses())


func _get_target_id() -> int:
	if owner != null:
		return owner.get_instance_id()
	var target: Node = get_parent()
	return target.get_instance_id() if target != null else get_instance_id()
