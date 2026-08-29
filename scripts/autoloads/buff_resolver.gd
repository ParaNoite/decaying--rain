extends Node

const DEFAULT_STATUS_CATALOG: StatusCatalog = preload("res://resources/gameplay/status_catalog.tres")

var status_catalog: StatusCatalog = DEFAULT_STATUS_CATALOG
var _event_bus: Node
var _bound_containers: Dictionary[int, bool] = {}


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")


func bind_container(target: Node, container: StatusContainer) -> void:
	if target == null or container == null:
		return
	var container_id: int = container.get_instance_id()
	if _bound_containers.has(container_id):
		return

	_bound_containers[container_id] = true
	container.status_applied.connect(_on_status_applied.bind(target))
	container.status_removed.connect(_on_status_removed.bind(target))
	container.status_list_changed.connect(_on_status_list_changed.bind(target))
	container.status_tick.connect(_on_status_tick.bind(target))
	container.tree_exited.connect(_on_container_exited.bind(container_id), CONNECT_ONE_SHOT)

	for status: StatusEffectDefinition in container.initial_statuses:
		apply_status(target, status)


func apply_status(
	target: Node,
	status: StatusEffectDefinition,
	duration_override: float = -1.0,
	source_id: int = 0,
) -> bool:
	var container: StatusContainer = get_status_container(target)
	if target == null or status == null or container == null:
		return false
	if target.has_method("is_status_immune") and bool(target.call("is_status_immune", status.status_id)):
		_emit_status_rejected(target, status.status_id, &"immune")
		return false

	var duration: float = duration_override if duration_override >= 0.0 else status.duration_seconds
	if not status.is_permanent_until_removed and target.has_method("get_status_duration_multiplier"):
		duration *= maxf(0.0, float(target.call("get_status_duration_multiplier", status.status_id)))
	return container.apply_resolved_status(status, duration, source_id)


func apply_status_by_id(
	target: Node,
	status_id: StringName,
	duration_override: float = -1.0,
	source_id: int = 0,
) -> bool:
	var definition: StatusEffectDefinition = get_definition(status_id)
	if definition == null:
		_emit_status_rejected(target, status_id, &"unknown_status")
		return false
	return apply_status(target, definition, duration_override, source_id)


func remove_status(target: Node, status_id: StringName) -> bool:
	var container: StatusContainer = get_status_container(target)
	return container != null and container.remove_resolved_status(status_id)


func clear_statuses(target: Node) -> void:
	var container: StatusContainer = get_status_container(target)
	if container != null:
		container.clear_resolved_statuses()


func has_status(target: Node, status_id: StringName) -> bool:
	var container: StatusContainer = get_status_container(target)
	return container != null and container.has_status(status_id)


func get_status_remaining(target: Node, status_id: StringName) -> float:
	var container: StatusContainer = get_status_container(target)
	return container.get_status_remaining(status_id) if container != null else 0.0


func get_definition(status_id: StringName) -> StatusEffectDefinition:
	if status_catalog == null:
		return null
	return status_catalog.get_definition(status_id)


func get_constraints(target: Node) -> Dictionary:
	var constraints: Dictionary = _default_constraints()
	var container: StatusContainer = get_status_container(target)
	if container != null:
		constraints.merge(container.get_constraints(), true)
	if target != null and target.has_method("amend_buff_constraints"):
		target.call("amend_buff_constraints", constraints)
	return constraints


func get_status_container(target: Node) -> StatusContainer:
	if target == null:
		return null
	if target is StatusContainer:
		return target as StatusContainer
	if target.has_method("get_status_container"):
		var resolved: Variant = target.call("get_status_container")
		if resolved is StatusContainer:
			return resolved as StatusContainer
	return null


func _on_status_applied(status_id: StringName, target: Node) -> void:
	if _event_bus != null and is_instance_valid(target):
		_event_bus.status_applied.emit(target.get_instance_id(), status_id)


func _on_status_removed(status_id: StringName, target: Node) -> void:
	if _event_bus != null and is_instance_valid(target):
		_event_bus.status_removed.emit(target.get_instance_id(), status_id)


func _on_status_list_changed(statuses: Array[Dictionary], target: Node) -> void:
	if _event_bus != null and is_instance_valid(target):
		_event_bus.status_list_changed.emit(target.get_instance_id(), statuses)


func _on_status_tick(
	status_id: StringName,
	source_id: int,
	damage_type: StringName,
	health_delta: float,
	stamina_delta: float,
	hunger_delta: float,
	target: Node,
) -> void:
	if not is_instance_valid(target):
		return

	if health_delta < 0.0:
		var damage_resolver: Node = get_node_or_null("/root/DamageResolver")
		if damage_resolver != null:
			var damage: DamageEventData = DamageEventData.new()
			damage.attacker_id = source_id
			damage.target_id = target.get_instance_id()
			damage.amount = -health_delta
			damage.damage_type = damage_type
			damage.source_tags = [&"status", status_id, &"periodic"]
			damage.bypass_outgoing_modifiers = true
			damage_resolver.call("resolve_damage", damage, target)
	elif health_delta > 0.0:
		var health: HealthComponent = _get_health_component(target)
		if health != null:
			health.heal(health_delta)

	var stamina: StaminaComponent = _get_stamina_component(target)
	if stamina != null:
		if stamina_delta >= 0.0:
			stamina.recover(stamina_delta)
		else:
			stamina.consume(-stamina_delta)

	var hunger: HungerComponent = _get_hunger_component(target)
	if hunger != null:
		if hunger_delta >= 0.0:
			hunger.restore_hunger(hunger_delta)
		else:
			hunger.consume_hunger(-hunger_delta)


func _get_health_component(target: Node) -> HealthComponent:
	if target != null and target.has_method("get_health_component"):
		var resolved: Variant = target.call("get_health_component")
		if resolved is HealthComponent:
			return resolved as HealthComponent
	return null


func _get_stamina_component(target: Node) -> StaminaComponent:
	if target != null and target.has_method("get_stamina_component"):
		var resolved: Variant = target.call("get_stamina_component")
		if resolved is StaminaComponent:
			return resolved as StaminaComponent
	return null


func _get_hunger_component(target: Node) -> HungerComponent:
	if target != null and target.has_method("get_hunger_component"):
		var resolved: Variant = target.call("get_hunger_component")
		if resolved is HungerComponent:
			return resolved as HungerComponent
	return null


func _emit_status_rejected(target: Node, status_id: StringName, reason_id: StringName) -> void:
	if _event_bus != null and target != null:
		_event_bus.status_rejected.emit(target.get_instance_id(), status_id, reason_id)


func _on_container_exited(container_id: int) -> void:
	_bound_containers.erase(container_id)


func _default_constraints() -> Dictionary:
	return {
		"movement_disabled": false,
		"combat_blocked": false,
		"interaction_blocked": false,
		"mobility_blocked": false,
		"outgoing_damage_multiplier": 1.0,
		"incoming_damage_multiplier": 1.0,
		"stamina_recovery_multiplier": 1.0,
		"movement_speed_multiplier": 1.0,
		"sprint_speed_multiplier": 1.0,
		"firearm_spread_multiplier": 1.0,
		"blocked_action_ids": [],
	}
