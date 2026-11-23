extends SceneTree
## Run: godot --headless --path . --script res://tests/prototype_validation.gd
## Omit --headless and append -- --capture to save rendered orientation checks.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var main := load("res://scenes/legacy_main.tscn").instantiate() as Node3D
	root.add_child(main)
	main.get_node("Collision").enabled = false # Free-running regression fixture.
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var player: CylinderRunnerPlayer = main.get_node("Player")
	var camera: CylinderRunnerCamera = main.get_node("RunnerCamera")
	var tunnel: RunnerTunnel = main.get_node("Tunnel")
	_check(tunnel.mesh.get_surface_count() == 2, "Both cylinder surfaces must be present")
	_check(tunnel.get_aabb().size.is_equal_approx(Vector3(16, 16, 200)), "Tunnel dimensions differ from 16 x 16 x 200")
	var arrays := tunnel.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var face_normal := -(vertices[indices[1]] - vertices[indices[0]]).cross(vertices[indices[2]] - vertices[indices[0]]).normalized()
	_check(face_normal.dot(normals[0]) > 0.99, "Triangle winding does not face inward")
	var outer_arrays := tunnel.mesh.surface_get_arrays(1)
	var outer_indices: PackedInt32Array = outer_arrays[Mesh.ARRAY_INDEX]
	var outer_normals: PackedVector3Array = outer_arrays[Mesh.ARRAY_NORMAL]
	var outer_face := -(vertices[outer_indices[1]] - vertices[outer_indices[0]]).cross(vertices[outer_indices[2]] - vertices[outer_indices[0]]).normalized()
	_check(outer_face.dot(outer_normals[0]) > 0.99 and outer_face.dot(face_normal) < -0.99, "Exterior winding/normals must face outward")
	_check(arrays[Mesh.ARRAY_COLOR] != outer_arrays[Mesh.ARRAY_COLOR], "Surface colors must differ")
	_validate_surface_switching(player, camera)
	_check(InputMap.action_get_events("steer_left").size() == 2, "Left key bindings missing")
	_check(InputMap.action_get_events("steer_right").size() == 2, "Right key bindings missing")
	# Exercise physical keyboard events through the actual controller input path.
	for key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		player.reset_run()
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		player._process(0.1)
		var expected_sign := -1.0 if key == KEY_A or key == KEY_LEFT else 1.0
		_check(player.angular_position * expected_sign > 0.0,
			"Keyboard event did not steer in expected direction: %s (%d)" % [OS.get_keycode_string(key), key])
		var release := event.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
	var results: Array[Vector3] = []
	for fps in [30, 60, 144]:
		player.reset_run()
		camera.snap_to_target()
		var delta := 1.0 / float(fps)
		for step in range(fps * 24):
			var previous_rotation := camera.global_basis.get_rotation_quaternion()
			var previous_relative := camera.global_position - player.global_position
			# Multiple revolutions in both directions, releases and repeated Z wraps.
			var steering := 1.0 if step < fps * 10 else (-1.0 if step < fps * 20 else 0.0)
			player.advance(delta, steering)
			camera._process(delta)
			var feet := player.position - player.basis.y * player.capsule_height * 0.5
			_check(absf(Vector2(feet.x, feet.y).length() - 8.0) < 0.0001, "Feet detached from wall")
			_check(player.basis.y.dot(-Vector3(player.position.x, player.position.y, 0).normalized()) > 0.9999, "Head is not inward")
			_check(player.basis.z.is_equal_approx(Vector3.BACK), "Player no longer faces -Z")
			_check(absf(camera.basis.determinant() - 1.0) < 0.0001, "Camera frame is invalid")
			_check(Vector2(camera.position.x, camera.position.y).length() < 8.0, "Camera escaped tunnel")
			_check(camera.position.z > player.position.z, "Camera is not behind player")
			_check(absf(previous_rotation.dot(camera.basis.get_rotation_quaternion())) > 0.99, "Camera snapped during rotation")
			_check((camera.position - player.position - previous_relative).length() < 0.6, "Camera jumped relative to player")
			_check(camera.basis.y.dot(player.basis.y) > 0.9, "Camera lost player's local up")
			_check(player.position.z >= -120.001 and player.position.z <= -19.999, "Longitudinal loop failed")
		results.append(Vector3(player.angular_position, player.angular_velocity, player.forward_position))
	for result in results:
		_check(result.distance_to(results[0]) < 0.001, "Movement differs between 30, 60 and 144 FPS")
	if _failures == 0:
		print("Validated both surfaces, Q switching/echo rejection, all four steering keys, wall contact, orientation, full turns, camera clearance, looping and 30/60/144 FPS consistency.")
	if "--capture" in OS.get_cmdline_user_args():
		for degrees in [0, 90, 180, 270]:
			for surface in ["inside", "outside"]:
				player.reset_run()
				player.angular_position = deg_to_rad(float(degrees))
				player.advance(0.0, 0.0)
				camera.snap_to_target()
				if surface == "outside":
					player.switch_surface()
					_settle_switch(player, camera)
				await process_frame
				await RenderingServer.frame_post_draw
				var path := "res://.godot/validation/%s_%d.png" % [surface, degrees]
				var error := root.get_texture().get_image().save_png(path)
				_check(error == OK, "Could not save rendered capture")
				print("Rendered capture: ", path)
	print("Validation failures: ", _failures)
	quit(0 if _failures == 0 else 1)


func _validate_surface_switching(player: CylinderRunnerPlayer, camera: CylinderRunnerCamera) -> void:
	for degrees in [0, 90, 180, 270, 360]:
		for steering in [-1.0, 0.0, 1.0]:
			player.reset_run()
			player.angular_position = deg_to_rad(float(degrees))
			player.angular_velocity = steering * deg_to_rad(player.angular_speed)
			player.advance(0.0, steering)
			camera.snap_to_target()
			for repetition in range(8):
				var before := Vector3(player.angular_position, player.angular_velocity, player.forward_position)
				var old_state := player.surface_state
				_press_q(player)
				_check(player.surface_state != old_state, "Q did not switch state")
				_check(before.is_equal_approx(Vector3(player.angular_position, player.angular_velocity, player.forward_position)), "Switch changed angle, steering velocity or Z")
				_check_surface_frame(player, camera)
				var old_position := player.position
				var right := player.basis.x
				player.advance(1.0 / 60.0, steering)
				camera._process(1.0 / 60.0)
				_check(is_equal_approx(player.position.z, old_position.z - player.movement_speed / 60.0), "Switch interrupted forward running")
				if steering != 0.0:
					_check((player.position - old_position).dot(right) * steering > 0.0, "Steering is inverted after switch")
				_check_surface_frame(player, camera)
	# Complete multiple revolutions in each mode, then switch while moving.
	# Repeat at distinct FPS, with longitudinal wraps and both steering directions.
	var results: Array[Vector3] = []
	for fps in [30, 60, 144]:
		player.reset_run()
		camera.snap_to_target()
		for step in range(fps * 24):
			if step == fps * 6 or step == fps * 12 or step == fps * 18:
				_press_q(player)
				_check_surface_frame(player, camera)
			var rotation_before := camera.basis.get_rotation_quaternion()
			var relative_before := camera.position - player.position
			var right := player.basis.x
			var position_before := player.position
			var steering := 1.0 if step < fps * 12 else -1.0
			player.advance(1.0 / float(fps), steering)
			camera._process(1.0 / float(fps))
			_check_surface_frame(player, camera)
			_check(absf(rotation_before.dot(camera.basis.get_rotation_quaternion())) > 0.99, "Camera snapped during surface steering")
			_check((camera.position - player.position - relative_before).length() < 0.6, "Camera jumped during surface run/loop")
			if step % (fps * 6) > fps:
				_check((player.position - position_before).dot(right) * steering > 0.0, "Sustained surface steering is inverted")
			_check(player.position.z >= -120.001 and player.position.z <= -19.999, "Surface loop failed")
		results.append(Vector3(player.angular_position, player.angular_velocity, player.forward_position))
	for result in results:
		_check(result.distance_to(results[0]) < 0.001, "Switching movement differs between FPS")
	player.reset_run()
	# Check actual arrow/A/D input in OUTSIDE mode as well as existing inside tests.
	player.switch_surface()
	_settle_switch(player, camera)
	for key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		player.angular_velocity = 0.0
		var before := player.position
		var right := player.basis.x
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		player._process(0.1)
		var direction := -1.0 if key == KEY_A or key == KEY_LEFT else 1.0
		_check((player.position - before).dot(right) * direction > 0.0, "Outside keyboard steering is inverted")
		var release := event.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
	player.reset_run()


func _press_q(player: CylinderRunnerPlayer) -> void:
	# Enable this node's event handling while the deterministic test scene is paused.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var state_after_press := player.surface_state
	var echo := event.duplicate() as InputEventKey
	echo.echo = true
	Input.parse_input_event(echo)
	Input.flush_buffered_events()
	_check(player.surface_state == state_after_press, "Holding Q toggles repeatedly")
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	_check(player.surface_state == state_after_press, "Q release toggles state")
	player.process_mode = Node.PROCESS_MODE_INHERIT
	_settle_switch(player, player.get_parent().get_node("RunnerCamera"))


func _settle_switch(player: CylinderRunnerPlayer, camera: CylinderRunnerCamera) -> void:
	# Endpoint regression checks only; transition_validation tests actual timing.
	if player.transition.active:
		player.transition.advance(player.transition.duration, 0.0)
		player._finish_switch()
		camera.snap_to_target()


func _check_surface_frame(player: CylinderRunnerPlayer, camera: CylinderRunnerCamera) -> void:
	var sign_value := player.get_surface_sign()
	var radial := Vector3(player.position.x, player.position.y, 0.0).normalized()
	var feet := player.position - player.basis.y * player.capsule_height * 0.5
	_check(absf(Vector2(feet.x, feet.y).length() - player.cylinder_radius) < 0.0001, "Surface feet are not on cylinder")
	_check(player.basis.y.dot(radial * sign_value) > 0.9999, "Surface head orientation is wrong")
	_check(player.basis.z.is_equal_approx(Vector3.BACK), "Surface forward is not -Z")
	_check(camera.basis.y.dot(player.basis.y) > 0.9, "Surface camera up does not match player")
	_check(absf(camera.basis.determinant() - 1.0) < 0.0001, "Surface camera basis is invalid")
	_check(camera.position.z > player.position.z, "Surface camera is not behind player")
	var camera_xy := Vector2(camera.position.x, camera.position.y)
	_check((camera_xy.length() - player.cylinder_radius) * sign_value > 0.1, "Camera is on the wrong side of wall")
	# The closest point of the entire camera-to-player sight line must stay outside
	# when outside. Inside, a segment between two interior points stays in the disk.
	if sign_value > 0.0:
		var segment := Vector2(player.position.x, player.position.y) - camera_xy
		var fraction := clampf(-camera_xy.dot(segment) / maxf(segment.length_squared(), 0.000001), 0.0, 1.0)
		_check((camera_xy + segment * fraction).length() > player.cylinder_radius + camera.near, "Cylinder obscures exterior player")
