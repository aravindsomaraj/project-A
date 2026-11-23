extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/legacy_main.tscn").instantiate()
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var p = scene.get_node("Player")
	var camera = scene.get_node("RunnerCamera")
	var cases := [["partial", -23.0, 0.0, false], ["full", -48.0, 90.0, false], ["outer", -73.0, 0.0, true], ["second", -95.0, 180.0, false], ["game_over", -38.0, 0.0, false]]
	for entry in cases:
		scene.get_node("RunStatus").restart()
		p.forward_position = entry[1]
		p.angular_position = deg_to_rad(entry[2])
		p.surface_state = p.SurfaceState.OUTSIDE if entry[3] else p.SurfaceState.INSIDE
		p._update_surface_transform()
		camera.snap_to_target()
		if entry[0] == "game_over":
			p.advance(0.2,0)
		camera._process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/validation/obstacle_%s.png" % entry[0])
	print("Rendered four obstacles and game over.")
	quit()
