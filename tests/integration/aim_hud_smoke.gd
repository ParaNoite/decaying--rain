extends Node3D

var failures: int = 0
var player: Player3DController
var aim: AimHud


func _ready() -> void:
	var range_scene: Node3D = preload("res://scenes/tests/firearm_range.tscn").instantiate()
	add_child(range_scene)
	player = range_scene.player
	player.set_physics_process(false)
	aim = range_scene._crosshair
	var hud: HudController = preload("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	_check(hud.crosshair.get_script() == aim.get_script() and hud.crosshair.definition == aim.definition, "正式 HUD 与靶场共用组件和调参资源")
	player.combat_driver.aim_fraction = 0.0
	player.combat_driver.motion_spread = 1.0
	aim.update_from_player(1.0)
	_check(aim.center_visible and aim.outer_visible, "腰射显示中心点和外框")
	var base_radius: float = aim.spread_radius
	player.combat_driver.motion_spread = 3.0
	aim.update_from_player(1.0)
	_check(aim.spread_radius > base_radius, "实际精度降低时外框扩张")
	player.combat_driver.motion_spread = 1.0
	player.combat_driver.apply_firearm_modifiers({"firearm_spread_multiplier": 2.0})
	aim.update_from_player(1.0)
	_check(aim.spread_radius > base_radius, "散布 Buff 进入准心显示")
	player.combat_driver.apply_firearm_modifiers({})
	player.first_person_arms.set_firearm(player.combat_driver.current_weapon, 0.0)
	player.first_person_arms.firearm_impact(2.0, 1.0)
	player.first_person_arms._update_firearm_pose(player.combat_driver.current_weapon.primary_timing.impact_seconds)
	aim.update_from_player(0.1)
	_check(aim.outer_offset.y < 0.0 and aim.outer_offset.length() <= aim.definition.recoil_limit_pixels, "浮动外框向上跟枪且幅度受限")
	player.combat_driver.aim_fraction = 1.0
	aim.update_from_player(1.0)
	_check(not aim.center_visible and not aim.outer_visible and aim.visible, "ADS 隐藏瞄准图形但保留命中层")
	player.combat_state_machine.current_state = PlayerCombatStateMachine.STATE_RELOAD
	aim.update_from_player(1.0)
	_check(aim.center_visible and not aim.outer_visible, "换弹优先保留中心点")
	player.combat_state_machine.current_state = PlayerCombatStateMachine.STATE_READY
	player.locomotion_state_machine.current_state = PlayerLocomotionStateMachine.STATE_SPRINT
	aim.update_from_player(1.0)
	_check(aim.center_visible and not aim.outer_visible, "冲刺保留中心点")
	player.locomotion_state_machine.current_state = PlayerLocomotionStateMachine.STATE_IDLE
	player.combat_driver.aim_fraction = 0.0
	var interactable: InteractableComponent = InteractableComponent.new()
	interactable.prompt = "E 交互测试"
	add_child(interactable)
	player.interaction_driver.focused_interactable = interactable
	get_node("/root/EventBus").interaction_prompt_changed.emit(interactable.prompt)
	aim.update_from_player(0.1)
	_check(aim.interaction_active and aim.prompt_label.visible and aim.prompt_label.text == interactable.prompt, "交互圆环与下方文字使用有效焦点")
	interactable.enabled = false
	aim.update_from_player(0.1)
	_check(not aim.interaction_active, "禁用交互目标不显示圆环")
	player.interaction_driver.clear_prompt()
	var saved_weapon: WeaponDefinition = player.combat_driver.current_weapon
	player.combat_driver.current_weapon = null
	aim.update_from_player(0.1)
	_check(aim.center_visible and not aim.outer_visible, "空手只显示中心点")
	player.combat_driver.current_weapon = saved_weapon
	var fps_radii: Array[float] = []
	for fps: int in [30, 60, 144]:
		aim.spread_radius = 8.0
		for frame: int in fps:
			aim.update_from_player(1.0 / fps)
		fps_radii.append(aim.spread_radius)
	_check(absf(fps_radii.max() - fps_radii.min()) < 0.001, "30/60/144 帧散布响应一致")
	var target: Node3D = preload("res://scenes/tests/firearm_target.tscn").instantiate()
	add_child(target)
	var hit: DamageEventData = DamageEventData.new()
	hit.attacker_id = player.get_instance_id()
	hit.target_id = target.get_instance_id()
	hit.amount = 1.0
	hit.source_tags = [&"firearm"]
	var resolver: Node = get_node("/root/DamageResolver")
	resolver.resolve_damage(hit, target)
	_check(aim.hit_marker.is_active() and aim.hit_marker.kind == HitMarker.Kind.HIT and hud.hit_marker.is_active(), "真实枪械命中同时驱动两种 HUD")
	hit.source_tags.append(&"headshot")
	resolver.resolve_damage(hit, target)
	_check(aim.hit_marker.kind == HitMarker.Kind.HEADSHOT, "头部标签触发爆头提示")
	hit.amount = 2000.0
	var result: DamageResolutionData = resolver.resolve_damage(hit, target)
	_check(result.killed and target.get_health_component().is_alive() and aim.hit_marker.kind == HitMarker.Kind.KILL, "靶子回血前记录本次击杀，击杀覆盖爆头")
	hit.amount = 1.0
	hit.source_tags = [&"firearm"]
	resolver.resolve_damage(hit, target)
	_check(aim.hit_marker.kind == HitMarker.Kind.KILL, "后续低级命中不会覆盖击杀")
	aim.hit_marker._process(0.4)
	resolver.resolve_damage(hit, target)
	_check(aim.hit_marker.kind == HitMarker.Kind.HIT, "高级提示到期后允许普通命中")
	aim.hit_marker.clear()
	hit.attacker_id = 0
	resolver.resolve_damage(hit, target)
	_check(not aim.hit_marker.is_active(), "其他来源伤害不触发玩家命中提示")
	hit.attacker_id = player.get_instance_id()
	player.combat_driver.aim_fraction = 1.0
	aim.update_from_player(1.0)
	resolver.resolve_damage(hit, target)
	_check(aim.hit_marker.is_active() and not aim.center_visible, "ADS 命中提示独立显示")
	aim.set_gameplay_visible(false)
	resolver.resolve_damage(hit, target)
	_check(not aim.hit_marker.is_active(), "隐藏 HUD 清理并拒绝残留命中")
	aim.set_gameplay_visible(true)
	if OS.get_cmdline_user_args().has("--capture"):
		hud.hide()
		player.combat_driver.aim_fraction = 0.0
		player.first_person_arms.reset_firearm_recoil()
		player.first_person_arms.set_firearm(player.combat_driver.current_weapon, 0.0)
		for frame: int in 30:
			await get_tree().process_frame
		await _capture("hip")
		for kind: int in [HitMarker.Kind.HIT, HitMarker.Kind.HEADSHOT, HitMarker.Kind.KILL]:
			aim.hit_marker.show_hit(kind)
			await _capture("hit_%d" % kind)
		player.combat_driver.aim_fraction = 1.0
		aim.hit_marker.clear()
		player.first_person_arms.set_firearm(player.combat_driver.current_weapon, 1.0)
		for frame: int in 30:
			await get_tree().process_frame
		await _capture("ads")
	player.health.set_health(0.0)
	aim.update_from_player(0.0)
	_check(not aim.visible and not aim.hit_marker.is_active(), "死亡清除准心和命中提示")
	print("AIM_HUD_SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	hud.queue_free()
	range_scene.queue_free()
	target.queue_free()
	interactable.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "user://aim_hud_%s.png" % label
	get_viewport().get_texture().get_image().save_png(path)
	print(ProjectSettings.globalize_path(path))


func _check(value: bool, message: String) -> void:
	print("%s：%s" % ["通过" if value else "失败", message])
	if not value:
		failures += 1
