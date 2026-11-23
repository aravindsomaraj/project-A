extends SceneTree
var failures := 0
var scene: Node3D
var p: CylinderRunnerPlayer
var collision: RunnerCollision
var obstacle: RunnerObstacle
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func start(angle: float, z: float, outside: bool = false) -> void:
	scene.get_node("RunStatus").restart()
	p.movement_speed = 18.0
	p.angular_position = deg_to_rad(angle)
	p.forward_position = z
	p.surface_state = p.SurfaceState.OUTSIDE if outside else p.SurfaceState.INSIDE
	p._update_surface_transform()
	scene.get_node("RunnerCamera").snap_to_target()
func run() -> void:
	scene = load("res://scenes/legacy_main.tscn").instantiate()
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	p = scene.get_node("Player")
	collision = scene.get_node("Collision")
	var fixtures := Node.new()
	scene.add_child(fixtures)
	obstacle = load("res://scenes/obstacle.tscn").instantiate()
	fixtures.add_child(obstacle)
	collision.obstacle_root = fixtures
	obstacle.z_position = -40.0
	obstacle.width_degrees = 40.0
	for angle in [0.0, 90.0, 180.0, 270.0, 359.0]:
		obstacle.angle_degrees = angle
		for fps in [30,60,144]:
			start(angle, -35)
			for i in range(fps):
				p.advance(1.0 / fps, 0)
			check(p.dead, "Partial contact missed at angle/FPS")
			check(absf(p.forward_position - (-40 + obstacle.depth * 0.5 + p.capsule_radius)) < 0.001, "Did not stop at contact")
			var stopped := p.position
			p.advance(1,1)
			p.switch_surface()
			check(p.position.is_equal_approx(stopped), "Dead player moved")
		start(angle + 90, -35)
		p.advance(0.6,0)
		check(not p.dead, "Safe angle collided")
	# Steer away using actual movement rather than teleporting across the barrier.
	obstacle.angle_degrees = 0
	start(0,-25)
	for i in range(60):
		p.advance(1.0/60.0, 1)
	check(not p.dead and p.forward_position < -40, "Steering failed to avoid partial")
	# Seam crossing and capsule-edge padding.
	start(359, -35)
	p.advance(0.5,0)
	check(p.dead, "0/360 seam missed")
	start(22,-35)
	p.advance(0.5,0)
	check(p.dead, "Capsule width not included")
	start(0,-20)
	p.movement_speed = 1000
	p.advance(0.1,0)
	check(p.dead and p.forward_position > -40, "High speed tunneled through barrier")
	start(0,-119)
	p.movement_speed = 1000
	p.advance(0.1,0)
	check(p.dead and p.forward_position > -40, "Collision missed across longitudinal wrap")
	obstacle.kind = RunnerObstacle.Kind.FULL_INNER
	for angle in [0,90,180,270,359]:
		start(angle,-35)
		p.advance(0.5,1)
		check(p.dead, "Full barrier avoided by steering")
	start(0,-30)
	p.switch_surface()
	p.advance(0.25,0)
	p.advance(0.5,0)
	check(not p.dead and p.forward_position < -40, "Early switch did not avoid full inner")
	start(0,-38)
	p.switch_surface()
	p.advance(0.2,0)
	check(p.dead and p.surface_state == p.SurfaceState.INSIDE, "Source surface invulnerability during outgoing switch")
	# Finish during a large frame: source time interval catches collision before completion.
	start(0,-35)
	p.switch_surface()
	p.advance(0.5,0)
	check(p.dead, "Mid-frame source collision missed")
	# Destination interval catches entry only after a switch into the barrier completes.
	start(0,-34,true)
	p.switch_surface()
	p.advance(0.5,0)
	check(p.dead, "Mid-frame destination collision missed")
	obstacle.kind = RunnerObstacle.Kind.PARTIAL_OUTER
	start(0,-35)
	p.advance(0.5,0)
	check(not p.dead, "Outer obstacle hit inside player")
	start(0,-35,true)
	p.advance(0.5,0)
	check(p.dead, "Outer obstacle failed to hit outside player")
	start(0,-38,true)
	p.switch_surface()
	p.advance(0.2,0)
	check(p.dead, "Source outside became invulnerable during switch")
	check(scene.get_node("RunStatus").panel.visible, "Game over UI hidden")
	# R uses actual input dispatch. RunStatus remains active while fixture is paused.
	var status = scene.get_node("RunStatus")
	status.process_mode = Node.PROCESS_MODE_ALWAYS
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await process_frame
	check(not p.dead and p.position.is_equal_approx(Vector3(0,-7,-20)), "R did not restore initial pose")
	check(not p.transition.active and p.transition.cooldown_left == 0 and p.surface_state == 0, "Restart left transition state")
	check(not status.panel.visible, "Restart left game over UI")
	p.end_run()
	await process_frame
	var point: Vector2 = status.restart_button.get_global_rect().get_center()
	for down in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform() * point
		touch.pressed = down
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
	await process_frame
	check(not p.dead, "Touch restart button failed without mouse emulation")
	check(p.get_node("TouchInput").is_processing_unhandled_input(), "Touch input not restored")
	# End-to-end fixed course: steer off the floor, switch early, stay outside
	# at a safe angle, pass all four barriers and the longitudinal wrap.
	collision.obstacle_root = scene.get_node("Obstacles")
	start(0,-20)
	var switched := false
	for frame in range(360):
		if not switched and p.forward_position < -50:
			p.switch_surface()
			switched = true
		var steering := 1.0 if not switched and p.angular_position < deg_to_rad(80.0) else 0.0
		p.advance(1.0/60.0, steering)
		scene.get_node("RunnerCamera")._process(1.0/60.0)
	check(not p.dead and switched and p.forward_position > -40, "Fixed course could not be completed and looped")
	print("Obstacle validation failures: ", failures)
	quit(0 if failures == 0 else 1)
