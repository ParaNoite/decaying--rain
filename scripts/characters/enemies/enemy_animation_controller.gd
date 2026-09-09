class_name EnemyAnimationController
extends Node

const ACTION_NONE: StringName = &"none"
const ACTION_ATTACK_WINDUP: StringName = &"attack_windup"
const ACTION_ATTACK_RELEASE: StringName = &"attack_release"
const ACTION_ATTACK_IMPACT: StringName = &"attack_impact"
const ACTION_ATTACK_RECOVERY: StringName = &"attack_recovery"
const ACTION_HURT: StringName = &"hurt"
const ACTION_SHOVED: StringName = &"shoved"
const ACTION_PARRIED: StringName = &"parried"
const ACTION_DEAD: StringName = &"dead"
const ATTACK_STYLE_DEFAULT: StringName = &"default"
const ATTACK_STYLE_HEAVY: StringName = &"heavy"

var current_action: StringName = ACTION_NONE
var locomotion_amount: float = 0.0
var attack_pose_amount: float = 0.0

var _rig: EnemyVisualRig
var _role: EnemyDefinition.PressureRole = EnemyDefinition.PressureRole.MELEE_SWARM
var _time: float = 0.0
var _action_elapsed: float = 0.0
var _action_duration: float = 0.0
var _attack_total_elapsed: float = 0.0
var _attack_timing: ActionTimingDefinition
var _attack_active: bool = false
var _presentation_timing: ActionTimingDefinition
var _is_ranged_attack: bool = false
var _attack_style: StringName = ATTACK_STYLE_DEFAULT
var _attack_movement: AttackMovementDefinition
var _heavy_lunge_amount: float = 0.0
var _heavy_pounce_start_seconds: float = 0.22
var _heavy_windup_seconds: float = 1.0
var _walk_weight: float = 0.0
var _rest_positions: Dictionary[Node3D, Vector3] = {}


func _process(delta: float) -> void:
	if _rig == null:
		return
	_time += delta
	if _attack_active:
		_attack_total_elapsed += delta
		_sync_attack_phase()
	else:
		_action_elapsed += delta
	_update_pose(delta)


func configure(enemy_definition: EnemyDefinition, visual_rig: EnemyVisualRig) -> void:
	if enemy_definition == null or visual_rig == null:
		return
	_rig = visual_rig
	_role = enemy_definition.pressure_role
	_heavy_pounce_start_seconds = enemy_definition.heavy_attack_pounce_timing.impact_start_seconds()
	_heavy_windup_seconds = enemy_definition.heavy_attack_timing.windup_seconds
	_rest_positions.clear()
	for pivot: Node3D in _animated_pivots():
		_rest_positions[pivot] = pivot.position
	_update_pose(0.0)


func set_locomotion_speed(normalized_speed: float) -> void:
	locomotion_amount = clampf(normalized_speed, 0.0, 1.0)


func set_heavy_lunge_amount(normalized_speed: float) -> void:
	_heavy_lunge_amount = clampf(normalized_speed, 0.0, 1.0)


func _sync_attack_phase() -> void:
	if not _attack_active or _attack_timing == null:
		return
	var phase := _attack_timing.phase_at(_attack_total_elapsed)
	if phase == ActionTimingDefinition.Phase.COMPLETE:
		_attack_active = false
		current_action = ACTION_NONE
		_action_elapsed = 0.0
		_action_duration = 0.0
		attack_pose_amount = 0.0
		return
	_action_elapsed = maxf(0.0, _attack_total_elapsed - _attack_timing.phase_start_seconds(phase))
	_action_duration = maxf(0.001, _attack_timing.phase_duration(phase))
	match phase:
		ActionTimingDefinition.Phase.WINDUP:
			current_action = ACTION_ATTACK_WINDUP
		ActionTimingDefinition.Phase.RELEASE:
			current_action = ACTION_ATTACK_RELEASE
		ActionTimingDefinition.Phase.IMPACT:
			current_action = ACTION_ATTACK_IMPACT
		ActionTimingDefinition.Phase.RECOVERY:
			current_action = ACTION_ATTACK_RECOVERY


func play_attack(
	timing: ActionTimingDefinition,
	is_ranged: bool,
	attack_style: StringName = ATTACK_STYLE_DEFAULT,
	attack_movement: AttackMovementDefinition = null
) -> void:
	if (
		_attack_active
		and _attack_timing == timing
		and _is_ranged_attack == is_ranged
		and _attack_style == attack_style
		and _attack_movement == attack_movement
	):
		return
	_presentation_timing = null
	_attack_timing = timing
	_attack_total_elapsed = 0.0
	_attack_active = timing != null
	_is_ranged_attack = is_ranged
	_attack_style = attack_style
	_attack_movement = attack_movement
	_sync_attack_phase()


func play_reaction(reaction: StringName, timing: ActionTimingDefinition, duration_override: float = -1.0) -> void:
	_attack_active = false
	_attack_movement = null
	_presentation_timing = timing
	current_action = reaction
	_action_elapsed = 0.0
	var contract_duration: float = timing.total_seconds() if timing != null else 0.0
	_action_duration = maxf(0.001, duration_override if duration_override >= 0.0 else contract_duration)
	attack_pose_amount = 0.0


func play_death(timing: ActionTimingDefinition) -> void:
	_attack_active = false
	_attack_movement = null
	_presentation_timing = timing
	current_action = ACTION_DEAD
	_action_elapsed = 0.0
	_action_duration = maxf(0.001, timing.total_seconds() if timing != null else 0.0)
	attack_pose_amount = 0.0


func get_action_state() -> StringName:
	return current_action


func _update_pose(delta: float) -> void:
	var locomotion_target: float = locomotion_amount if current_action == ACTION_NONE else _attack_locomotion_weight()
	_walk_weight = move_toward(_walk_weight, locomotion_target, delta * 6.0)
	_reset_pose()
	_apply_breathing_and_walk()
	match current_action:
		ACTION_ATTACK_WINDUP:
			_apply_attack_windup()
		ACTION_ATTACK_RELEASE:
			if _attack_style == ATTACK_STYLE_HEAVY:
				_apply_heavy_release(_action_progress())
			else:
				_apply_attack_impact(_action_progress() * 0.32)
		ACTION_ATTACK_IMPACT:
			if _attack_style == ATTACK_STYLE_HEAVY:
				_apply_heavy_impact(_action_progress())
			else:
				_apply_attack_impact(0.32)
		ACTION_ATTACK_RECOVERY:
			if _attack_style == ATTACK_STYLE_HEAVY:
				_apply_heavy_recovery(_action_progress())
			else:
				_apply_attack_impact(0.32 + _action_progress() * 0.68)
		ACTION_HURT:
			_apply_hurt()
		ACTION_SHOVED:
			_apply_shove()
		ACTION_PARRIED:
			_apply_parry()
		ACTION_DEAD:
			_apply_death()
		_:
			attack_pose_amount = 0.0
	if not _attack_active and current_action not in [ACTION_NONE, ACTION_DEAD] and _action_elapsed >= _action_duration:
		current_action = ACTION_NONE
		attack_pose_amount = 0.0


func _attack_locomotion_weight() -> float:
	if (
		not _attack_active
		or _attack_movement == null
		or not _attack_movement.use_locomotion_blend
		or _attack_timing == null
	):
		return 0.0
	var phase: ActionTimingDefinition.Phase = _attack_timing.phase_at(_attack_total_elapsed)
	if _attack_movement.speed_multiplier_for_phase(phase) <= 0.0:
		return 0.0
	return minf(locomotion_amount, _attack_movement.locomotion_blend_max_weight)


func _reset_pose() -> void:
	for pivot: Node3D in _rest_positions:
		if is_instance_valid(pivot):
			pivot.position = _rest_positions[pivot]
			pivot.quaternion = Quaternion.IDENTITY
	if _rig.muzzle_flash != null:
		_rig.muzzle_flash.visible = false
		_rig.muzzle_flash.scale = Vector3.ONE


func _apply_breathing_and_walk() -> void:
	var gait: float = sin(_time * lerpf(6.8, 8.6, _walk_weight))
	var stride: float = gait * _walk_weight
	var left_knee_bend: float = maxf(0.0, -gait) * _walk_weight
	var right_knee_bend: float = maxf(0.0, gait) * _walk_weight
	var breath: float = sin(_time * 2.1) * (1.0 - _walk_weight)
	_offset(_rig.hips, Vector3(0.0, absf(gait) * 0.045 * _walk_weight + breath * 0.008, 0.0))
	_pose(_rig.hips, Vector3(0.0, stride * 4.5, stride * 1.5))
	_pose(_rig.spine, Vector3(breath * 1.2, -stride * 7.0, -stride * 2.0))
	_pose(_rig.head, Vector3(-breath * 0.8, stride * 2.4, stride))
	_pose(_rig.left_leg, Vector3(-stride * 30.0, 0.0, 0.0))
	_pose(_rig.right_leg, Vector3(stride * 30.0, 0.0, 0.0))
	_pose(_rig.left_knee, Vector3(left_knee_bend * 34.0, 0.0, 0.0))
	_pose(_rig.right_knee, Vector3(right_knee_bend * 34.0, 0.0, 0.0))
	_pose(_rig.left_arm, Vector3(stride * 25.0 - 4.0, 0.0, 7.0))
	_pose(_rig.right_arm, Vector3(-stride * 25.0 - 4.0, 0.0, -7.0))
	_pose(_rig.left_forearm, Vector3(-10.0 - absf(stride) * 9.0, 0.0, 0.0))
	_pose(_rig.right_forearm, Vector3(-10.0 - absf(stride) * 9.0, 0.0, 0.0))
	_pose(_rig.coat_left, Vector3(-8.0 - stride * 8.0, 0.0, stride * 3.0))
	_pose(_rig.coat_right, Vector3(-8.0 + stride * 8.0, 0.0, stride * 3.0))


func _apply_attack_windup() -> void:
	var weight: float = _ease_in_out(_action_progress())
	attack_pose_amount = weight
	if _is_ranged_attack:
		_apply_ranged_aim(weight)
	elif _attack_style == ATTACK_STYLE_HEAVY:
		_apply_heavy_windup(weight, _action_progress())
	elif _role == EnemyDefinition.PressureRole.BASE_BREAKER:
		_apply_melee_windup(weight, 1.18)
	else:
		_apply_melee_windup(weight, 1.0)


func _apply_heavy_windup(weight: float, progress: float) -> void:
	var jump_start: float = clampf(_heavy_pounce_start_seconds / maxf(0.001, _heavy_windup_seconds), 0.10, 0.90)
	var crouch_progress: float = clampf(progress / jump_start, 0.0, 1.0)
	var jump_progress: float = clampf((progress - jump_start) / maxf(0.001, 1.0 - jump_start), 0.0, 1.0)
	var crouch: float = _ease_in_out(crouch_progress)
	var stumble: float = sin(jump_progress * PI * 3.0) * weight
	var stride_scale: float = lerpf(0.28, 1.0, _heavy_lunge_amount)
	var step: float = sin(jump_progress * PI * 7.0) * weight * stride_scale
	var burst_weight: float = smoothstep(0.60, 0.90, _heavy_lunge_amount)
	var leap_arc: float = sin(jump_progress * PI) * burst_weight
	var launch_lift: float = smoothstep(0.0, 0.22, jump_progress) * (1.0 - smoothstep(0.70, 1.0, jump_progress)) * 0.28
	var landing_brace: float = smoothstep(0.45, 0.85, 1.0 - _heavy_lunge_amount) * weight
	var arm_raise_start: float = maxf(0.0, jump_start - 0.16)
	var arm_raise_progress: float = clampf((progress - arm_raise_start) / 0.22, 0.0, 1.0)
	var arm_raise: float = _ease_out(arm_raise_progress)
	var arm_snap: float = arm_raise + sin(arm_raise_progress * PI) * 0.08
	_offset(_rig.hips, Vector3(stumble * 0.065, -0.28 * crouch + absf(step) * 0.035 + leap_arc * 0.55 + launch_lift - landing_brace * 0.08, 0.02 * crouch - leap_arc * 0.18))
	_pose(_rig.hips, Vector3(28.0 * crouch - 20.0 * weight - 17.0 * leap_arc + 10.0 * landing_brace, stumble * 11.0, step * 7.0))
	_pose(_rig.spine, Vector3(21.0 * crouch - 31.0 * weight - 15.0 * leap_arc + 8.0 * landing_brace, -stumble * 16.0, stumble * 9.0))
	_pose(_rig.head, Vector3(-14.0 * crouch + 18.0 * weight, stumble * 10.0, -stumble * 7.0))
	_pose(_rig.left_arm, Vector3(132.0 * arm_snap, 27.0 * arm_raise, 31.0 * arm_raise))
	_pose(_rig.right_arm, Vector3(132.0 * arm_snap, -27.0 * arm_raise, -31.0 * arm_raise))
	_pose(_rig.left_forearm, Vector3(31.0 * arm_raise, -15.0 * arm_raise, -8.0 * arm_raise))
	_pose(_rig.right_forearm, Vector3(31.0 * arm_raise, 15.0 * arm_raise, 8.0 * arm_raise))
	_pose(_rig.left_leg, Vector3(-24.0 * crouch - step * 36.0 - 12.0 * weight + 34.0 * leap_arc, 0.0, -7.0 * weight))
	_pose(_rig.right_leg, Vector3(-20.0 * crouch + step * 36.0 + 16.0 * weight + 44.0 * leap_arc, 0.0, 7.0 * weight))
	_pose(_rig.left_knee, Vector3(54.0 * crouch + maxf(0.0, step) * 42.0 + 16.0 * weight + 62.0 * leap_arc + 18.0 * landing_brace, 0.0, 0.0))
	_pose(_rig.right_knee, Vector3(58.0 * crouch + maxf(0.0, -step) * 42.0 + 21.0 * weight + 74.0 * leap_arc + 22.0 * landing_brace, 0.0, 0.0))
	_pose(_rig.coat_left, Vector3(-18.0 * weight - step * 8.0, 5.0 * weight, 12.0 * weight))
	_pose(_rig.coat_right, Vector3(-18.0 * weight + step * 8.0, -5.0 * weight, -12.0 * weight))


func _apply_heavy_release(progress: float) -> void:
	var strike: float = _ease_in_out(progress)
	_apply_heavy_strike_pose(strike, 1.0)


func _apply_heavy_impact(_progress: float) -> void:
	_apply_heavy_strike_pose(1.0, 1.0)


func _apply_heavy_recovery(progress: float) -> void:
	var weight: float = 1.0 - _ease_in_out(progress)
	_apply_heavy_strike_pose(1.0, weight)
	var wobble: float = sin(progress * PI * 3.0) * weight
	_pose_add(_rig.hips, Vector3(0.0, wobble * 8.0, wobble * 5.0))
	_pose_add(_rig.spine, Vector3(0.0, -wobble * 10.0, -wobble * 6.0))


func _apply_heavy_strike_pose(strike: float, weight: float) -> void:
	attack_pose_amount = weight
	_offset(_rig.hips, Vector3(0.0, lerpf(-0.12, -0.21, strike), lerpf(-0.08, -0.24, strike)) * weight)
	_pose(_rig.hips, Vector3(lerpf(-13.0, -24.0, strike), 0.0, lerpf(0.0, 5.0, strike)) * weight)
	_pose(_rig.spine, Vector3(lerpf(-19.0, -48.0, strike), 0.0, lerpf(0.0, -7.0, strike)) * weight)
	_pose(_rig.head, Vector3(lerpf(11.0, 24.0, strike), 0.0, lerpf(0.0, 6.0, strike)) * weight)
	_pose(_rig.left_arm, Vector3(lerpf(132.0, 32.0, strike), lerpf(27.0, 0.0, strike), lerpf(31.0, 62.0, strike)) * weight)
	_pose(_rig.right_arm, Vector3(lerpf(132.0, 42.0, strike), lerpf(-27.0, 0.0, strike), lerpf(-31.0, -62.0, strike)) * weight)
	_pose(_rig.left_forearm, Vector3(lerpf(31.0, 12.0, strike), lerpf(-15.0, 0.0, strike), 18.0 * weight))
	_pose(_rig.right_forearm, Vector3(lerpf(31.0, 22.0, strike), lerpf(15.0, 0.0, strike), -18.0 * weight))
	_pose(_rig.left_leg, Vector3(lerpf(-9.0, 19.0, strike), 0.0, -6.0) * weight)
	_pose(_rig.right_leg, Vector3(lerpf(12.0, -14.0, strike), 0.0, 6.0) * weight)
	_pose(_rig.left_knee, Vector3(lerpf(13.0, 31.0, strike), 0.0, 0.0) * weight)
	_pose(_rig.right_knee, Vector3(lerpf(17.0, 27.0, strike), 0.0, 0.0) * weight)
	_pose(_rig.coat_left, Vector3(-29.0 * strike, 7.0, 14.0) * weight)
	_pose(_rig.coat_right, Vector3(-27.0 * strike, -7.0, -14.0) * weight)


func _apply_ranged_aim(weight: float) -> void:
	_offset(_rig.hips, Vector3(0.0, -0.025 * weight, 0.04 * weight))
	_pose(_rig.hips, Vector3(0.0, -12.0 * weight, 0.0))
	_pose(_rig.spine, Vector3(4.0 * weight, 16.0 * weight, 0.0))
	_pose(_rig.head, Vector3(-3.0 * weight, -5.0 * weight, 0.0))
	_pose(_rig.right_arm, Vector3(70.0 * weight, -20.0 * weight, -14.0 * weight))
	_pose(_rig.right_forearm, Vector3(22.0 * weight, 8.0 * weight, 0.0))
	_pose(_rig.left_arm, Vector3(68.0 * weight, 29.0 * weight, 20.0 * weight))
	_pose(_rig.left_forearm, Vector3(22.0 * weight, -10.0 * weight, 4.0 * weight))
	_pose(_rig.left_leg, Vector3(-8.0 * weight, 0.0, -4.0 * weight))
	_pose(_rig.right_leg, Vector3(10.0 * weight, 0.0, 3.0 * weight))


func _apply_melee_windup(weight: float, heavy: float) -> void:
	var leg_lock_weight: float = 1.0 - _attack_locomotion_weight() * 0.85
	_offset(_rig.hips, Vector3(-0.06 * weight, -0.07 * weight, 0.09 * weight))
	_pose(_rig.hips, Vector3(-8.0 * weight, -25.0 * weight, -5.0 * weight))
	_pose(_rig.spine, Vector3(-13.0 * weight, -32.0 * weight, -8.0 * weight))
	_pose(_rig.head, Vector3(7.0 * weight, 17.0 * weight, 5.0 * weight))
	_pose(_rig.right_arm, Vector3(102.0 * heavy * weight, -16.0 * weight, -31.0 * weight))
	_pose(_rig.right_forearm, Vector3(31.0 * heavy * weight, 7.0 * weight, -5.0 * weight))
	_pose(_rig.left_arm, Vector3(56.0 * heavy * weight, 24.0 * weight, 25.0 * weight))
	_pose(_rig.left_forearm, Vector3(24.0 * heavy * weight, -7.0 * weight, 5.0 * weight))
	_pose_attack_leg(_rig.left_leg, Vector3(-16.0 * weight * leg_lock_weight, 0.0, -5.0 * weight * leg_lock_weight))
	_pose_attack_leg(_rig.right_leg, Vector3(14.0 * weight * leg_lock_weight, 0.0, 3.0 * weight * leg_lock_weight))
	_pose_attack_leg(_rig.right_knee, Vector3(20.0 * weight * leg_lock_weight, 0.0, 0.0))
	_pose(_rig.coat_left, Vector3(-18.0 * weight, 6.0 * weight, 9.0 * weight))
	_pose(_rig.coat_right, Vector3(-13.0 * weight, -7.0 * weight, -7.0 * weight))


func _apply_attack_impact(progress_override: float = -1.0) -> void:
	var progress: float = _action_progress() if progress_override < 0.0 else clampf(progress_override, 0.0, 1.0)
	if _is_ranged_attack:
		var aim_weight: float = 1.0 if progress < 0.24 else 1.0 - _ease_in_out((progress - 0.24) / 0.76)
		var recoil: float = sin(clampf(progress / 0.34, 0.0, 1.0) * PI)
		attack_pose_amount = aim_weight
		_apply_ranged_aim(aim_weight)
		if _rig.muzzle_flash != null and progress < 0.18:
			_rig.muzzle_flash.visible = true
			var flash_scale: float = 1.0 + sin(progress / 0.18 * PI) * 1.6
			_rig.muzzle_flash.scale = Vector3(0.75, flash_scale, 0.75)
		_offset(_rig.spine, Vector3(0.0, 0.0, 0.075 * recoil))
		_pose_add(_rig.spine, Vector3(-7.0 * recoil, 0.0, 2.0 * recoil))
		_pose_add(_rig.head, Vector3(4.0 * recoil, 0.0, -2.0 * recoil))
		return
	var contact_blend: float = _ease_in_out(clampf(progress / 0.32, 0.0, 1.0))
	var recovery_weight: float = 1.0 if progress < 0.32 else 1.0 - _ease_in_out((progress - 0.32) / 0.68)
	var heavy: float = 1.25 if _role == EnemyDefinition.PressureRole.BASE_BREAKER else 1.0
	var windup_arm: float = 102.0 * heavy
	var windup_forearm: float = 31.0 * heavy
	var right_arm_x: float = lerpf(windup_arm, 70.0, contact_blend) * recovery_weight
	var right_forearm_x: float = lerpf(windup_forearm, 8.0, contact_blend) * recovery_weight
	var left_arm_x: float = lerpf(56.0 * heavy, 66.0, contact_blend) * recovery_weight
	var left_forearm_x: float = lerpf(24.0 * heavy, 12.0, contact_blend) * recovery_weight
	attack_pose_amount = recovery_weight
	_offset(_rig.hips, Vector3(0.08 * contact_blend, -0.06 * recovery_weight, -0.14 * contact_blend) * recovery_weight)
	_pose(_rig.hips, Vector3(lerpf(-8.0, 4.0, contact_blend), lerpf(-25.0, 8.0, contact_blend), 3.0 * contact_blend) * recovery_weight)
	_pose(_rig.spine, Vector3(lerpf(-13.0, 8.0, contact_blend), lerpf(-32.0, 10.0, contact_blend), 4.0 * contact_blend) * recovery_weight)
	_pose(_rig.head, Vector3(lerpf(7.0, -10.0, contact_blend), lerpf(17.0, -12.0, contact_blend), -4.0 * contact_blend) * recovery_weight)
	_pose(_rig.right_arm, Vector3(right_arm_x, lerpf(-16.0, 0.0, contact_blend) * recovery_weight, -12.0 * recovery_weight))
	_pose(_rig.right_forearm, Vector3(right_forearm_x, 4.0 * recovery_weight, 0.0))
	_pose(_rig.left_arm, Vector3(left_arm_x, lerpf(24.0, 2.0, contact_blend) * recovery_weight, 14.0 * recovery_weight))
	_pose(_rig.left_forearm, Vector3(left_forearm_x, -4.0 * recovery_weight, 0.0))
	_pose_attack_leg(_rig.left_leg, Vector3(lerpf(-16.0, 7.0, contact_blend) * recovery_weight, 0.0, -3.0 * recovery_weight))
	_pose_attack_leg(_rig.right_leg, Vector3(lerpf(14.0, -8.0, contact_blend) * recovery_weight, 0.0, 3.0 * recovery_weight))
	_pose_attack_leg(_rig.left_knee, Vector3(10.0 * contact_blend * recovery_weight, 0.0, 0.0))
	_pose_attack_leg(_rig.right_knee, Vector3(12.0 * recovery_weight, 0.0, 0.0))
	_pose(_rig.coat_left, Vector3(-22.0 * contact_blend * recovery_weight, -7.0 * recovery_weight, 10.0 * recovery_weight))
	_pose(_rig.coat_right, Vector3(-19.0 * contact_blend * recovery_weight, -5.0 * recovery_weight, -9.0 * recovery_weight))


func _apply_hurt() -> void:
	var progress: float = _action_progress()
	var weight: float = _reaction_phase_weight()
	var stumble: float = sin(progress * PI * 4.0) * weight * (1.0 - progress)
	_offset(_rig.hips, Vector3(0.035 * stumble, -0.07 * weight, 0.15 * weight))
	_pose(_rig.hips, Vector3(10.0 * weight, 5.0 * stumble, 4.0 * stumble))
	_pose(_rig.spine, Vector3(24.0 * weight, 9.0 * stumble, 7.0 * weight))
	_pose(_rig.head, Vector3(-17.0 * weight, -8.0 * stumble, -9.0 * weight))
	_pose(_rig.left_arm, Vector3(-25.0 * weight, 0.0, 22.0 * weight))
	_pose(_rig.right_arm, Vector3(-21.0 * weight, 0.0, -20.0 * weight))
	_pose(_rig.left_leg, Vector3(-12.0 * weight, 0.0, -4.0 * stumble))
	_pose(_rig.right_leg, Vector3(16.0 * weight, 0.0, 3.0 * stumble))
	_pose(_rig.right_knee, Vector3(22.0 * weight, 0.0, 0.0))


func _apply_shove() -> void:
	var progress: float = _action_progress()
	var weight: float = _reaction_phase_weight()
	var stumble: float = sin(progress * PI * 5.0) * weight * (1.0 - progress)
	_offset(_rig.hips, Vector3(0.06 * stumble, -0.13 * weight, 0.30 * weight))
	_pose(_rig.hips, Vector3(22.0 * weight, 7.0 * stumble, 5.0 * stumble))
	_pose(_rig.spine, Vector3(39.0 * weight, 11.0 * stumble, 5.0 * stumble))
	_pose(_rig.head, Vector3(-28.0 * weight, -8.0 * stumble, -5.0 * stumble))
	_pose(_rig.left_arm, Vector3(-38.0 * weight, -8.0 * weight, 52.0 * weight))
	_pose(_rig.right_arm, Vector3(-34.0 * weight, 10.0 * weight, -52.0 * weight))
	_pose(_rig.left_leg, Vector3(-20.0 * weight, 0.0, -6.0 * stumble))
	_pose(_rig.right_leg, Vector3(24.0 * weight, 0.0, 5.0 * stumble))
	_pose(_rig.left_knee, Vector3(14.0 * weight, 0.0, 0.0))
	_pose(_rig.right_knee, Vector3(34.0 * weight, 0.0, 0.0))
	_pose(_rig.coat_left, Vector3(-36.0 * weight, 0.0, 15.0 * weight))
	_pose(_rig.coat_right, Vector3(-31.0 * weight, 0.0, -13.0 * weight))


func _apply_parry() -> void:
	var progress: float = _action_progress()
	var weight: float = _reaction_phase_weight()
	var stumble: float = sin(progress * PI * 4.0) * weight * (1.0 - progress)
	_offset(_rig.hips, Vector3(-0.10 * weight, -0.12 * weight, 0.24 * weight))
	_pose(_rig.hips, Vector3(17.0 * weight, -27.0 * weight, -10.0 * weight + 6.0 * stumble))
	_pose(_rig.spine, Vector3(33.0 * weight, -36.0 * weight, -17.0 * weight + 8.0 * stumble))
	_pose(_rig.head, Vector3(-26.0 * weight, 27.0 * weight, 20.0 * weight))
	_pose(_rig.right_arm, Vector3(-54.0 * weight, 26.0 * weight, -84.0 * weight))
	_pose(_rig.right_forearm, Vector3(-32.0 * weight, 22.0 * weight, -20.0 * weight))
	_pose(_rig.left_arm, Vector3(-39.0 * weight, -17.0 * weight, 64.0 * weight))
	_pose(_rig.left_forearm, Vector3(-44.0 * weight, 0.0, 0.0))
	_pose(_rig.left_leg, Vector3(-25.0 * weight, 0.0, -10.0 * weight))
	_pose(_rig.right_leg, Vector3(18.0 * weight, 0.0, 8.0 * weight))
	_pose(_rig.left_knee, Vector3(18.0 * weight, 0.0, 0.0))
	_pose(_rig.right_knee, Vector3(34.0 * weight, 0.0, 0.0))


func _apply_death() -> void:
	var progress: float = _ease_in_out(_death_phase_progress())
	var buckle: float = smoothstep(0.0, 0.46, progress)
	var fall: float = smoothstep(0.28, 1.0, progress)
	_offset(_rig.hips, Vector3(0.0, -0.48 * buckle, -0.28 * fall))
	_pose(_rig.hips, Vector3(-18.0 * buckle - 48.0 * fall, 9.0 * fall, 8.0 * fall))
	_pose(_rig.spine, Vector3(-15.0 * buckle - 64.0 * fall, -12.0 * fall, -7.0 * fall))
	_pose(_rig.head, Vector3(12.0 * buckle - 31.0 * fall, 8.0 * fall, 12.0 * fall))
	_pose(_rig.left_leg, Vector3(24.0 * buckle, 0.0, -9.0 * buckle))
	_pose(_rig.right_leg, Vector3(31.0 * buckle, 0.0, 7.0 * buckle))
	_pose(_rig.left_knee, Vector3(62.0 * buckle, 0.0, 0.0))
	_pose(_rig.right_knee, Vector3(76.0 * buckle, 0.0, 0.0))
	_pose(_rig.left_arm, Vector3(-35.0 * fall, 0.0, 64.0 * fall))
	_pose(_rig.right_arm, Vector3(-48.0 * fall, 0.0, -58.0 * fall))
	_pose(_rig.left_forearm, Vector3(-48.0 * fall, 0.0, 0.0))
	_pose(_rig.right_forearm, Vector3(-36.0 * fall, 0.0, 0.0))
	_pose(_rig.coat_left, Vector3(-35.0 * fall, 0.0, 12.0 * fall))
	_pose(_rig.coat_right, Vector3(-32.0 * fall, 0.0, -10.0 * fall))


func _animated_pivots() -> Array[Node3D]:
	return [
		_rig.motion_root, _rig.hips, _rig.spine, _rig.head,
		_rig.left_arm, _rig.right_arm, _rig.left_forearm, _rig.right_forearm,
		_rig.left_leg, _rig.right_leg, _rig.left_knee, _rig.right_knee,
		_rig.coat_left, _rig.coat_right,
	]


func _pose(node: Node3D, degrees: Vector3) -> void:
	if node == null:
		return
	node.quaternion = Quaternion.from_euler(Vector3(
		deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)
	))


func _pose_add(node: Node3D, degrees: Vector3) -> void:
	if node == null:
		return
	var addition: Quaternion = Quaternion.from_euler(Vector3(
		deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)
	))
	node.quaternion = node.quaternion * addition


func _pose_attack_leg(node: Node3D, degrees: Vector3) -> void:
	if _attack_locomotion_weight() > 0.0:
		_pose_add(node, degrees)
	else:
		_pose(node, degrees)


func _offset(node: Node3D, offset: Vector3) -> void:
	if node != null and _rest_positions.has(node):
		node.position = _rest_positions[node] + offset


func _action_progress() -> float:
	return clampf(_action_elapsed / maxf(0.001, _action_duration), 0.0, 1.0)


func _ease_in_out(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


func _reaction_phase_weight() -> float:
	var phase := _presentation_phase()
	var progress: float = _presentation_phase_progress(phase)
	match phase:
		ActionTimingDefinition.Phase.WINDUP:
			return 0.15 * _ease_in_out(progress)
		ActionTimingDefinition.Phase.RELEASE:
			return _ease_out(progress)
		ActionTimingDefinition.Phase.IMPACT:
			return 1.0
		ActionTimingDefinition.Phase.RECOVERY:
			return 1.0 - _ease_in_out(progress)
		_:
			return 0.0


func _death_phase_progress() -> float:
	var phase := _presentation_phase()
	var progress: float = _presentation_phase_progress(phase)
	match phase:
		ActionTimingDefinition.Phase.WINDUP:
			return progress * 0.08
		ActionTimingDefinition.Phase.RELEASE:
			return 0.08 + progress * 0.42
		ActionTimingDefinition.Phase.IMPACT:
			return 0.50 + progress * 0.24
		ActionTimingDefinition.Phase.RECOVERY:
			return 0.74 + progress * 0.26
		_:
			return 1.0


func _presentation_phase() -> ActionTimingDefinition.Phase:
	if _presentation_timing == null or _presentation_timing.total_seconds() <= 0.0:
		return ActionTimingDefinition.Phase.COMPLETE
	var normalized_elapsed: float = clampf(_action_elapsed / maxf(0.001, _action_duration), 0.0, 1.0)
	return _presentation_timing.phase_at(normalized_elapsed * _presentation_timing.total_seconds())


func _presentation_phase_progress(phase: ActionTimingDefinition.Phase) -> float:
	if _presentation_timing == null or phase == ActionTimingDefinition.Phase.COMPLETE:
		return 1.0
	var normalized_elapsed: float = clampf(_action_elapsed / maxf(0.001, _action_duration), 0.0, 1.0)
	var contract_elapsed: float = normalized_elapsed * _presentation_timing.total_seconds()
	var phase_elapsed: float = contract_elapsed - _presentation_timing.phase_start_seconds(phase)
	return clampf(phase_elapsed / maxf(0.001, _presentation_timing.phase_duration(phase)), 0.0, 1.0)
