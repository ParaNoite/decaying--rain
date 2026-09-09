extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")


func _ready() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	add_child(player)
	await get_tree().process_frame
	var hud: HudController = HUD_SCENE.instantiate() as HudController
	add_child(hud)
	await get_tree().process_frame

	_check(not player.watch_state_machine.is_active(), "watch should begin closed")
	var watch_timing: ActionTimingDefinition = player.combat_definition.watch_timing
	_press_key(player, KEY_TAB)
	await get_tree().process_frame
	_check(player.watch_state_machine.is_active() and hud.watch_panel.visible, "watch toggle did not open the persistent HUD")
	_check(not hud.gameplay_top_left.visible and not hud.crosshair.visible, "regular HUD remained visible behind the watch")
	_check(hud.watch_panel.scale.x < 0.1, "watch projection did not begin from a center point")
	_check(bool(player.watch_state_machine.update().get("watch_active", false)), "open watch did not expose gameplay constraints")
	await get_tree().create_timer(watch_timing.windup_seconds + watch_timing.release_seconds + 0.02).timeout
	_check(hud.watch_panel.scale.is_equal_approx(Vector2.ONE), "watch projection did not expand after the hand raise")
	_check(player.first_person_arms.is_watch_pose_active(), "left hand did not remain raised while the watch was open")
	_press_key(player, KEY_TAB)
	_check(not player.watch_state_machine.is_active(), "second Tab press did not close the watch")
	_check(not hud.gameplay_top_left.visible, "regular HUD returned before the projection closed")
	await get_tree().create_timer(watch_timing.release_seconds + 0.02).timeout
	_check(not hud.watch_panel.visible and hud.gameplay_top_left.visible and hud.crosshair.visible, "regular HUD did not return after closing the watch")
	_check(player.first_person_arms.is_watch_pose_active(), "hand lowered before the projection finished closing")
	await get_tree().create_timer(watch_timing.recovery_seconds + 0.02).timeout
	_check(not player.first_person_arms.is_watch_pose_active(), "hand did not lower after the watch close recovery")
	_press_key(player, KEY_TAB)
	_press_key(player, KEY_ESCAPE)
	await get_tree().create_timer(watch_timing.release_seconds + 0.02).timeout
	_check(not player.watch_state_machine.is_active(), "Escape did not close the watch")
	_press_key(player, KEY_TAB)
	await get_tree().create_timer(watch_timing.windup_seconds + watch_timing.release_seconds + 0.02).timeout
	await get_tree().process_frame
	_check(hud.watch_map.get_region_name() == "BASE COURTYARD", "base position did not resolve on tactical map")
	player.global_position = Vector3(0.0, 0.0, -45.0)
	await get_tree().process_frame
	_check(hud.watch_map.get_region_name() == "SCAVENGE AREA", "scavenge position did not resolve on tactical map")
	player.global_position = Vector3(80.0, 0.0, -120.0)
	player.rotation.y = PI * 0.5
	await get_tree().process_frame
	_check(hud.watch_map.get_player_map_position() == Vector2(1.0, 0.0), "out-of-bounds map marker was not clamped")
	_check(hud.watch_map.get_player_heading().is_equal_approx(Vector2(-1.0, 0.0)), "map marker did not follow player heading")
	hud._on_phase_changed(&"daylight", &"rain", 2)
	hud._on_wave_timer_changed(65.0, 120.0, 2)
	_check(hud.watch_timer_label.text == "01:05  /  02:00", "watch timer did not use clock format")
	hud.watch_tab_supplies.emit_signal("pressed")
	_check(hud.watch_supplies_page.visible and not hud.watch_status_page.visible, "supplies tab did not switch pages")

	player.hunger.set_hunger(40.0)
	_check(player.inventory_component.add_item(&"food_ration"), "food ration could not be added")
	await get_tree().process_frame
	_check(not hud.watch_eat_food_button.disabled, "food use button remained disabled with a ration")
	hud.watch_eat_food_button.emit_signal("pressed")
	_check(not player.watch_state_machine.is_active(), "using food did not close the watch")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.impact_start_seconds())
	_check(player.inventory_component.get_quantity(&"food_ration") == 0, "food was not consumed at the use impact")
	_check(is_equal_approx(player.hunger.current_hunger, 75.0), "food did not restore hunger")
	_check(not InputMap.has_action(&"inventory"), "legacy I-key inventory action still exists")

	print("WATCH_HUD_SMOKE: PASS")
	get_tree().quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("WATCH_HUD_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)


func _press_key(player: Player3DController, keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	if player.watch_state_machine.is_active():
		# Open-watch close keys are consumed before Control focus navigation.
		player._input(event)
	else:
		player._unhandled_input(event)
		player._update_watch_state()
