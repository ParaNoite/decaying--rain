extends "res://scripts/tests/firearm_range.gd"


func _ready() -> void:
	super._ready()
	_run_check.call_deferred()


func _run_check() -> void:
	var failures: int = 0
	DirAccess.make_dir_recursive_absolute("res://artifacts/weapon_animation")
	for id: StringName in [&"pistol", &"rifle"]:
		while player.loadout_component.get_current_weapon().weapon_id != id:
			player.loadout_component.switch_relative(1)
		await get_tree().create_timer(0.4).timeout
		var view: FirearmViewmodel = player.first_person_arms._firearm_visual
		var bolt: WeaponAnimatedPart = view.get_node("Alignment/BoltMotion")
		var ammo: int = player.loadout_component.get_magazine_ammo()
		var saw_motion: bool = false
		var saw_flash: bool = false
		var press: InputEventAction = InputEventAction.new()
		press.action = &"attack_primary"
		press.pressed = true
		Input.parse_input_event(press)
		for frame: int in 24:
			await RenderingServer.frame_post_draw
			if bolt.offset.z > 0.005:
				saw_motion = true
			if view.muzzle_flash.visible:
				saw_flash = true
				get_viewport().get_texture().get_image().save_png("res://artifacts/weapon_animation/" + str(id) + "_live_fire.png")
			if frame == 2:
				var release: InputEventAction = InputEventAction.new()
				release.action = &"attack_primary"
				Input.parse_input_event(release)
		if not saw_motion or not saw_flash or player.loadout_component.get_magazine_ammo() >= ammo:
			failures += 1
		print("LIVE_FIRE ", id, " motion=", saw_motion, " flash=", saw_flash, " ammo_consumed=", ammo - player.loadout_component.get_magazine_ammo())
	print("FIREARM_FIRE_VISUAL_SMOKE: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)
