extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://scenes/legacy_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("Collision").enabled = false # Free-running regression fixture.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var p = scene.get_node("Player")
	var c = scene.get_node("RunnerCamera")
	for fps in [30, 60, 144]:
		for degrees in [0, 90, 180, 270, 360]:
			p.reset_run()
			p.angular_position = deg_to_rad(float(degrees))
			p.advance(0.0, 0.0)
			c.snap_to_target()
			for repeat in range(4):
				var old_state = p.surface_state
				var start_z = p.forward_position
				var camera_z: float = c.position.z
				p.switch_surface()
				check(is_equal_approx(c.position.z, camera_z), "Switch reset camera longitudinal offset")
				check(p.transition.active, "Transition did not start")
				var frames := 0
				while p.transition.active:
					p.switch_surface()
					var old_basis = p.basis
					var previous_z: float = p.forward_position
					var previous_angle: float = p.angular_position
					var source_z: float = c._source_camera.position.z
					p.advance(1.0 / fps, 1.0)
					c._process(1.0 / fps)
					frames += 1
					check(absf(p.forward_position - previous_z + p.movement_speed / fps) < 0.0001, "Per-frame forward speed changed")
					if p.transition.active:
						check(absf(c._source_camera.position.z - source_z + p.movement_speed / fps) < 0.0001, "Live source view stopped moving")
					check(absf(angle_difference(previous_angle, p.angular_position)) > 0.0, "Steering froze during phase")
					check(absf(c.basis.determinant() - 1.0) < 0.001, "Camera basis invalid")
					check(absf(old_basis.get_rotation_quaternion().dot(p.basis.get_rotation_quaternion())) > 0.9, "Orientation jumped")
					check((Vector2(c.position.x, c.position.y).length() - 8.0) * p.get_surface_sign() > 0.5, "Camera crossed wall")
					check(c.basis.y.dot(p.basis.y) > 0.9, "Camera roll is unstable")
					check(not c.is_position_behind(p.global_position), "Camera points away from player")
					if p.get_surface_sign() > 0:
						var start := Vector2(c.position.x, c.position.y)
						var ray := Vector2(p.position.x, p.position.y) - start
						var t := clampf(-start.dot(ray) / maxf(ray.length_squared(), 0.00001), 0, 1)
						check((start + ray * t).length() > 8.1, "Wall obscures player")
					var screen_size: Vector2 = c.get_viewport().get_visible_rect().size
					var screen_position: Vector2 = c.unproject_position(p.global_position) / screen_size
					check(screen_position.distance_to(Vector2(0.5, 0.5)) < 0.42, "Player left camera framing")
					check(frames <= fps, "Transition failed to finish")
					if frames > fps:
						break
				check(p.surface_state != old_state, "Surface did not change")
				check(absf(frames / float(fps) - 0.25) <= 1.0 / fps + 0.001, "Wrong duration")
				check(absf(p.forward_position - (start_z - frames * 18.0 / fps)) < 0.001, "Forward motion interrupted")
				p.switch_surface()
				check(not p.transition.active, "Cooldown did not reject input")
				p.advance(0.2, 0.0)
				c._process(0.2)
	# Cross the longitudinal loop while phasing, with steering already in motion.
	p.reset_run()
	p.switch_surface()
	for step in range(20):
		p.advance(1.0 / 60.0, 0.0)
		c._process(1.0 / 60.0)
		check(is_zero_approx(p.angular_position), "Switch introduced angular drift without input")
	p.reset_run()
	p.advance(0.4, 1.0)
	p.forward_position = -119.5
	p.advance(0.0, 1.0)
	c.snap_to_target()
	p.switch_surface()
	for step in range(20):
		var relative: Vector3 = c.position - p.position
		p.advance(1.0 / 60.0, 1.0)
		c._process(1.0 / 60.0)
		check((c.position - p.position - relative).length() < 0.6, "Camera jumped at phase loop/steering resume")
	print("Transition validation failures: ", failures)
	quit(0 if failures == 0 else 1)
