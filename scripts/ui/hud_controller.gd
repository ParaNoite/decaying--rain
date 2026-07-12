class_name HudController
extends CanvasLayer

@onready var phase_label: Label = %PhaseLabel
@onready var health_label: Label = %HealthLabel
@onready var stamina_label: Label = %StaminaLabel
@onready var hunger_label: Label = %HungerLabel
@onready var core_label: Label = %CoreLabel
@onready var prompt_label: Label = %PromptLabel
@onready var debug_notice_stack: VBoxContainer = %DebugNoticeStack
@onready var combat_banner_label: Label = %CombatBannerLabel
@onready var watch_panel: Control = %WatchPanel
@onready var watch_wave_label: Label = %WatchWaveLabel
@onready var watch_timer_label: Label = %WatchTimerLabel
@onready var death_label: Label = %DeathLabel

const MAX_DEBUG_NOTICE_COUNT: int = 5

var _event_bus = null
var _combat_banner_tween: Tween


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
	_event_bus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	_event_bus.debug_test_notice.connect(_on_debug_test_notice)
	_event_bus.combat_feedback.connect(_on_combat_feedback)
	_event_bus.watch_state_changed.connect(_on_watch_state_changed)
	_event_bus.wave_timer_changed.connect(_on_wave_timer_changed)
	_event_bus.player_died.connect(_on_player_died)
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
	if _event_bus.interaction_prompt_changed.is_connected(_on_interaction_prompt_changed):
		_event_bus.interaction_prompt_changed.disconnect(_on_interaction_prompt_changed)
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


func _on_phase_changed(_previous_phase: StringName, current_phase: StringName, wave_index: int) -> void:
	phase_label.text = "Wave %d / %s" % [wave_index, String(current_phase)]


func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP %.0f / %.0f" % [current, maximum]


func _on_player_stamina_changed(current: float, maximum: float) -> void:
	stamina_label.text = "STA %.0f / %.0f" % [current, maximum]


func _on_hunger_changed(current: float, maximum: float) -> void:
	hunger_label.text = "FOOD %.0f / %.0f" % [current, maximum]


func _on_base_core_health_changed(current: float, maximum: float) -> void:
	core_label.text = "CORE %.0f / %.0f" % [current, maximum]


func _on_resource_looted(resource_id: StringName, payload: Dictionary) -> void:
	_on_debug_test_notice("Picked up %s: %s" % [String(resource_id), str(payload)], &"loot")


func _on_interaction_prompt_changed(prompt: String) -> void:
	prompt_label.text = prompt
	prompt_label.visible = not prompt.is_empty()


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

	get_tree().create_timer(3.0).timeout.connect(_remove_debug_notice.bind(notice_label), CONNECT_ONE_SHOT)


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


func _remove_debug_notice(notice_label: Label) -> void:
	if is_instance_valid(notice_label):
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

	var base_core: Node = get_tree().get_first_node_in_group("base_core")
	if base_core != null:
		var core_health: HealthComponent = base_core.get_node_or_null("HealthComponent") as HealthComponent
		if core_health != null:
			_on_base_core_health_changed(core_health.current_health, core_health.max_health)
