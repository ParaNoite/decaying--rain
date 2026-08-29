extends Node

signal damage_resolved(result: DamageResolutionData)

var _event_bus: Node
var _buff_resolver: Node


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	_buff_resolver = get_node_or_null("/root/BuffResolver")


func resolve_damage(data: DamageEventData, target: Node) -> DamageResolutionData:
	var result: DamageResolutionData = DamageResolutionData.new()
	result.event = data
	result.target = target

	if data == null:
		result.rejection_reason = &"missing_event"
		return result
	result.raw_amount = maxf(0.0, data.amount)

	if target == null or not is_instance_valid(target):
		result.rejection_reason = &"missing_target"
		return result
	if not data.is_valid_resolution_request():
		result.rejection_reason = &"invalid_event"
		return result
	if data.target_id != target.get_instance_id():
		result.rejection_reason = &"target_mismatch"
		return result

	if target.has_method("try_block_damage") and bool(target.call("try_block_damage", data)):
		result.blocked = true
		_finish_resolution(result)
		return result

	if data.amount > 0.0:
		var health: HealthComponent = _get_health_component(target)
		if health == null:
			result.rejection_reason = &"missing_health_component"
			return result
		if not health.is_alive():
			result.rejection_reason = &"target_dead"
			return result

		result.outgoing_multiplier = _get_outgoing_multiplier(data)
		result.critical_multiplier = maxf(1.0, data.critical_multiplier) if data.is_critical else 1.0
		result.damage_type_multiplier = _get_damage_type_multiplier(target, data.damage_type)
		result.incoming_multiplier = _get_incoming_multiplier(data, target)
		result.final_amount = maxf(
			0.0,
			data.amount
			* result.outgoing_multiplier
			* result.critical_multiplier
			* result.damage_type_multiplier
			* result.incoming_multiplier
		)
		if result.final_amount > 0.0:
			health.take_damage(result.final_amount)
			_apply_hit_statuses(data, target)

	result.applied = true
	_finish_resolution(result)
	return result


func _get_outgoing_multiplier(data: DamageEventData) -> float:
	if data.bypass_outgoing_modifiers or _buff_resolver == null or data.attacker_id == 0:
		return 1.0
	var attacker: Object = instance_from_id(data.attacker_id)
	if not (attacker is Node):
		return 1.0
	var constraints: Dictionary = _buff_resolver.call("get_constraints", attacker as Node)
	return maxf(0.0, float(constraints.get("outgoing_damage_multiplier", 1.0)))


func _get_incoming_multiplier(data: DamageEventData, target: Node) -> float:
	if data.bypass_incoming_modifiers or _buff_resolver == null:
		return 1.0
	var constraints: Dictionary = _buff_resolver.call("get_constraints", target)
	return maxf(0.0, float(constraints.get("incoming_damage_multiplier", 1.0)))


func _get_damage_type_multiplier(target: Node, damage_type: StringName) -> float:
	if target.has_method("get_damage_type_multiplier"):
		return maxf(0.0, float(target.call("get_damage_type_multiplier", damage_type)))
	return 1.0


func _get_health_component(target: Node) -> HealthComponent:
	if target.has_method("get_health_component"):
		var resolved: Variant = target.call("get_health_component")
		if resolved is HealthComponent:
			return resolved as HealthComponent
	return null


func _apply_hit_statuses(data: DamageEventData, target: Node) -> void:
	if _buff_resolver == null:
		return
	for status_id: StringName in data.status_ids_to_apply:
		_buff_resolver.call("apply_status_by_id", target, status_id, -1.0, data.attacker_id)


func _finish_resolution(result: DamageResolutionData) -> void:
	if result.target != null and result.target.has_method("on_damage_resolved"):
		result.target.call("on_damage_resolved", result)
	damage_resolved.emit(result)
	if _event_bus != null:
		_event_bus.combat_hit.emit(result.event)
		_event_bus.damage_resolved.emit(result)
