class_name PlayerInputReader
extends Node

var move_vector: Vector2 = Vector2.ZERO
var wants_sprint: bool = false
var wants_primary_attack: bool = false
var wants_aim: bool = false
var wants_interact: bool = false

var jump_buffered: bool = false
var slide_buffered: bool = false
var interact_buffered: bool = false
var primary_attack_buffered: bool = false
var secondary_attack_buffered: bool = false
var parry_buffered: bool = false
var shove_buffered: bool = false
var active_skill_buffered: bool = false
var reload_buffered: bool = false
var weapon_next_buffered: bool = false
var weapon_previous_buffered: bool = false
var watch_toggle_buffered: bool = false
var inventory_slot_buffered: int = -1
var inventory_drop_buffered: bool = false
var inventory_clear_selection_buffered: bool = false
var pause_buffered: bool = false


func refresh() -> void:
	move_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	wants_sprint = Input.is_action_pressed("sprint")
	wants_primary_attack = Input.is_action_pressed("attack_primary")
	wants_aim = Input.is_action_pressed("attack_secondary") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	wants_interact = Input.is_action_pressed("interact")


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffered = true
	if event.is_action_pressed("slide"):
		slide_buffered = true
	if event.is_action_pressed("interact"):
		interact_buffered = true
	if event.is_action_pressed("attack_primary"):
		primary_attack_buffered = true
	if event.is_action_pressed("attack_secondary"):
		secondary_attack_buffered = true
	if event.is_action_pressed("parry"):
		parry_buffered = true
	if event.is_action_pressed("shove"):
		shove_buffered = true
	if event.is_action_pressed("active_skill"):
		active_skill_buffered = true
	if event.is_action_pressed("reload"):
		reload_buffered = true
	if event.is_action_pressed("weapon_next"):
		weapon_next_buffered = true
	if event.is_action_pressed("weapon_previous"):
		weapon_previous_buffered = true
	if event.is_action_pressed("watch"):
		watch_toggle_buffered = true
	for slot_index: int in 4:
		if event.is_action_pressed("inventory_slot_%d" % (slot_index + 1)):
			inventory_slot_buffered = slot_index
	if event.is_action_pressed("inventory_drop"):
		inventory_drop_buffered = true
	if event.is_action_pressed("inventory_clear_selection"):
		inventory_clear_selection_buffered = true
	if event.is_action_pressed("pause"):
		pause_buffered = true


func consume_jump() -> bool:
	return _consume("jump_buffered")


func consume_slide() -> bool:
	return _consume("slide_buffered")


func consume_interact() -> bool:
	return _consume("interact_buffered")


func consume_primary_attack() -> bool:
	return _consume("primary_attack_buffered")


func consume_secondary_attack() -> bool:
	return _consume("secondary_attack_buffered")


func consume_parry() -> bool:
	return _consume("parry_buffered")


func consume_shove() -> bool:
	return _consume("shove_buffered")


func consume_active_skill() -> bool:
	return _consume("active_skill_buffered")


func consume_reload() -> bool:
	return _consume("reload_buffered")


func consume_weapon_next() -> bool:
	return _consume("weapon_next_buffered")


func consume_weapon_previous() -> bool:
	return _consume("weapon_previous_buffered")


func consume_watch_toggle() -> bool:
	return _consume("watch_toggle_buffered")


func consume_inventory_slot() -> int:
	var slot_index: int = inventory_slot_buffered
	inventory_slot_buffered = -1
	return slot_index


func consume_inventory_drop() -> bool:
	return _consume("inventory_drop_buffered")


func consume_inventory_clear_selection() -> bool:
	return _consume("inventory_clear_selection_buffered")


func consume_pause() -> bool:
	return _consume("pause_buffered")


func clear_action_buffers() -> void:
	jump_buffered = false
	slide_buffered = false
	interact_buffered = false
	primary_attack_buffered = false
	secondary_attack_buffered = false
	parry_buffered = false
	shove_buffered = false
	active_skill_buffered = false
	reload_buffered = false
	weapon_next_buffered = false
	weapon_previous_buffered = false
	watch_toggle_buffered = false
	inventory_slot_buffered = -1
	inventory_drop_buffered = false
	inventory_clear_selection_buffered = false
	pause_buffered = false


func _consume(property_name: StringName) -> bool:
	var was_buffered: bool = bool(get(property_name))
	set(property_name, false)
	return was_buffered
