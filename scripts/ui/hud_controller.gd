class_name HudController
extends CanvasLayer

@onready var phase_label: Label = %PhaseLabel
@onready var health_label: Label = %HealthLabel
@onready var stamina_label: Label = %StaminaLabel
@onready var hunger_label: Label = %HungerLabel
@onready var core_label: Label = %CoreLabel

var _event_bus = null


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus == null:
		return

	_event_bus.phase_changed.connect(_on_phase_changed)
	_event_bus.player_health_changed.connect(_on_player_health_changed)
	_event_bus.player_stamina_changed.connect(_on_player_stamina_changed)
	_event_bus.hunger_changed.connect(_on_hunger_changed)
	_event_bus.base_core_health_changed.connect(_on_base_core_health_changed)


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
