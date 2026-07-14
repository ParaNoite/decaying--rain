class_name PlayerProfessionComponent
extends Node

signal profession_selected(profession_id: StringName)

@export var profession_definition: ProfessionDefinition

var _event_bus = null


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if profession_definition != null:
		_select_profession(profession_definition)


func get_active_skill() -> Resource:
	if profession_definition == null:
		return null
	return profession_definition.active_skill


func get_profession_id() -> StringName:
	if profession_definition == null:
		return &"none"
	return profession_definition.profession_id


func get_starting_weapon_ids() -> Array[StringName]:
	if profession_definition == null:
		return []
	return profession_definition.starting_weapon_ids.duplicate()


func get_starting_item_ids() -> Array[StringName]:
	if profession_definition == null:
		return []
	return profession_definition.starting_item_ids.duplicate()


func get_blocked_action_ids() -> Array[StringName]:
	var blocked: Array[StringName] = []
	for rule: PerkRuleDefinition in _rules():
		if rule.kind == PerkRuleDefinition.RuleKind.ACTION_BLOCK:
			for action_id: StringName in rule.action_ids:
				if not blocked.has(action_id):
					blocked.append(action_id)
		elif rule.kind == PerkRuleDefinition.RuleKind.ACTION_ALLOW:
			for action_id: StringName in rule.action_ids:
				blocked.erase(action_id)
	return blocked


func is_status_immune(status_id: StringName) -> bool:
	for rule: PerkRuleDefinition in _rules():
		if rule.kind == PerkRuleDefinition.RuleKind.STATUS_IMMUNITY and rule.status_ids.has(status_id):
			return true
	return false


func get_status_duration_multiplier(status_id: StringName) -> float:
	var result: float = 1.0
	for rule: PerkRuleDefinition in _rules():
		if rule.kind == PerkRuleDefinition.RuleKind.STATUS_VULNERABILITY and rule.status_ids.has(status_id):
			result *= rule.multiplier
	return maxf(0.0, result)


func get_stat_multiplier(stat_id: StringName) -> float:
	var result: float = 1.0
	if profession_definition == null:
		return result
	match stat_id:
		&"ammo_pickup":
			result *= profession_definition.ammo_pickup_multiplier
		&"firearm_stability":
			result *= profession_definition.firearm_stability_multiplier
		_:
			pass
	for rule: PerkRuleDefinition in _rules():
		if rule.kind == PerkRuleDefinition.RuleKind.STAT_MODIFIER and rule.stat_id == stat_id:
			result *= rule.multiplier
	return maxf(0.0, result)


func get_stat_flat_bonus(stat_id: StringName) -> float:
	var result: float = 0.0
	for rule: PerkRuleDefinition in _rules():
		if rule.kind == PerkRuleDefinition.RuleKind.STAT_MODIFIER and rule.stat_id == stat_id:
			result += rule.flat_bonus
	return result


func _rules() -> Array[PerkRuleDefinition]:
	var result: Array[PerkRuleDefinition] = []
	if profession_definition == null:
		return result
	var raw_rules: Array[Resource] = profession_definition.advantages + profession_definition.disadvantages
	for resource: Resource in raw_rules:
		if resource is PerkRuleDefinition:
			result.append(resource as PerkRuleDefinition)
	return result


func _select_profession(next_profession: ProfessionDefinition) -> void:
	profession_definition = next_profession
	profession_selected.emit(profession_definition.profession_id)
	if _event_bus != null:
		_event_bus.player_perk_selected.emit(profession_definition.profession_id)
		_event_bus.debug_test_notice.emit("Perk selected: %s" % profession_definition.display_name, &"perk")
