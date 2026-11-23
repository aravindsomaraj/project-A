extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var p = main.get_node("Player")
	var g = main.get_node("Generator")
	g.forced_patterns = PackedInt32Array([9,7,4,2])
	g.reset_course()
	p.forward_position = -90
	p._update_surface_transform()
	main.get_node("RunnerCamera").snap_to_target()
	g.ensure_ahead(-290)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/validation/generated_track.png")
	print("Pool: ",g.pool.size()," sequence: ",g.history)
	quit()
