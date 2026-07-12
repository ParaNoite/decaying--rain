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


func _select_profession(next_profession: ProfessionDefinition) -> void:
	profession_definition = next_profession
	profession_selected.emit(profession_definition.profession_id)
	if _event_bus != null:
		_event_bus.player_perk_selected.emit(profession_definition.profession_id)
		_event_bus.debug_test_notice.emit("Perk selected: %s" % profession_definition.display_name, &"perk")
