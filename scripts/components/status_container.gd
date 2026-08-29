class_name StatusContainer
extends Node

signal status_applied(status_id: StringName)
signal status_removed(status_id: StringName)
signal status_changed(status_id: StringName, remaining_seconds: float)
signal status_tick(
	status_id: StringName,
	source_id: int,
	damage_type: StringName,
	health_delta: float,
	stamina_delta: float,
	hunger_delta: float
)
signal status_list_changed(statuses: Array[Dictionary])

const STATUS_LIST_UPDATE_INTERVAL: float = 0.1

@export var initial_statuses: Array[StatusEffectDefinition] = []

var active_statuses: Dictionary[StringName, ActiveStatusData] = {}
var _status_list_update_elapsed: float = 0.0


func _process(delta: float) -> void:
	var expired_statuses: Array[StringName] = []
	var has_timed_status: bool = false

	for status_id: StringName in active_statuses.keys():
		var active: ActiveStatusData = active_statuses[status_id]
		if active.remaining_seconds < 0.0:
			_tick_status(active, status_id, delta)
			continue

		has_timed_status = true
		var active_delta: float = minf(delta, active.remaining_seconds)
		active.remaining_seconds = maxf(0.0, active.remaining_seconds - delta)
		_tick_status(active, status_id, active_delta)
		status_changed.emit(status_id, active.remaining_seconds)
		if active.remaining_seconds <= 0.0:
			expired_statuses.append(status_id)

	for status_id: StringName in expired_statuses:
		remove_resolved_status(status_id)

	if has_timed_status and expired_statuses.is_empty():
		_status_list_update_elapsed += delta
		if _status_list_update_elapsed >= STATUS_LIST_UPDATE_INTERVAL:
			_status_list_update_elapsed = 0.0
			_emit_status_list_changed()


func apply_resolved_status(
	status: StatusEffectDefinition,
	duration_seconds: float,
	source_id: int = 0,
) -> bool:
	if status == null or status.status_id == &"":
		return false

	var duration: float = duration_seconds
	if status.is_permanent_until_removed:
		duration = -1.0

	if active_statuses.has(status.status_id):
		return _update_existing_status(status, duration, source_id)

	active_statuses[status.status_id] = ActiveStatusData.new(status, duration, source_id)
	status_applied.emit(status.status_id)
	status_changed.emit(status.status_id, duration)
	_emit_status_list_changed()
	return true


func remove_resolved_status(status_id: StringName) -> bool:
	if not active_statuses.has(status_id):
		return false

	active_statuses.erase(status_id)
	status_removed.emit(status_id)
	_emit_status_list_changed()
	return true


func clear_resolved_statuses() -> void:
	var status_ids: Array[StringName] = []
	for status_id: StringName in active_statuses.keys():
		status_ids.append(status_id)
	for status_id: StringName in status_ids:
		remove_resolved_status(status_id)


func has_status(status_id: StringName) -> bool:
	return active_statuses.has(status_id)


func get_status_definition(status_id: StringName) -> StatusEffectDefinition:
	if not active_statuses.has(status_id):
		return null
	return active_statuses[status_id].definition


func get_status_remaining(status_id: StringName) -> float:
	if not active_statuses.has(status_id):
		return 0.0
	return active_statuses[status_id].remaining_seconds


func get_status_stack_count(status_id: StringName) -> int:
	if not active_statuses.has(status_id):
		return 0
	return active_statuses[status_id].stack_count


func get_active_statuses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for status_id: StringName in active_statuses.keys():
		var active: ActiveStatusData = active_statuses[status_id]
		result.append({
			"status_id": status_id,
			"display_name": active.definition.display_name,
			"description": active.definition.description,
			"category": active.definition.category,
			"remaining_seconds": active.remaining_seconds,
			"stack_count": active.stack_count,
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
		"sprint_speed_multiplier": 1.0,
	}

	for active: ActiveStatusData in active_statuses.values():
		var definition: StatusEffectDefinition = active.definition
		constraints["movement_disabled"] = constraints["movement_disabled"] or definition.movement_disabled
		constraints["combat_blocked"] = constraints["combat_blocked"] or definition.combat_blocked
		constraints["interaction_blocked"] = constraints["interaction_blocked"] or definition.interaction_blocked
		constraints["mobility_blocked"] = constraints["mobility_blocked"] or definition.mobility_blocked
		constraints["outgoing_damage_multiplier"] *= definition.outgoing_damage_multiplier
		constraints["incoming_damage_multiplier"] *= definition.incoming_damage_multiplier
		constraints["stamina_recovery_multiplier"] *= definition.stamina_recovery_multiplier
		constraints["movement_speed_multiplier"] *= definition.movement_speed_multiplier
		constraints["sprint_speed_multiplier"] *= definition.sprint_speed_multiplier

	return constraints


func _update_existing_status(
	status: StatusEffectDefinition,
	duration_seconds: float,
	source_id: int,
) -> bool:
	var active: ActiveStatusData = active_statuses[status.status_id]
	match status.stack_policy:
		StatusEffectDefinition.StackPolicy.REFRESH_DURATION:
			active.definition = status
			active.remaining_seconds = duration_seconds
			active.source_id = source_id
		StatusEffectDefinition.StackPolicy.REPLACE:
			active = ActiveStatusData.new(status, duration_seconds, source_id)
			active_statuses[status.status_id] = active
		StatusEffectDefinition.StackPolicy.ADD_STACK:
			# Statuses are intentionally unique. Legacy stack definitions now refresh instead.
			active.definition = status
			active.remaining_seconds = duration_seconds
			active.source_id = source_id
			active.stack_count = 1
		_:
			return false

	status_changed.emit(status.status_id, duration_seconds)
	_emit_status_list_changed()
	return true


func _tick_status(active: ActiveStatusData, status_id: StringName, delta: float) -> void:
	var definition: StatusEffectDefinition = active.definition
	if definition.tick_interval_seconds <= 0.0 or delta <= 0.0:
		return

	active.tick_elapsed += delta
	while active.tick_elapsed >= definition.tick_interval_seconds:
		active.tick_elapsed -= definition.tick_interval_seconds
		var stacks: float = float(active.stack_count)
		status_tick.emit(
			status_id,
			active.source_id,
			definition.tick_damage_type,
			definition.health_delta_per_tick * stacks,
			definition.stamina_delta_per_tick * stacks,
			definition.hunger_delta_per_tick * stacks
		)


func _emit_status_list_changed() -> void:
	_status_list_update_elapsed = 0.0
	status_list_changed.emit(get_active_statuses())
