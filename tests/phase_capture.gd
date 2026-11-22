extends SceneTree
## Rendered regression: each cardinal angle, both directions, three phase samples.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("Collision").enabled = false # Free-running regression fixture.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var p = scene.get_node("Player")
	var c = scene.get_node("RunnerCamera")
	var failures := 0
	for degrees in [0, 90, 180, 270]:
		p.reset_run()
		p.angular_position = deg_to_rad(float(degrees))
		p.advance(0.0, 0)
		c.snap_to_target()
		for direction in ["out", "in"]:
			await process_frame
			await RenderingServer.frame_post_draw
			p.switch_surface()
			var previous_time := 0.0
			for time in [0.05, 0.125, 0.20, 0.25]:
				p.advance(time - previous_time, 1.0)
				c._process(time - previous_time)
				previous_time = time
				await process_frame
				await RenderingServer.frame_post_draw
				var frame = root.get_texture().get_image()
				var path := "res://.godot/validation/phase_%s_%d_%d.png" % [direction, degrees, roundi(time * 1000)]
				frame.save_png(path)
				var low := 1.0
				var high := 0.0
				for x in range(0, frame.get_width(), 32):
					for y in range(0, frame.get_height(), 32):
						var luminance: float = frame.get_pixel(x, y).get_luminance()
						low = minf(low, luminance)
						high = maxf(high, luminance)
				if high - low < 0.1:
					push_error("Blank/flat frame: " + path)
					failures += 1
			p.advance(0.2, 0)
			c._process(0.2)
	print("Rendered phase checks: ", failures, " failures; 32 captures saved.")
	quit(0 if failures == 0 else 1)

