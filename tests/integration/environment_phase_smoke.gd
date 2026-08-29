extends Node

const MVP_SCENE: PackedScene = preload("res://scenes/levels/mvp_skeleton.tscn")
const MVP_RUN_CONFIG: RunConfig = preload("res://resources/gameplay/mvp_run_config.tres")
const TRANSITION_WAIT_SECONDS: float = 0.95
const BASE_DRY_MIN: Vector2 = Vector2(-7.0, -7.0)
const BASE_DRY_MAX: Vector2 = Vector2(7.0, 2.0)


func _ready() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager autoload missing")
	game_manager.start_mvp_run(MVP_RUN_CONFIG)

	var level: Node3D = MVP_SCENE.instantiate() as Node3D
	level.set("auto_start_run", false)
	add_child(level)
	await get_tree().process_frame

	var rain_root: Node3D = level.get_node_or_null("RainOutsideBase") as Node3D
	var shelter: Area3D = level.get_node_or_null("BaseRainShelter") as Area3D
	var player: CharacterBody3D = level.get_node_or_null("Player") as CharacterBody3D
	var world_environment: WorldEnvironment = level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun: DirectionalLight3D = level.get_node_or_null("Sun") as DirectionalLight3D
	_check(rain_root != null, "mvp_skeleton missing RainOutsideBase")
	_check(shelter != null and shelter.collision_mask == 2, "base shelter must detect the player collision layer")
	_check(player != null, "mvp_skeleton missing Player")
	var rain_emitters: Array[GPUParticles3D] = []
	var total_particle_count: int = 0
	for child: Node in rain_root.get_children():
		_check(child is GPUParticles3D, "RainOutsideBase may only contain particle emitters")
		var emitter: GPUParticles3D = child as GPUParticles3D
		rain_emitters.append(emitter)
		total_particle_count += emitter.amount
		_check(emitter.draw_pass_1 != null, "%s needs a visible draw mesh" % emitter.name)
		_check_emitter_outside_base(emitter)
	_check(rain_emitters.size() == 4, "rain needs four emitters around the base dry zone")
	_check(total_particle_count >= 1000, "rain particle count is too low for the playable area")
	_check(world_environment != null and world_environment.environment != null, "mvp_skeleton missing Environment")
	_check(sun != null, "mvp_skeleton missing Sun")

	var environment: Environment = world_environment.environment
	var normal_background_luminance: float = environment.background_color.get_luminance()
	var normal_ambient_energy: float = environment.ambient_light_energy
	var normal_sun_energy: float = sun.light_energy
	_check(rain_emitters.all(func(emitter: GPUParticles3D) -> bool: return not emitter.emitting), "rain must be disabled during daylight")

	player.position = Vector3(0.0, 1.0, 40.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	game_manager.change_phase(GameManager.PHASE_RAIN)
	await get_tree().process_frame
	_check(rain_emitters.all(func(emitter: GPUParticles3D) -> bool: return emitter.emitting), "all outside-base rain emitters must start during rain")
	await get_tree().create_timer(TRANSITION_WAIT_SECONDS).timeout
	_check(environment.background_color.get_luminance() < normal_background_luminance * 0.45, "rain sky did not become visibly darker")
	_check(environment.ambient_light_energy < normal_ambient_energy * 0.6, "rain ambient light did not dim")
	_check(sun.light_energy < normal_sun_energy * 0.3, "rain sunlight did not dim")

	player.position = Vector3(0.0, 1.0, -2.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(TRANSITION_WAIT_SECONDS).timeout
	_check(rain_emitters.all(func(emitter: GPUParticles3D) -> bool: return emitter.emitting), "outside rain must continue while player shelters in base")
	_check(is_equal_approx(environment.ambient_light_energy, normal_ambient_energy), "base shelter did not restore normal screen lighting")

	player.position = Vector3(0.0, 1.0, 40.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(TRANSITION_WAIT_SECONDS).timeout
	_check(environment.ambient_light_energy < normal_ambient_energy * 0.6, "leaving base during rain did not darken the screen")

	game_manager.change_phase(GameManager.PHASE_SETTLEMENT)
	await get_tree().process_frame
	_check(rain_emitters.all(func(emitter: GPUParticles3D) -> bool: return not emitter.emitting), "rain particles must stop outside rain phase")
	await get_tree().create_timer(TRANSITION_WAIT_SECONDS).timeout
	_check(is_equal_approx(environment.background_color.get_luminance(), normal_background_luminance), "normal sky was not restored")
	_check(is_equal_approx(environment.ambient_light_energy, normal_ambient_energy), "normal ambient light was not restored")
	_check(is_equal_approx(sun.light_energy, normal_sun_energy), "normal sunlight was not restored")


	print("ENVIRONMENT_PHASE_SMOKE: PASS")
	get_tree().quit()


func _check_emitter_outside_base(emitter: GPUParticles3D) -> void:
	var material: ParticleProcessMaterial = emitter.process_material as ParticleProcessMaterial
	_check(material != null, "%s missing ParticleProcessMaterial" % emitter.name)
	var extents: Vector3 = material.emission_box_extents
	var emitter_min: Vector2 = Vector2(emitter.position.x - extents.x, emitter.position.z - extents.z)
	var emitter_max: Vector2 = Vector2(emitter.position.x + extents.x, emitter.position.z + extents.z)
	var overlaps_base: bool = (
		emitter_min.x < BASE_DRY_MAX.x
		and emitter_max.x > BASE_DRY_MIN.x
		and emitter_min.y < BASE_DRY_MAX.y
		and emitter_max.y > BASE_DRY_MIN.y
	)
	_check(not overlaps_base, "%s emission box overlaps the base dry zone" % emitter.name)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ENVIRONMENT_PHASE_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)
