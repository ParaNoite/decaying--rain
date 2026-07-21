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
@onready var status_label: Label = %StatusLabel
@onready var prompt_label: Label = %PromptLabel
@onready var debug_notice_stack: VBoxContainer = %DebugNoticeStack
@onready var combat_banner_label: Label = %CombatBannerLabel
@onready var watch_panel: Control = %WatchPanel
@onready var watch_wave_label: Label = %WatchWaveLabel
@onready var watch_timer_label: Label = %WatchTimerLabel
@onready var watch_status_label: Label = %WatchStatusLabel
@onready var watch_inventory_label: Label = %WatchInventoryLabel
@onready var inventory_panel: Control = %InventoryPanel
@onready var inventory_contents_label: Label = %InventoryContentsLabel
@onready var use_bandage_button: Button = %UseBandageButton
@onready var use_food_button: Button = %UseFoodButton
@onready var death_label: Label = %DeathLabel

const MAX_DEBUG_NOTICE_COUNT: int = 5

var _event_bus = null
var _combat_banner_tween: Tween
var _perk_display_name: String = "--"
var _skill_display_name: String = "--"
var _skill_id: StringName = &"none"
var _skill_cooldown_remaining: float = 0.0
var _inventory_items: Dictionary = {}
var _active_statuses: Array[Dictionary] = []


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
	_event_bus.inventory_changed.connect(_on_inventory_changed)
	_event_bus.inventory_visibility_changed.connect(_on_inventory_visibility_changed)
	_event_bus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	_event_bus.player_perk_selected.connect(_on_player_perk_selected)
	_event_bus.player_active_skill_changed.connect(_on_player_active_skill_changed)
	_event_bus.player_action_blocked.connect(_on_player_action_blocked)
	_event_bus.player_weapon_changed.connect(_on_player_weapon_changed)
	_event_bus.player_ammo_changed.connect(_on_player_ammo_changed)
	_event_bus.status_list_changed.connect(_on_status_list_changed)
	_event_bus.debug_test_notice.connect(_on_debug_test_notice)
	_event_bus.combat_feedback.connect(_on_combat_feedback)
	_event_bus.watch_state_changed.connect(_on_watch_state_changed)
	_event_bus.wave_timer_changed.connect(_on_wave_timer_changed)
	_event_bus.player_died.connect(_on_player_died)
	_event_bus.enemy_spawned.connect(_on_enemy_spawned)
	_event_bus.enemy_died.connect(_on_enemy_died)
	use_bandage_button.pressed.connect(_request_item_use.bind(&"bandage"))
	use_food_button.pressed.connect(_request_item_use.bind(&"food_ration"))
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
	if _event_bus.inventory_changed.is_connected(_on_inventory_changed):
		_event_bus.inventory_changed.disconnect(_on_inventory_changed)
	if _event_bus.inventory_visibility_changed.is_connected(_on_inventory_visibility_changed):
		_event_bus.inventory_visibility_changed.disconnect(_on_inventory_visibility_changed)
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


func _on_interaction_prompt_changed(prompt: String) -> void:
	prompt_label.text = prompt
	prompt_label.visible = not prompt.is_empty()


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
	_inventory_items = items.duplicate(true)
	var text: String = _format_inventory(_inventory_items)
	inventory_contents_label.text = text
	watch_inventory_label.text = "SUPPLIES\n%s" % text
	use_bandage_button.disabled = int(_inventory_items.get(&"bandage", 0)) <= 0
	use_food_button.disabled = int(_inventory_items.get(&"food_ration", 0)) <= 0


func _on_inventory_visibility_changed(active: bool) -> void:
	inventory_panel.visible = active


func _request_item_use(item_id: StringName) -> void:
	if _event_bus != null:
		_event_bus.inventory_item_use_requested.emit(item_id)


func _on_status_list_changed(target_id: int, statuses: Array[Dictionary]) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and target_id != player.get_instance_id():
		return
	_active_statuses = statuses.duplicate(true)
	var text: String = _format_statuses(_active_statuses)
	status_label.text = text
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
	combat_banner_label.visible = true
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
	_combat_banner_tween.tween_callback(combat_banner_label.hide)


func _on_watch_state_changed(active: bool) -> void:
	watch_panel.visible = active


func _on_wave_timer_changed(remaining_seconds: float, total_seconds: float, wave_index: int) -> void:
	watch_wave_label.text = "Wave %d" % wave_index
	watch_timer_label.text = "Time %.0f / %.0f" % [remaining_seconds, total_seconds]


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


func _format_inventory(items: Dictionary) -> String:
	if items.is_empty():
		return "Empty"
	var lines: PackedStringArray = []
	var keys: Array = items.keys()
	keys.sort()
	for item_value: Variant in keys:
		lines.append("%s  x%d" % [_display_name_from_id(StringName(item_value)), int(items[item_value])])
	return "\n".join(lines)


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
