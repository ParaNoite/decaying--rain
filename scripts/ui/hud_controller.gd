class_name HudController
extends CanvasLayer

@onready var phase_label: Label = %PhaseLabel
@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_label: Label = %StaminaLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var hunger_label: Label = %HungerLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var core_label: Label = %CoreLabel
@onready var perk_label: Label = %PerkLabel
@onready var skill_label: Label = %SkillLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var status_row: HFlowContainer = %StatusRow
@onready var status_empty_label: Label = %StatusEmptyLabel
@onready var gameplay_top_left: VBoxContainer = $Root/TopLeft
@onready var prompt_label: Label = %PromptLabel
@onready var status_dock: VBoxContainer = $Root/StatusDock
@onready var debug_notice_stack: VBoxContainer = %DebugNoticeStack
@onready var quick_slots: VBoxContainer = $Root/QuickSlots
@onready var combat_banner_label: Label = %CombatBannerLabel
@onready var watch_panel: Control = %WatchPanel
@onready var watch_status_page: Control = %WatchStatusPage
@onready var watch_supplies_page: Control = %WatchSuppliesPage
@onready var watch_tab_status: Button = %WatchTabStatus
@onready var watch_tab_supplies: Button = %WatchTabSupplies
@onready var watch_phase_label: Label = %WatchPhaseLabel
@onready var watch_timer_label: Label = %WatchTimerLabel
@onready var watch_status_label: Label = %WatchStatusLabel
@onready var watch_map: WatchTacticalMap = %WatchMap
@onready var watch_location_label: Label = %WatchLocationLabel
@onready var watch_ammo_light_label: Label = %WatchAmmoLightLabel
@onready var watch_ammo_rifle_label: Label = %WatchAmmoRifleLabel
@onready var watch_ammo_shells_label: Label = %WatchAmmoShellsLabel
@onready var watch_food_count_label: Label = %WatchFoodCountLabel
@onready var watch_eat_food_button: Button = %WatchEatFoodButton
@onready var quick_slot_labels: Array[Label] = [%QuickSlot1, %QuickSlot2, %QuickSlot3, %QuickSlot4]
@onready var death_label: Label = %DeathLabel
@onready var crosshair: Label = $Root/Crosshair
@onready var hit_marker: HitMarker = %HitMarker
@onready var item_use_progress: ProgressBar = %ItemUseProgress
@onready var item_use_label: Label = %ItemUseLabel

const MAX_DEBUG_NOTICE_COUNT: int = 5

var _event_bus = null
var _combat_banner_tween: Tween
var _watch_transition_tween: Tween
var _perk_display_name: String = "--"
var _skill_display_name: String = "--"
var _skill_id: StringName = &"none"
var _skill_cooldown_remaining: float = 0.0
var _special_inventory_items: Dictionary = {}
var _active_statuses: Array[Dictionary] = []
var _selected_inventory_slot: int = 0
var _watch_phase: StringName = &"none"
var _item_use_active: bool = false
var _combat_banner_active: bool = false


func _process(_delta: float) -> void:
	var player: Player3DController = get_tree().get_first_node_in_group("player") as Player3DController
	if player != null:
		crosshair.visible = gameplay_top_left.visible and player.combat_driver.aim_fraction < 0.5
	if watch_panel.visible:
		watch_location_label.text = "LOCATION // %s" % watch_map.get_region_name()


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus == null:
		return

	_event_bus.phase_changed.connect(_on_phase_changed)
	_event_bus.player_health_changed.connect(_on_player_health_changed)
	_event_bus.player_stamina_changed.connect(_on_player_stamina_changed)
	_event_bus.hunger_changed.connect(_on_hunger_changed)
	_event_bus.base_core_health_changed.connect(_on_base_core_health_changed)
	_event_bus.resource_looted.connect(_on_resource_looted)
	_event_bus.loot_container_opened.connect(_on_loot_container_opened)
	_event_bus.world_item_picked_up.connect(_on_world_item_picked_up)
	_event_bus.item_used.connect(_on_item_used)
	_event_bus.inventory_changed.connect(_on_inventory_changed)
	_event_bus.special_inventory_changed.connect(_on_special_inventory_changed)
	_event_bus.inventory_selection_changed.connect(_on_inventory_selection_changed)
	_event_bus.item_use_progress.connect(_on_item_use_progress)
	_event_bus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	_event_bus.player_perk_selected.connect(_on_player_perk_selected)
	_event_bus.player_active_skill_changed.connect(_on_player_active_skill_changed)
	_event_bus.player_action_blocked.connect(_on_player_action_blocked)
	_event_bus.player_weapon_changed.connect(_on_player_weapon_changed)
	_event_bus.player_ammo_changed.connect(_on_player_ammo_changed)
	_event_bus.status_list_changed.connect(_on_status_list_changed)
	_event_bus.debug_test_notice.connect(_on_debug_test_notice)
	_event_bus.combat_feedback.connect(_on_combat_feedback)
	_event_bus.damage_resolved.connect(_on_damage_resolved)
	_event_bus.watch_state_changed.connect(_on_watch_state_changed)
	_event_bus.wave_timer_changed.connect(_on_wave_timer_changed)
	_event_bus.player_died.connect(_on_player_died)
	_event_bus.enemy_spawned.connect(_on_enemy_spawned)
	_event_bus.enemy_died.connect(_on_enemy_died)
	watch_tab_status.pressed.connect(_show_status_page)
	watch_tab_supplies.pressed.connect(_show_supplies_page)
	watch_eat_food_button.pressed.connect(_request_watch_item_use.bind(&"food_ration"))
	_show_status_page()
	_sync_initial_values()


func _exit_tree() -> void:
	if _event_bus == null:
		return
	if _event_bus.phase_changed.is_connected(_on_phase_changed):
		_event_bus.phase_changed.disconnect(_on_phase_changed)
	if _event_bus.player_health_changed.is_connected(_on_player_health_changed):
		_event_bus.player_health_changed.disconnect(_on_player_health_changed)
	if _event_bus.player_stamina_changed.is_connected(_on_player_stamina_changed):
		_event_bus.player_stamina_changed.disconnect(_on_player_stamina_changed)
	if _event_bus.hunger_changed.is_connected(_on_hunger_changed):
		_event_bus.hunger_changed.disconnect(_on_hunger_changed)
	if _event_bus.base_core_health_changed.is_connected(_on_base_core_health_changed):
		_event_bus.base_core_health_changed.disconnect(_on_base_core_health_changed)
	if _event_bus.resource_looted.is_connected(_on_resource_looted):
		_event_bus.resource_looted.disconnect(_on_resource_looted)
	if _event_bus.loot_container_opened.is_connected(_on_loot_container_opened):
		_event_bus.loot_container_opened.disconnect(_on_loot_container_opened)
	if _event_bus.world_item_picked_up.is_connected(_on_world_item_picked_up):
		_event_bus.world_item_picked_up.disconnect(_on_world_item_picked_up)
	if _event_bus.item_used.is_connected(_on_item_used):
		_event_bus.item_used.disconnect(_on_item_used)
	if _event_bus.inventory_changed.is_connected(_on_inventory_changed):
		_event_bus.inventory_changed.disconnect(_on_inventory_changed)
	if _event_bus.special_inventory_changed.is_connected(_on_special_inventory_changed):
		_event_bus.special_inventory_changed.disconnect(_on_special_inventory_changed)
	if _event_bus.inventory_selection_changed.is_connected(_on_inventory_selection_changed):
		_event_bus.inventory_selection_changed.disconnect(_on_inventory_selection_changed)
	if _event_bus.item_use_progress.is_connected(_on_item_use_progress):
		_event_bus.item_use_progress.disconnect(_on_item_use_progress)
	if _event_bus.interaction_prompt_changed.is_connected(_on_interaction_prompt_changed):
		_event_bus.interaction_prompt_changed.disconnect(_on_interaction_prompt_changed)
	if _event_bus.player_perk_selected.is_connected(_on_player_perk_selected):
		_event_bus.player_perk_selected.disconnect(_on_player_perk_selected)
	if _event_bus.player_active_skill_changed.is_connected(_on_player_active_skill_changed):
		_event_bus.player_active_skill_changed.disconnect(_on_player_active_skill_changed)
	if _event_bus.player_action_blocked.is_connected(_on_player_action_blocked):
		_event_bus.player_action_blocked.disconnect(_on_player_action_blocked)
	if _event_bus.player_weapon_changed.is_connected(_on_player_weapon_changed):
		_event_bus.player_weapon_changed.disconnect(_on_player_weapon_changed)
	if _event_bus.player_ammo_changed.is_connected(_on_player_ammo_changed):
		_event_bus.player_ammo_changed.disconnect(_on_player_ammo_changed)
	if _event_bus.status_list_changed.is_connected(_on_status_list_changed):
		_event_bus.status_list_changed.disconnect(_on_status_list_changed)
	if _event_bus.debug_test_notice.is_connected(_on_debug_test_notice):
		_event_bus.debug_test_notice.disconnect(_on_debug_test_notice)
	if _event_bus.combat_feedback.is_connected(_on_combat_feedback):
		_event_bus.combat_feedback.disconnect(_on_combat_feedback)
	if _event_bus.damage_resolved.is_connected(_on_damage_resolved):
		_event_bus.damage_resolved.disconnect(_on_damage_resolved)
	if _event_bus.watch_state_changed.is_connected(_on_watch_state_changed):
		_event_bus.watch_state_changed.disconnect(_on_watch_state_changed)
	if _event_bus.wave_timer_changed.is_connected(_on_wave_timer_changed):
		_event_bus.wave_timer_changed.disconnect(_on_wave_timer_changed)
	if _event_bus.player_died.is_connected(_on_player_died):
		_event_bus.player_died.disconnect(_on_player_died)
	if _event_bus.enemy_spawned.is_connected(_on_enemy_spawned):
		_event_bus.enemy_spawned.disconnect(_on_enemy_spawned)
	if _event_bus.enemy_died.is_connected(_on_enemy_died):
		_event_bus.enemy_died.disconnect(_on_enemy_died)


func _on_phase_changed(_previous_phase: StringName, current_phase: StringName, wave_index: int) -> void:
	phase_label.text = "Wave %d / %s" % [wave_index, String(current_phase)]
	_watch_phase = current_phase
	watch_phase_label.text = "WAVE %d  //  %s" % [wave_index, _display_name_from_id(current_phase).to_upper()]


func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP %.0f / %.0f" % [current, maximum]
	health_bar.max_value = maximum
	health_bar.value = current


func _on_player_stamina_changed(current: float, maximum: float) -> void:
	stamina_label.text = "STA %.0f / %.0f" % [current, maximum]
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_hunger_changed(current: float, maximum: float) -> void:
	hunger_label.text = "FOOD %.0f / %.0f" % [current, maximum]
	hunger_bar.max_value = maximum
	hunger_bar.value = current


func _on_base_core_health_changed(current: float, maximum: float) -> void:
	core_label.text = "CORE %.0f / %.0f" % [current, maximum]


func _on_resource_looted(resource_id: StringName, payload: Dictionary) -> void:
	_on_debug_test_notice("Picked up %s: %s" % [String(resource_id), str(payload)], &"loot")


func _on_loot_container_opened(container_id: StringName, payload: Dictionary) -> void:
	_on_debug_test_notice("Opened %s: %s" % [String(container_id), str(payload)], &"loot")


func _on_world_item_picked_up(item_id: StringName, quantity: int) -> void:
	_on_debug_test_notice("Picked up %s x%d" % [_item_display_name(item_id), quantity], &"loot")


func _on_item_used(item_id: StringName, _quantity: int) -> void:
	_on_debug_test_notice("Used %s" % _item_display_name(item_id), &"inventory")


func _on_interaction_prompt_changed(prompt: String) -> void:
	prompt_label.text = prompt
	prompt_label.visible = not watch_panel.visible and not prompt.is_empty()


func _on_player_perk_selected(perk_id: StringName) -> void:
	_perk_display_name = _display_name_from_id(perk_id)
	_update_skill_panel()


func _on_player_active_skill_changed(skill_id: StringName, cooldown_remaining: float, _charges: int) -> void:
	_skill_id = skill_id
	_skill_display_name = _skill_display_name_for_id(skill_id)
	_skill_cooldown_remaining = cooldown_remaining
	_update_skill_panel()


func _on_player_action_blocked(action_id: StringName, reason_id: StringName) -> void:
	_on_debug_test_notice(
		"%s blocked: %s" % [_display_name_from_id(action_id), _display_name_from_id(reason_id)],
		&"blocked"
	)


func _on_player_weapon_changed(weapon_id: StringName) -> void:
	weapon_label.text = "WEAPON %s" % _display_name_from_id(weapon_id).to_upper()


func _on_player_ammo_changed(current: int, reserve: int) -> void:
	ammo_label.text = "AMMO %d / %d" % [current, reserve]


func _on_inventory_changed(items: Dictionary) -> void:
	_refresh_quick_slots()


func _on_special_inventory_changed(items: Dictionary) -> void:
	_special_inventory_items = items.duplicate(true)
	watch_ammo_light_label.text = "LIGHT AMMO  //  %d" % _get_special_quantity(&"light_ammo")
	watch_ammo_rifle_label.text = "RIFLE AMMO  //  %d" % _get_special_quantity(&"rifle_ammo")
	watch_ammo_shells_label.text = "SHELLS  //  %d" % _get_special_quantity(&"shells")
	var food_quantity: int = _get_special_quantity(&"food_ration")
	watch_food_count_label.text = "FOOD RATION  //  %d" % food_quantity
	watch_eat_food_button.disabled = food_quantity <= 0


func _on_inventory_selection_changed(slot_index: int) -> void:
	_selected_inventory_slot = slot_index
	_refresh_quick_slots()


func _on_item_use_progress(item_id: StringName, progress: float, active: bool) -> void:
	_item_use_active = active
	item_use_progress.visible = active and not watch_panel.visible
	item_use_label.visible = active and not watch_panel.visible
	if not active:
		item_use_progress.value = 0.0
		return
	item_use_label.text = "USING %s" % _item_display_name(item_id).to_upper()
	item_use_progress.value = clampf(progress, 0.0, 1.0) * 100.0


func _request_watch_item_use(item_id: StringName) -> void:
	if _event_bus != null:
		_event_bus.watch_item_use_requested.emit(item_id)


func _show_status_page() -> void:
	watch_status_page.visible = true
	watch_supplies_page.visible = false
	watch_tab_status.set_pressed_no_signal(true)
	watch_tab_supplies.set_pressed_no_signal(false)
	if _event_bus != null:
		_event_bus.ui_audio.emit(&"watch.click.valid")


func _show_supplies_page() -> void:
	watch_status_page.visible = false
	watch_supplies_page.visible = true
	watch_tab_status.set_pressed_no_signal(false)
	watch_tab_supplies.set_pressed_no_signal(true)
	if _event_bus != null:
		_event_bus.ui_audio.emit(&"watch.click.valid")


func _on_status_list_changed(target_id: int, statuses: Array[Dictionary]) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and target_id != player.get_instance_id():
		return
	_active_statuses = statuses.duplicate(true)
	var text: String = _format_statuses(_active_statuses)
	_render_status_dock(_active_statuses)
	watch_status_label.text = "CONDITIONS\n%s" % text


func _on_debug_test_notice(message: String, category: StringName) -> void:
	if debug_notice_stack == null:
		return

	var notice_label: Label = Label.new()
	notice_label.text = "[TEST %s] %s" % [String(category).to_upper(), message]
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	notice_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	notice_label.add_theme_constant_override("shadow_offset_x", 1)
	notice_label.add_theme_constant_override("shadow_offset_y", 1)
	debug_notice_stack.add_child(notice_label)

	_trim_debug_notices()

	var notice_ref: WeakRef = weakref(notice_label)
	get_tree().create_timer(3.0).timeout.connect(_remove_debug_notice.bind(notice_ref), CONNECT_ONE_SHOT)


func _on_combat_feedback(message: String, tone: StringName) -> void:
	if combat_banner_label == null:
		return

	if _combat_banner_tween != null:
		_combat_banner_tween.kill()

	combat_banner_label.text = message
	_combat_banner_active = true
	combat_banner_label.visible = not watch_panel.visible
	combat_banner_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	match tone:
		&"success":
			combat_banner_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45, 1.0))
		&"danger":
			combat_banner_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.18, 1.0))
		_:
			combat_banner_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))

	_combat_banner_tween = create_tween()
	_combat_banner_tween.tween_interval(0.55)
	_combat_banner_tween.tween_property(combat_banner_label, "modulate:a", 0.0, 0.35)
	_combat_banner_tween.tween_callback(_hide_combat_banner)


func _on_damage_resolved(result: DamageResolutionData) -> void:
	if not _is_player_enemy_melee_resolution(result):
		return
	if not watch_panel.visible and gameplay_top_left.visible:
		hit_marker.show_hit()


func _on_watch_state_changed(active: bool) -> void:
	var timing: ActionTimingDefinition = _get_watch_timing()
	if active:
		_set_gameplay_hud_visible(false)
		_show_watch_projection(timing)
	else:
		_hide_watch_projection(timing)
	if not active:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	watch_map.set_player(player)
	watch_location_label.text = "LOCATION // %s" % watch_map.get_region_name()


func _show_watch_projection(timing: ActionTimingDefinition) -> void:
	if _watch_transition_tween != null:
		_watch_transition_tween.kill()
	watch_panel.visible = true
	watch_panel.pivot_offset = watch_panel.size * 0.5
	watch_panel.scale = Vector2(0.035, 0.035)
	watch_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_watch_transition_tween = create_tween()
	_watch_transition_tween.tween_interval(timing.windup_seconds)
	_watch_transition_tween.tween_property(watch_panel, "scale", Vector2.ONE, timing.release_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_watch_transition_tween.parallel().tween_property(watch_panel, "modulate:a", 1.0, timing.release_seconds)


func _hide_watch_projection(timing: ActionTimingDefinition) -> void:
	if _watch_transition_tween != null:
		_watch_transition_tween.kill()
	if not watch_panel.visible:
		_set_gameplay_hud_visible(true)
		return
	watch_panel.pivot_offset = watch_panel.size * 0.5
	_watch_transition_tween = create_tween().set_parallel(true)
	_watch_transition_tween.tween_property(watch_panel, "scale", Vector2(0.035, 0.035), timing.release_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_watch_transition_tween.tween_property(watch_panel, "modulate:a", 0.0, timing.release_seconds)
	_watch_transition_tween.chain().tween_callback(_complete_watch_close)


func _complete_watch_close() -> void:
	watch_panel.hide()
	watch_panel.scale = Vector2.ONE
	watch_panel.modulate = Color.WHITE
	_set_gameplay_hud_visible(true)


func _get_watch_timing() -> ActionTimingDefinition:
	var player: Player3DController = get_tree().get_first_node_in_group("player") as Player3DController
	if player != null and player.combat_definition != null and player.combat_definition.watch_timing != null:
		return player.combat_definition.watch_timing
	return ActionTimingDefinition.new()


func _set_gameplay_hud_visible(visible: bool) -> void:
	gameplay_top_left.visible = visible
	status_dock.visible = visible
	debug_notice_stack.visible = visible
	quick_slots.visible = visible
	crosshair.visible = visible
	if not visible:
		hit_marker.hide()
	prompt_label.visible = visible and not prompt_label.text.is_empty()
	item_use_progress.visible = visible and _item_use_active
	item_use_label.visible = visible and _item_use_active
	combat_banner_label.visible = visible and _combat_banner_active


func _is_player_enemy_melee_resolution(result: DamageResolutionData) -> bool:
	if result == null or not result.applied or result.blocked or result.event == null:
		return false
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or result.event.attacker_id != player.get_instance_id():
		return false
	if result.target == null or not result.target.is_in_group("enemy"):
		return false
	return result.event.source_tags.has(&"melee") or result.event.source_tags.has(&"shove")


func _hide_combat_banner() -> void:
	_combat_banner_active = false
	combat_banner_label.hide()


func _on_wave_timer_changed(remaining_seconds: float, total_seconds: float, wave_index: int) -> void:
	watch_phase_label.text = "WAVE %d  //  %s" % [wave_index, _display_name_from_id(_watch_phase).to_upper()]
	watch_timer_label.text = "%s  /  %s" % [_format_clock(remaining_seconds), _format_clock(total_seconds)]


func _on_player_died(reason: StringName) -> void:
	death_label.text = "Death: %s" % String(reason)
	death_label.visible = true


func _on_enemy_spawned(enemy_id: StringName, _instance_id: int, wave_index: int) -> void:
	_on_debug_test_notice("Spawned %s in wave %d" % [String(enemy_id), wave_index], &"enemy")


func _on_enemy_died(enemy_id: StringName, _instance_id: int, wave_index: int) -> void:
	_on_debug_test_notice("Defeated %s in wave %d" % [String(enemy_id), wave_index], &"enemy")


func _update_skill_panel() -> void:
	if perk_label != null:
		perk_label.text = "PERK %s" % _perk_display_name.to_upper()

	if skill_label == null:
		return

	if _skill_id == &"none":
		skill_label.text = "SKILL --"
		skill_label.add_theme_color_override("font_color", Color(0.56, 0.86, 1.0, 1.0))
		return

	if _skill_cooldown_remaining > 0.05:
		skill_label.text = "SKILL %s %.1fs" % [_skill_display_name.to_upper(), _skill_cooldown_remaining]
		skill_label.add_theme_color_override("font_color", Color(0.55, 0.72, 0.84, 1.0))
	else:
		skill_label.text = "SKILL %s READY" % _skill_display_name.to_upper()
		skill_label.add_theme_color_override("font_color", Color(0.30, 1.0, 0.95, 1.0))


func _remove_debug_notice(notice_ref: WeakRef) -> void:
	if notice_ref == null:
		return

	var notice: Object = notice_ref.get_ref()
	if not (notice is Label):
		return

	var notice_label: Label = notice as Label
	if notice_label.get_parent() == debug_notice_stack:
		debug_notice_stack.remove_child(notice_label)
	notice_label.queue_free()


func _trim_debug_notices() -> void:
	while debug_notice_stack.get_child_count() > MAX_DEBUG_NOTICE_COUNT:
		var oldest_notice: Node = debug_notice_stack.get_child(0)
		debug_notice_stack.remove_child(oldest_notice)
		oldest_notice.queue_free()


func _sync_initial_values() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		var player_health: HealthComponent = player.get_node_or_null("Components/HealthComponent") as HealthComponent
		if player_health != null:
			_on_player_health_changed(player_health.current_health, player_health.max_health)

		var player_stamina: StaminaComponent = player.get_node_or_null("Components/StaminaComponent") as StaminaComponent
		if player_stamina != null:
			_on_player_stamina_changed(player_stamina.current_stamina, player_stamina.max_stamina)

		var player_hunger: HungerComponent = player.get_node_or_null("Components/HungerComponent") as HungerComponent
		if player_hunger != null:
			_on_hunger_changed(player_hunger.current_hunger, player_hunger.max_hunger)

		_sync_player_skill_values(player)

		var loadout: PlayerLoadoutComponent = player.get_node_or_null("Components/PlayerLoadoutComponent") as PlayerLoadoutComponent
		if loadout != null:
			var weapon: WeaponDefinition = loadout.get_current_weapon()
			if weapon != null:
				_on_player_weapon_changed(weapon.weapon_id)
			_on_player_ammo_changed(loadout.get_magazine_ammo(), loadout.get_reserve_ammo())

		var inventory: PlayerInventoryComponent = player.get_node_or_null("Components/PlayerInventoryComponent") as PlayerInventoryComponent
		if inventory != null:
			_on_inventory_changed(inventory.get_items())
			_on_special_inventory_changed(inventory.get_special_items())

		var statuses: StatusContainer = player.get_node_or_null("Components/StatusContainer") as StatusContainer
		if statuses != null:
			_on_status_list_changed(player.get_instance_id(), statuses.get_active_statuses())

	var base_core: Node = get_tree().get_first_node_in_group("base_core")
	if base_core != null:
		var core_health: HealthComponent = base_core.get_node_or_null("HealthComponent") as HealthComponent
		if core_health != null:
			_on_base_core_health_changed(core_health.current_health, core_health.max_health)

	_update_skill_panel()


func _sync_player_skill_values(player: Node) -> void:
	var profession_component: Node = player.get_node_or_null("Components/ProfessionComponent")
	if profession_component != null and profession_component.has_method("get_profession_id"):
		_perk_display_name = _display_name_from_id(profession_component.get_profession_id())
		if profession_component.has_method("get_active_skill"):
			var active_skill: Resource = profession_component.get_active_skill()
			if active_skill != null:
				_skill_id = active_skill.skill_id
				_skill_display_name = active_skill.display_name

	var skill_component: Node = player.get_node_or_null("Components/PlayerSkillComponent")
	if skill_component != null:
		_skill_cooldown_remaining = float(skill_component.get("cooldown_remaining"))


func _display_name_from_id(value: StringName) -> String:
	if value == &"none" or String(value).is_empty():
		return "--"
	var words: PackedStringArray = String(value).replace("_", " ").split(" ", false)
	for index: int in words.size():
		words[index] = words[index].capitalize()
	return " ".join(words)


func _skill_display_name_for_id(skill_id: StringName) -> String:
	if skill_id == &"none":
		return "--"

	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		var profession_component: Node = player.get_node_or_null("Components/ProfessionComponent")
		if profession_component != null and profession_component.has_method("get_active_skill"):
			var active_skill: Resource = profession_component.get_active_skill()
			if active_skill != null and active_skill.skill_id == skill_id:
				return active_skill.display_name

	return _display_name_from_id(skill_id)


func _get_special_quantity(item_id: StringName) -> int:
	return int(_special_inventory_items.get(item_id, 0))


func _format_clock(seconds: float) -> String:
	var total_seconds: int = maxi(0, ceili(seconds))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _item_display_name(item_id: StringName) -> String:
	var item: ItemDefinition = _get_item_definition(item_id)
	return item.display_name if item != null else _display_name_from_id(item_id)


func _get_item_definition(item_id: StringName) -> ItemDefinition:
	var inventory: PlayerInventoryComponent = _get_player_inventory()
	return inventory.get_item_definition(item_id) if inventory != null else null


func _get_player_inventory() -> PlayerInventoryComponent:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Components/PlayerInventoryComponent") as PlayerInventoryComponent


func _refresh_quick_slots() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var inventory: PlayerInventoryComponent = player.get_node_or_null("Components/PlayerInventoryComponent") as PlayerInventoryComponent
	if inventory == null:
		return
	var slots: Array[Dictionary] = inventory.get_slot_snapshots()
	for index: int in quick_slot_labels.size():
		var label: Label = quick_slot_labels[index]
		if label == null:
			continue
		var snapshot: Dictionary = slots[index] if index < slots.size() else {}
		var item_id: StringName = StringName(snapshot.get("item_id", &""))
		var quantity: int = int(snapshot.get("quantity", 0))
		var prefix: String = ">" if index == _selected_inventory_slot else " "
		var contents: String = "Empty"
		if item_id != &"" and quantity > 0:
			contents = "%s x%d" % [_item_display_name(item_id), quantity]
		label.text = "%s %d  %s" % [prefix, index + 1, contents]


func _format_statuses(statuses: Array[Dictionary]) -> String:
	if statuses.is_empty():
		return "STATUS CLEAR"
	var lines: PackedStringArray = []
	for status: Dictionary in statuses:
		var remaining: float = float(status.get("remaining_seconds", -1.0))
		var duration_text: String = "PERM" if remaining < 0.0 else "%.1fs" % remaining
		var stack_count: int = int(status.get("stack_count", 1))
		var stack_text: String = " x%d" % stack_count if stack_count > 1 else ""
		lines.append("%s%s  %s" % [String(status.get("display_name", "Status")).to_upper(), stack_text, duration_text])
	return "\n".join(lines)


func _render_status_dock(statuses: Array[Dictionary]) -> void:
	if status_row == null or status_empty_label == null:
		return
	for child: Node in status_row.get_children():
		status_row.remove_child(child)
		child.queue_free()
	status_empty_label.visible = statuses.is_empty()
	for status: Dictionary in statuses:
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(154.0, 42.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _make_status_style(status))
		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = _format_status_dock_entry(status)
		label.add_theme_color_override("font_color", _status_color(status))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.95))
		label.add_theme_constant_override("outline_size", 2)
		panel.add_child(label)
		status_row.add_child(panel)


func _format_status_dock_entry(status: Dictionary) -> String:
	var remaining: float = float(status.get("remaining_seconds", -1.0))
	var duration_text: String = "持续" if remaining < 0.0 else "%.0f 秒" % ceilf(remaining)
	return "%s\n%s" % [String(status.get("display_name", "状态")).to_upper(), duration_text]


func _status_color(status: Dictionary) -> Color:
	var category: int = int(status.get("category", StatusEffectDefinition.StatusCategory.BUFF))
	match category:
		StatusEffectDefinition.StatusCategory.BUFF, StatusEffectDefinition.StatusCategory.PROFESSION:
			return Color(0.56, 0.94, 0.75, 1.0)
		_:
			return Color(1.0, 0.58, 0.48, 1.0)


func _make_status_style(status: Dictionary) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var accent: Color = _status_color(status)
	style.bg_color = Color(0.03, 0.05, 0.07, 0.88)
	style.border_color = Color(accent, 0.68)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 4.0
	return style
