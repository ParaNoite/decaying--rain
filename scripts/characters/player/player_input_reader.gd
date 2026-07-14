class_name PlayerInputReader
extends Node

var move_vector: Vector2 = Vector2.ZERO
var wants_sprint: bool = false
var wants_watch: bool = false
var wants_primary_attack: bool = false
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
var inventory_buffered: bool = false
var pause_buffered: bool = false


func refresh() -> void:
	move_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	wants_sprint = Input.is_action_pressed("sprint")
	wants_watch = Input.is_action_pressed("watch")
	wants_primary_attack = Input.is_action_pressed("attack_primary")
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
	if event.is_action_pressed("inventory"):
		inventory_buffered = true
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


func consume_inventory() -> bool:
	return _consume("inventory_buffered")


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
	inventory_buffered = false
	pause_buffered = false


func _consume(property_name: StringName) -> bool:
	var was_buffered: bool = bool(get(property_name))
	set(property_name, false)
	return was_buffered
