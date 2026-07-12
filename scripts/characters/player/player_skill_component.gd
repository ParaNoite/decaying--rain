class_name PlayerSkillComponent
extends Node

signal active_skill_changed(skill_id: StringName, cooldown_remaining: float)
signal active_skill_charge_started(skill_id: StringName, windup_seconds: float)
signal active_skill_triggered(skill_id: StringName)
signal action_blocked(action_id: StringName, reason_id: StringName)

const EFFECT_CHARGED_BEAM: StringName = &"charged_beam"
const ACTION_ACTIVE_SKILL: StringName = &"active_skill"

@export var profession_component_path: NodePath = ^"../ProfessionComponent"
@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var ray_origin_path: NodePath = ^"../../Head/Camera3D"
@export_flags_3d_physics var beam_collision_mask: int = 4

@onready var profession_component = get_node_or_null(profession_component_path)
@onready var stamina: StaminaComponent = get_node_or_null(stamina_path) as StaminaComponent
@onready var ray_origin: Node3D = get_node_or_null(ray_origin_path) as Node3D

var active_skill: Resource
var cooldown_remaining: float = 0.0

var _event_bus = null
var _pending_skill: Resource
var _pending_fire_time: float = 0.0


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	refresh_from_profession()
	_broadcast_skill_changed()


func refresh_from_profession() -> void:
	if profession_component == null:
		return
	if not profession_component.has_method("get_active_skill"):
		return
	active_skill = profession_component.get_active_skill()


func update(body: Node3D, input_reader: PlayerInputReader, constraints: Dictionary, delta: float) -> Dictionary:
	var skill_constraints: Dictionary = {}
	_tick_cooldown(delta)

	if _pending_skill != null:
		_pending_fire_time = maxf(0.0, _pending_fire_time - delta)
		skill_constraints["combat_blocked"] = true
		skill_constraints["mobility_blocked"] = true
		if _pending_fire_time <= 0.0:
			_fire_pending_skill(body)

	if input_reader.consume_active_skill():
		try_trigger(body, constraints)

	return skill_constraints


func try_trigger(body: Node3D, constraints: Dictionary) -> bool:
	if active_skill == null:
		_block(&"no_skill")
		return false

	if _pending_skill != null:
		_block(&"charging")
		return false

	if cooldown_remaining > 0.0:
		_block(&"cooldown")
		return false

	if constraints.get("movement_disabled", false) or constraints.get("combat_blocked", false) or constraints.get("watch_active", false):
		_block(&"action_locked")
		return false

	if not _phase_allowed(active_skill):
		_block(&"phase_locked")
		return false

	if stamina != null and not stamina.can_consume(active_skill.stamina_cost):
		_block(&"stamina")
		return false

	if stamina != null:
		stamina.consume(active_skill.stamina_cost)

	_pending_skill = active_skill
	_pending_fire_time = active_skill.windup_seconds
	active_skill_charge_started.emit(active_skill.skill_id, active_skill.windup_seconds)
	if _event_bus != null:
		_event_bus.debug_test_notice.emit(active_skill.activation_message, &"skill")
	_broadcast_skill_changed()

	if _pending_fire_time <= 0.0:
		_fire_pending_skill(body)
	return true


func is_ready() -> bool:
	return active_skill != null and cooldown_remaining <= 0.0 and _pending_skill == null


func _tick_cooldown(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return

	var was_ready: bool = is_ready()
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	var now_ready: bool = is_ready()
	if now_ready and not was_ready:
		_broadcast_ready()
	_broadcast_skill_changed()


func _fire_pending_skill(body: Node3D) -> void:
	var skill: Resource = _pending_skill
	_pending_skill = null
	if skill == null:
		return

	match skill.effect_id:
		EFFECT_CHARGED_BEAM:
			_fire_charged_beam(body, skill)
		_:
			_block(&"unknown_effect")
			return

	cooldown_remaining = skill.cooldown_seconds
	active_skill_triggered.emit(skill.skill_id)
	if _event_bus != null:
		_event_bus.player_active_skill_triggered.emit(skill.skill_id)
	_broadcast_skill_changed()


func _fire_charged_beam(body: Node3D, skill: Resource) -> void:
	if body == null or ray_origin == null:
		_block(&"no_ray_origin")
		return

	var origin: Vector3 = ray_origin.global_position
	var direction: Vector3 = -ray_origin.global_transform.basis.z.normalized()
	var end: Vector3 = origin + direction * skill.beam_range
	var visual_origin: Vector3 = _beam_visual_origin(origin, skill)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = beam_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if body is CollisionObject3D:
		var collision_body: CollisionObject3D = body as CollisionObject3D
		query.exclude = [collision_body.get_rid()]

	var result: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_show_beam_visual(visual_origin, end, skill)
		_show_beam_impact(end, skill)
		_emit_skill_feedback("CHARGED BEAM MISSED", &"neutral")
		return

	var collider: Object = result.get("collider")
	if not (collider is Node):
		_emit_skill_feedback("CHARGED BEAM HIT NOTHING", &"neutral")
		return

	var target: Node = collider as Node
	var hit_position: Vector3 = _hit_position_from_result(result, target, end)
	_show_beam_visual(visual_origin, hit_position, skill)
	_show_beam_impact(hit_position, skill)

	var hit_data: DamageEventData = DamageEventData.new()
	hit_data.attacker_id = body.get_instance_id()
	hit_data.target_id = target.get_instance_id()
	hit_data.amount = skill.beam_damage
	hit_data.damage_type = &"energy"
	hit_data.source_tags = skill.beam_tags.duplicate()
	hit_data.hit_position = hit_position

	if target.has_method("receive_damage"):
		target.receive_damage(hit_data)
	elif target.has_method("apply_damage"):
		target.apply_damage(skill.beam_damage)
	elif _event_bus != null:
		_event_bus.combat_hit.emit(hit_data)

	_emit_skill_feedback("%s -%.0f" % [skill.fired_message.to_upper(), skill.beam_damage], &"success")


func _phase_allowed(skill: Resource) -> bool:
	if skill.allowed_phases.is_empty():
		return true
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return true
	var current_phase: StringName = game_manager.current_phase
	return skill.allowed_phases.has(current_phase)


func _hit_position_from_result(result: Dictionary, target: Node, fallback: Vector3) -> Vector3:
	if result.has("position"):
		return result["position"]
	if target is Node3D:
		var target_3d: Node3D = target as Node3D
		return target_3d.global_position
	return fallback


func _beam_visual_origin(fallback_origin: Vector3, skill: Resource) -> Vector3:
	if ray_origin == null:
		return fallback_origin
	return ray_origin.to_global(skill.beam_visual_origin_offset)


func _show_beam_visual(origin: Vector3, target: Vector3, skill: Resource) -> void:
	var length: float = origin.distance_to(target)
	if length <= 0.05:
		return

	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var beam_mesh: BoxMesh = BoxMesh.new()
	var beam_width: float = maxf(0.01, skill.beam_width)
	beam_mesh.size = Vector3(beam_width, beam_width * 1.4, length)

	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.name = "ChargedBeamVisual"
	beam.mesh = beam_mesh
	beam.material_override = _beam_material(skill, 2.8)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)

	beam.global_position = origin.lerp(target, 0.5)
	beam.look_at(target, Vector3.UP)

	var duration: float = maxf(0.02, skill.beam_visual_duration)
	var tween: Tween = beam.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(beam, "transparency", 1.0, duration)
	tween.tween_callback(beam.queue_free)


func _show_beam_impact(position: Vector3, skill: Resource) -> void:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var sphere_mesh: SphereMesh = SphereMesh.new()
	var impact_size: float = maxf(0.01, skill.beam_impact_size)
	sphere_mesh.radius = impact_size
	sphere_mesh.height = impact_size * 2.0
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8

	var impact: MeshInstance3D = MeshInstance3D.new()
	impact.name = "ChargedBeamImpact"
	impact.mesh = sphere_mesh
	impact.material_override = _beam_material(skill, 3.6)
	impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(impact)
	impact.global_position = position

	var duration: float = maxf(0.02, skill.beam_visual_duration)
	var tween: Tween = impact.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(impact, "scale", Vector3.ONE * 1.9, duration)
	tween.tween_property(impact, "transparency", 1.0, duration)
	tween.chain().tween_callback(impact.queue_free)


func _beam_material(skill: Resource, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = skill.beam_color
	material.emission_enabled = true
	material.emission = Color(skill.beam_color.r, skill.beam_color.g, skill.beam_color.b, 1.0)
	material.emission_energy_multiplier = energy
	return material


func _block(reason_id: StringName) -> void:
	action_blocked.emit(ACTION_ACTIVE_SKILL, reason_id)
	if _event_bus != null:
		_event_bus.player_action_blocked.emit(ACTION_ACTIVE_SKILL, reason_id)
		_event_bus.debug_test_notice.emit("Active skill blocked: %s" % String(reason_id), &"skill")


func _broadcast_ready() -> void:
	if active_skill == null:
		return
	if _event_bus != null:
		_event_bus.debug_test_notice.emit(active_skill.ready_message, &"skill")


func _broadcast_skill_changed() -> void:
	var skill_id: StringName = &"none" if active_skill == null else active_skill.skill_id
	active_skill_changed.emit(skill_id, cooldown_remaining)
	if _event_bus != null:
		_event_bus.player_active_skill_changed.emit(skill_id, cooldown_remaining, 1 if is_ready() else 0)


func _emit_skill_feedback(message: String, tone: StringName) -> void:
	if _event_bus == null:
		return
	_event_bus.combat_feedback.emit(message, tone)
	_event_bus.debug_test_notice.emit(message, &"skill")
