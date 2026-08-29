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

	player.status_container.clear_resolved_statuses()
	player.apply_status_by_id(&"bleeding", 12.0)
	await get_tree().process_frame
	_check(hud.status_row.get_child_count() == 1, "bottom status row did not render one active status")
	var status_panel: PanelContainer = hud.status_row.get_child(0) as PanelContainer
	_check(status_panel != null, "bottom status row did not render a status panel")
	var status_label: Label = status_panel.get_child(0) as Label
	_check(status_label != null and status_label.text.contains("BLEEDING"), "bottom status row omitted the status name")
	_check(status_label.text.contains("12"), "bottom status row omitted the remaining duration")

	player.status_container.clear_resolved_statuses()
	await get_tree().process_frame
	_check(hud.status_row.get_child_count() == 0, "cleared statuses remained in the bottom status row")
	_check(hud.status_empty_label.visible, "bottom status row did not show its clear state")

	print("HUD_STATUS_DISPLAY_SMOKE: PASS")
	get_tree().quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("HUD_STATUS_DISPLAY_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)
