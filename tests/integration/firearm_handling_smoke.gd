extends Node3D

var failures: int = 0
var shots: int = 0
var last_recoil: Vector2 = Vector2.ZERO
var player: Player3DController


func _ready() -> void:
	var range_scene: Node3D = load("res://scenes/tests/firearm_range.tscn").instantiate() as Node3D
	add_child(range_scene)
	player = range_scene.get("player") as Player3DController
	player.set_physics_process(false)
	player.combat_driver.firearm_fired.connect(_count_shot)
	await get_tree().physics_frame
	var driver: PlayerCombatDriver = player.combat_driver
	var state: PlayerCombatStateMachine = player.combat_state_machine
	var input: PlayerInputReader = player.input_reader
	var loadout: PlayerLoadoutComponent = player.loadout_component
	_check(loadout.equipped_weapons.filter(func(w: WeaponDefinition) -> bool: return w.is_firearm()).size() == 4, "四把枪已装入独立武器栏")
	_select(&"rifle")
	driver.aim_fraction = 0.0
	var hip: float = driver.get_current_spread()
	driver.aim_fraction = 1.0
	_check(driver.get_current_spread() < hip, "开镜降低散布")
	input.wants_aim = true
	var constraints: Dictionary = {}
	player._update_firearm_handling(constraints, 1.0)
	_check(float(constraints.get("movement_speed_multiplier", 1.0)) < 1.0, "开镜降低移动速度")
	input.wants_aim = false
	var modifier_status: StatusEffectDefinition = StatusEffectDefinition.new()
	modifier_status.status_id = &"firearm_modifier_test"
	modifier_status.firearm_fire_rate_multiplier = 1.5
	modifier_status.firearm_recoil_multiplier = 1.4
	modifier_status.firearm_recoil_recovery_multiplier = 1.3
	modifier_status.firearm_viewmodel_recoil_multiplier = 0.8
	var modifier_container: StatusContainer = StatusContainer.new()
	add_child(modifier_container)
	modifier_container.apply_resolved_status(modifier_status, 5.0)
	var modifier_constraints: Dictionary = modifier_container.get_constraints()
	_check(is_equal_approx(float(modifier_constraints["firearm_fire_rate_multiplier"]), 1.5), "状态资源可修改射速倍率")
	_check(is_equal_approx(float(modifier_constraints["firearm_recoil_multiplier"]), 1.4), "状态资源可修改后坐倍率")
	driver.apply_firearm_modifiers(modifier_constraints)
	_check(is_equal_approx(driver.get_effective_fire_interval(), driver.current_weapon.fire_interval_seconds / 1.5), "射速倍率作用于运行时射击间隔")
	_refill()
	driver.shot_cooldown = 0.0
	last_recoil = Vector2.ZERO
	_check(driver.begin_primary_attack() and driver.resolve_primary_attack(player), "修改后可正常开火")
	_check(last_recoil.x > driver.current_weapon.recoil_pitch_degrees, "后坐倍率作用于射击冲量")
	player.first_person_arms.set_firearm(driver.current_weapon, 0.0)
	player.first_person_arms.reset_firearm_recoil()
	player.first_person_arms.firearm_impact(driver.firearm_viewmodel_recoil_multiplier)
	player.first_person_arms._advance_firearm_recoil(driver.current_weapon.primary_timing.impact_seconds)
	_check(is_equal_approx(player.first_person_arms._firearm_kick, driver.current_weapon.viewmodel_kick * 0.8), "枪身后坐倍率接口生效")
	driver.apply_firearm_modifiers({})
	player.camera_rig.reset_recoil()
	player.camera_rig.add_firearm_recoil(driver.current_weapon, Vector2(1, 0.1))
	_check(player.camera_rig.recoil_offset == Vector2.ZERO, "开火不瞬移镜头")
	player.camera_rig.advance_recoil(0.03)
	_check(player.camera_rig.recoil_offset.x > 0, "镜头后坐向上")
	_check(player.camera_rig.recoil_offset.x < player.camera_rig.recoil_target.x, "响应过程连续追随目标")
	var compensated: Vector2 = player.camera_rig.compensate_recoil(-player.camera_rig.recoil_target)
	player.camera_rig.advance_recoil(0.1)
	_check(compensated.length() < 0.0001 and player.camera_rig.recoil_offset.length() < 0.0001, "双轴压枪同时消除当前与待生效冲击")
	player.camera_rig.add_firearm_recoil(driver.current_weapon, Vector2(1, -1))
	var excess: Vector2 = player.camera_rig.compensate_recoil(Vector2(-2, 2) * PI / 180.0)
	_check(excess.distance_to(Vector2(-1, 1) * PI / 180.0) < 0.00001, "待生效后坐支持负水平与超量压枪")
	player.camera_rig.advance_recoil(0.1)
	_check(player.camera_rig.recoil_offset == Vector2.ZERO, "超量压枪后不二次回拉")
	player.camera_rig.add_firearm_recoil(driver.current_weapon, Vector2(1, 0))
	player.camera_rig.advance_recoil(0.15)
	player.camera_rig.recoil_delay = 0.0
	player.camera_rig.recoil_recovery_multiplier = 1.0
	var normal_recovery_start: float = player.camera_rig.recoil_offset.x
	player.camera_rig.recoil_target = player.camera_rig.recoil_offset
	player.camera_rig.advance_recoil(0.01)
	var normal_recovery_delta: float = normal_recovery_start - player.camera_rig.recoil_offset.x
	player.camera_rig.recoil_offset.x = normal_recovery_start
	player.camera_rig.recoil_target = player.camera_rig.recoil_offset
	player.camera_rig.recoil_recovery_multiplier = 2.0
	player.camera_rig.advance_recoil(0.01)
	_check(normal_recovery_start - player.camera_rig.recoil_offset.x > normal_recovery_delta, "后坐恢复倍率接口生效")
	player.camera_rig.advance_recoil(2.0)
	_check(player.camera_rig.recoil_offset.length() < 0.001, "镜头后坐恢复")
	for fps: int in [30, 60, 144]:
		player.camera_rig.reset_recoil()
		player.camera_rig.add_firearm_recoil(driver.current_weapon, Vector2(1, -0.5))
		for frame: int in fps / 10:
			player.camera_rig.advance_recoil(1.0 / fps)
		_check(player.camera_rig.recoil_offset.x > deg_to_rad(0.94) and player.camera_rig.recoil_offset.x < deg_to_rad(0.98), "%d 帧响应幅度一致" % fps)
	player.camera_rig.add_firearm_recoil(driver.current_weapon, Vector2(1, 1))
	var before_switch: Vector2 = player.camera_rig.recoil_offset
	player.camera_rig.set_firearm(null)
	_check(player.camera_rig.recoil_target == before_switch and player.camera_rig.recoil_offset == before_switch, "切枪取消待生效冲击且不瞬移")
	player.camera_rig.advance_recoil(2.0)
	_check(player.camera_rig.recoil_offset == Vector2.ZERO, "切枪后旧后坐平滑消退")
	for fps: int in [30, 60, 144]:
		_select(&"smg")
		_refill()
		shots = 0
		driver.shot_cooldown = 0.0
		driver.shots_in_burst = 0
		input.wants_primary_attack = true
		for frame: int in fps:
			state.update(player, input, {}, 1.0 / float(fps))
		input.wants_primary_attack = false
		state.interrupt()
		_check(shots >= 13 and shots <= 14, "%d 帧下连射频率正确（%d 发）" % [fps, shots])
	_select(&"smg")
	_refill()
	shots = 0
	driver.shot_cooldown = 0.0
	driver.shots_in_burst = 0
	input.wants_primary_attack = true
	for frame: int in 60:
		state.update(player, input, {"firearm_fire_rate_multiplier": 1.5}, 1.0 / 60.0)
	input.wants_primary_attack = false
	state.interrupt()
	_check(shots >= 18, "射速 Buff 提高实际连射频率（%d 发）" % shots)
	_select(&"pistol")
	_refill()
	shots = 0
	driver.shot_cooldown = 0
	input.primary_attack_buffered = true
	input.wants_primary_attack = true
	for frame: int in 60:
		state.update(player, input, {}, 1.0 / 60.0)
	_check(shots == 1, "半自动按住只打一发")
	input.wants_primary_attack = false
	state.interrupt()
	var before: int = loadout.get_magazine_ammo()
	input.reload_buffered = true
	state.update(player, input, {}, 0.0)
	state.update(player, input, {}, 0.1)
	_check(loadout.get_magazine_ammo() == before, "整匣装填命中前不转移弹药")
	state.interrupt()
	_check(loadout.get_magazine_ammo() == before, "提前中断不凭空装弹")
	input.reload_buffered = true
	state.update(player, input, {}, 0.0)
	state.update(player, input, {}, driver.get_reload_timing().impact_start_seconds())
	_check(loadout.get_magazine_ammo() == driver.current_weapon.magazine_size, "整匣在命中起点完成转移")
	state.interrupt()
	_select(&"shotgun")
	_refill()
	loadout.consume_round()
	loadout.consume_round()
	before = loadout.get_magazine_ammo()
	var reserve_before: int = loadout.get_reserve_ammo()
	input.reload_buffered = true
	state.update(player, input, {}, 0.0)
	state.update(player, input, {}, driver.get_reload_timing().impact_start_seconds())
	_check(loadout.get_magazine_ammo() == before + 1 and loadout.get_reserve_ammo() == reserve_before - 1, "逐发每次只转移一发")
	input.wants_sprint = true
	state.update(player, input, {"firearm_sprinting": true}, 0.01)
	_check(state.current_state == &"reload" and loadout.get_magazine_ammo() == before + 1, "奔跑不会打断正在进行的换弹")
	state.interrupt()
	input.wants_sprint = false
	shots = 0
	input.primary_attack_buffered = true
	state.update(player, input, {"firearm_sprinting": true}, 1.0)
	_check(shots == 0, "冲刺禁止开火")
	input.reload_buffered = true
	state.update(player, input, {}, 0.0)
	input.weapon_next_buffered = true
	state.update(player, input, {}, 0.01)
	_check(state.current_state == &"ready" and driver.current_weapon.weapon_id != &"shotgun", "切枪打断装填")
	var target: Node = load("res://scenes/tests/firearm_target.tscn").instantiate()
	add_child(target)
	var damage: DamageEventData = DamageEventData.new()
	damage.target_id = target.get_instance_id()
	damage.amount = 20.0
	damage.source_tags = [&"firearm", &"headshot"]
	var result: DamageResolutionData = get_node("/root/DamageResolver").resolve_damage(damage, target)
	_check(is_equal_approx(result.final_amount, 40.0), "头部倍率经统一伤害解析器生效")
	_select(&"rifle")
	# 用真实物理射线验证伤害衰减和墙体遮挡，不只检查字段。
	var ballistic_target: Node3D = load("res://scenes/tests/firearm_target.tscn").instantiate() as Node3D
	ballistic_target.position = Vector3(10, 0, -10)
	add_child(ballistic_target)
	player.position = Vector3(10, 0.95, 0)
	player.camera_rig.head.rotation = Vector3.ZERO
	player.camera_rig.camera.rotation = Vector3.ZERO
	player.camera_rig.camera.look_at(ballistic_target.global_position + Vector3(0, 1.2, 0))
	driver.aim_fraction = 1.0
	driver.motion_spread = 1.0
	driver.spread_bloom = 0.0
	var observed: Array[DamageResolutionData] = []
	var callback: Callable = func(value: DamageResolutionData) -> void: observed.append(value)
	get_node("/root/DamageResolver").damage_resolved.connect(callback)
	await get_tree().physics_frame
	driver._fire_ray(player, 40.0, 0)
	_check(observed.size() == 1 and is_equal_approx(observed[0].raw_amount, 40.0), "近距射线完整伤害")
	observed.clear()
	ballistic_target.position.z = -70
	player.camera_rig.camera.look_at(ballistic_target.global_position + Vector3(0, 1.2, 0))
	await get_tree().physics_frame
	driver._fire_ray(player, 40.0, 0)
	_check(observed.size() == 1 and observed[0].raw_amount < 30.0, "远距射线按距离衰减")
	observed.clear()
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = Vector3(10, 2, -5)
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	add_child(wall)
	await get_tree().physics_frame
	driver._fire_ray(player, 40.0, 0)
	_check(observed.is_empty(), "墙体阻断射线")
	get_node("/root/DamageResolver").damage_resolved.disconnect(callback)
	wall.queue_free()
	ballistic_target.queue_free()
	player.camera_rig.camera.rotation = Vector3.ZERO
	player.camera_rig.head.rotation.x = -0.045
	player.first_person_arms.set_firearm(driver.current_weapon, 1.0)
	for frame: int in 120:
		player.first_person_arms._update_firearm_pose(1.0 / 60.0)
	var arms: PlayerFirstPersonArms = player.first_person_arms
	var sight: Vector3 = player.camera_rig.camera.to_local(arms._firearm_visual.to_global(Vector3(0, 0.15, 0.03)))
	_check(absf(sight.x) < 0.01 and absf(sight.y) < 0.01 and sight.z < -0.4, "ADS 机械瞄具对齐视线并保持安全视距")
	_check(arms.right_elbow.rotation.x >= arms.ELBOW_LOWEST_ROTATION_X and arms.left_elbow.rotation.x >= arms.ELBOW_LOWEST_ROTATION_X, "持枪肘部保持向上弯曲")
	_check(arms._firearm_visual.get_parent() == arms.first_person_weapon_socket, "枪模保持挂在手部插槽")
	arms.reset_firearm_recoil()
	arms.firearm_impact(1.0, 1.0)
	_check(arms._firearm_kick == 0.0, "枪身冲击不会瞬移")
	arms._update_firearm_pose(driver.current_weapon.primary_timing.impact_seconds)
	var kicked_sight: Vector3 = player.camera_rig.camera.to_local(arms._firearm_visual.to_global(Vector3(0, 0.15, 0.03)))
	_check(absf(kicked_sight.y - sight.y) > 0.001 and arms._firearm_kick > 0.0, "ADS 对齐之后仍保留上跳与后蹬")
	arms._update_firearm_pose(driver.current_weapon.primary_timing.recovery_seconds)
	_check(arms._firearm_kick == 0.0, "枪身按同一动作合同恢复")
	for shot: int in 10:
		arms.firearm_impact(2.0, -1.0)
	arms._advance_firearm_recoil(driver.current_weapon.primary_timing.impact_seconds)
	_check(is_equal_approx(arms._firearm_kick, driver.current_weapon.viewmodel_recoil_limit * driver.current_weapon.viewmodel_kick * driver.current_weapon.viewmodel_ads_multiplier), "高倍率连射枪身冲击有累积上限")
	arms.play_watch_raised(driver.current_weapon.primary_timing)
	_check(arms._recoil_pulses.is_empty(), "其他动作接管后不会重播残留枪身冲击")
	arms._reset_action_tween()
	arms._watch_pose_active = false
	for fps: int in [30, 60, 144]:
		for multiplier: float in [0.5, 1.0, 2.0]:
			player.camera_rig.reset_recoil()
			arms.reset_firearm_recoil()
			var shot_clock: float = 0.0
			var bounded: bool = true
			for frame: int in fps:
				shot_clock -= 1.0 / fps
				if shot_clock <= 0.0:
					shot_clock += driver.current_weapon.fire_interval_seconds / multiplier
					player.camera_rig.add_firearm_recoil(driver.current_weapon, Vector2(1, -0.5) * multiplier)
					arms.firearm_impact(multiplier, -1.0)
				player.camera_rig.recoil_recovery_multiplier = multiplier
				player.camera_rig.advance_recoil(1.0 / fps)
				arms._update_firearm_pose(1.0 / fps)
				bounded = bounded and player.camera_rig.recoil_offset.is_finite() and arms._firearm_kick <= driver.current_weapon.viewmodel_recoil_limit * driver.current_weapon.viewmodel_kick * driver.current_weapon.viewmodel_ads_multiplier + 0.00001
			player.camera_rig.set_firearm(null)
			for frame: int in fps * 10:
				player.camera_rig.advance_recoil(1.0 / fps)
				arms._update_firearm_pose(1.0 / fps)
			_check(bounded and player.camera_rig.recoil_offset == Vector2.ZERO and arms._firearm_kick == 0.0, "%d 帧 / %.1f 倍率连射累积、切枪与恢复" % [fps, multiplier])
	print("枪械手感测试：%s" % ("通过" if failures == 0 else "%d 项失败" % failures))
	if OS.get_cmdline_user_args().has("--capture"):
		arms.set_process(false)
		player.camera_rig.set_process(false)
		player.camera_rig.reset_recoil()
		player.position = Vector3(0, 0.95, 0)
		player.camera_rig.recoil_offset = Vector2.ZERO
		player.camera_rig.camera.rotation = Vector3.ZERO
		for aim: float in [0.0, 1.0]:
			player.combat_driver.aim_fraction = aim
			player.camera_rig.aim_fraction = aim
			player.first_person_arms.set_firearm(driver.current_weapon, aim)
			for frame: int in 90:
				player.first_person_arms._update_firearm_pose(1.0 / 60.0)
				player.camera_rig.update_motion_feedback(false, 1.0 / 60.0)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path: String = "user://firearm_%s.png" % ("ads" if aim > 0 else "hip")
			get_viewport().get_texture().get_image().save_png(path)
			print("画面检查：" + ProjectSettings.globalize_path(path))
			arms.firearm_impact(1.0, 1.0)
			for sample: int in 4:
				arms._update_firearm_pose(driver.current_weapon.primary_timing.impact_seconds / 4.0)
				await RenderingServer.frame_post_draw
				var kick_path: String = "user://firearm_%s_kick_%d.png" % ["ads" if aim > 0 else "hip", sample]
				get_viewport().get_texture().get_image().save_png(kick_path)
			arms.reset_firearm_recoil()
	player.queue_free()
	target.queue_free()
	range_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func _select(id: StringName) -> void:
	player.combat_state_machine.interrupt()
	for attempt: int in 10:
		if player.loadout_component.get_current_weapon().weapon_id == id:
			return
		player.loadout_component.switch_relative(1)
	_check(false, "找到武器 %s" % id)


func _refill() -> void:
	while player.loadout_component.can_reload():
		player.loadout_component.finish_reload()


func _count_shot(_weapon: WeaponDefinition, _recoil: Vector2) -> void:
	shots += 1
	last_recoil = _recoil


func _check(ok: bool, message: String) -> void:
	print("%s：%s" % ["通过" if ok else "失败", message])
	if not ok:
		failures += 1
