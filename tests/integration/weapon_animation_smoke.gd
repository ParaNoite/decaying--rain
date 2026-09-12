extends Node


func _ready() -> void:
	var failures: int = 0
	for id: String in ["pistol", "rifle"]:
		var weapon: WeaponDefinition = load("res://resources/gameplay/weapons/" + id + ".tres")
		var view: FirearmViewmodel = weapon.first_person_scene.instantiate()
		add_child(view)
		var magazine: WeaponAnimatedPart = view.get_node("Alignment/MagazineMotion")
		var bolt: WeaponAnimatedPart = view.get_node("Alignment/BoltMotion")
		var mesh: Node3D = magazine.get_node(magazine.target_path)
		var bolt_mesh: Node3D = bolt.get_node(bolt.target_path)
		var rest: Transform3D = mesh.transform
		var bolt_rest: Transform3D = bolt_mesh.transform
		view.confirm_shot()
		view.sample_action(&"fire", weapon.primary_timing, 1.0 / 30.0)
		view.set_muzzle_flash(false)
		if not view.muzzle_flash.visible or not view.muzzle_light.visible:
			failures += 1
			push_error(id + ": confirmed flash lost when impact was skipped")
		view.reset_action()
		if view.muzzle_flash.visible or view.muzzle_light.visible:
			failures += 1
			push_error(id + ": flash did not reset")
		for fps: float in [30.0, 60.0, 144.0]:
			var peak: float = 0.0
			for frame: int in range(1, ceili(weapon.primary_timing.total_seconds() * fps)):
				view.sample_action(&"fire", weapon.primary_timing, float(frame) / fps)
				peak = maxf(peak, bolt.offset.z)
			if peak < 0.018:
				failures += 1
				push_error(id + ": fire motion too small at " + str(fps) + " FPS")
			view.reset_action()
		for multiplier: float in [0.5, 1.0, 2.0]:
			var timing: ActionTimingDefinition = weapon.reload_timing.duplicate()
			timing.windup_seconds *= multiplier
			timing.release_seconds *= multiplier
			timing.impact_seconds *= multiplier
			timing.recovery_seconds *= multiplier
			view.sample_action(&"reload", timing, timing.windup_seconds + timing.release_seconds * 0.35)
			if mesh.transform.is_equal_approx(rest):
				failures += 1
				push_error(id + ": magazine did not move")
			view.sample_action(&"reload", timing, timing.impact_start_seconds())
			if not mesh.transform.is_equal_approx(rest):
				failures += 1
				push_error(id + ": magazine not seated at gameplay completion")
			view.sample_action(&"reload", timing, timing.windup_seconds)
			view.reset_action()
			if not mesh.transform.is_equal_approx(rest):
				failures += 1
				push_error(id + ": interruption failed to restore magazine")
		view.sample_action(&"fire", weapon.primary_timing, weapon.primary_timing.impact_start_seconds() + weapon.primary_timing.impact_seconds * 0.85)
		if bolt_mesh.transform.is_equal_approx(bolt_rest):
			failures += 1
			push_error(id + ": bolt did not move")
		view.sample_action(&"fire", weapon.primary_timing, weapon.primary_timing.total_seconds())
		if not bolt_mesh.transform.is_equal_approx(bolt_rest):
			failures += 1
			push_error(id + ": bolt did not reset")
		view.free()
	print("WEAPON_ANIMATION_SMOKE: " + ("PASS" if failures == 0 else "FAIL " + str(failures)))
	get_tree().quit(failures)
