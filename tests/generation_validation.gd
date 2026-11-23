extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func steer(p: CylinderRunnerPlayer, angle: float) -> float:
	return -p.get_surface_sign() * clampf(angle_difference(p.angular_position,deg_to_rad(angle)) * 3.0 / deg_to_rad(p.angular_speed),-1,1)
func run() -> void:
	var pair_count := 0
	for speed in [18.0,40.0,80.0]:
		var scene = load("res://scenes/main.tscn").instantiate()
		var p: CylinderRunnerPlayer = scene.get_node("Player")
		p.movement_speed = speed
		root.add_child(scene)
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		var g: RunnerGenerator = scene.get_node("Generator")
		check(g.patterns.size() >= 10, "Pattern library too small")
		check(g.segment_length >= g.required_spacing(), "Spacing budget not met")
		for a in range(g.patterns.size()):
			for b in range(g.patterns.size()):
				g.forced_patterns = PackedInt32Array([a,b])
				p.reset_run()
				g.reset_course()
				p.forward_position = -g.segment_length * 1.5 + 3.0
				p.angular_position = deg_to_rad(g.patterns[a].angle)
				p.surface_state = int(g.patterns[a].surface)
				p.transition.cooldown_left = p.switch_cooldown
				p._update_surface_transform()
				var first_z := -g.segment_length * 1.5
				var second_z := -g.segment_length * 2.5
				# Hold through source collision slab, allow reaction delay, then choose
				# the next safe route using real controller steering and switching.
				var frames := 0
				while p.forward_position > second_z - 3.0 and not p.dead and frames < 2000:
					var target: Dictionary = g.patterns[a]
					if p.forward_position < first_z - 2.0 - speed * g.reaction_time:
						target = g.patterns[b]
						if p.surface_state != int(target.surface):
							p.switch_surface()
					p.advance(1.0/60.0, steer(p,target.angle))
					g.retire_behind()
					frames += 1
				check(not p.dead and frames < 2000, "Unsafe pair %d -> %d at speed %s" % [a,b,speed])
				pair_count += 1
		# Initial approach from reset must be valid for every first pattern.
		for a in range(g.patterns.size()):
			g.forced_patterns = PackedInt32Array([a])
			p.reset_run()
			g.reset_course()
			var target: Dictionary = g.patterns[a]
			for frame in range(ceili((1.5*g.segment_length - 20 + 3) / speed * 60)):
				if p.surface_state != int(target.surface):
					p.switch_surface()
				p.advance(1.0/60,steer(p,target.angle))
			check(not p.dead,"Initial pattern unreachable")
		g.forced_patterns = PackedInt32Array()
		p.reset_run()
		g.reset_course()
		var original := g.history.duplicate()
		var ids: Array = []
		for s in g.pool:
			ids.append(s.get_instance_id())
		# Long run with collisions disabled checks pooling, rebasing and coverage.
		scene.get_node("Collision").enabled = false
		for step in range(2000):
			p.advance(0.1,0)
			g.retire_behind()
			check(g.next_z <= p.forward_position - 200,"Missing track ahead")
		check(g.pool.size() <= 7,"Unbounded ordinary-run pool")
		check(g.history.size() <= 64,"Unbounded debug log")
		scene.get_node("RunStatus").restart()
		check(g.history == original,"Restart did not reproduce seed")
		for id in ids:
			check(is_instance_id_valid(id),"Pool objects were destroyed")
		g.ensure_ahead(-g.segment_length * 5)
		var sequence := g.history.duplicate()
		g.seed_value += 1
		g.reset_course()
		g.ensure_ahead(-g.segment_length * 5)
		check(g.history != sequence,"Different seed has identical generated sequence")
		# Follow the same route policy across an actual seeded stream, including
		# transitions, recycling, and several floating-origin shifts.
		scene.get_node("Collision").enabled = true
		p.reset_run()
		g.reset_course()
		for step in range(10000):
			var chosen = null
			var nearest_z := -INF
			for segment in g.active:
				var row: float = segment.start_z - g.segment_length * 0.5
				if segment.pattern_index >= 0 and row <= p.forward_position + 2.0 + speed * g.reaction_time and row > nearest_z:
					nearest_z = row
					chosen = g.patterns[segment.pattern_index]
			var input := 0.0
			if chosen != null:
				if p.surface_state != int(chosen.surface):
					p.switch_surface()
				input = steer(p,chosen.angle)
			p.advance(1.0/60.0,input)
			g.retire_behind()
			if p.dead:
				break
		check(not p.dead,"Seeded connected run failed at speed %s" % speed)
		scene.free()
	print("Generation checks: ",pair_count," ordered pair/speed combinations; failures=",failures)
	quit(0 if failures == 0 else 1)
