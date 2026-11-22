class_name RunnerCollision
extends Node
## Swept capsule envelope in unwrapped angle/Z space. Independent of placement.
@export var obstacle_root: Node
var enabled := true

func sweep(player: CylinderRunnerPlayer, start_angle: float, end_angle: float,
		start_z: float, end_z: float, delta: float) -> float:
	if not enabled or obstacle_root == null:
		return INF
	var earliest := INF
	var boundary := 0.0
	if player.transition.active:
		boundary = (player.transition.duration - player.transition.elapsed) / maxf(delta, 0.000001)
	for obstacle: RunnerObstacle in obstacle_root.get_children():
		var begin := 0.0
		var end := 1.0
		var exclusive_end := false
		if player.transition.active:
			var source := 0 if player.transition.source_sign < 0 else 1
			if obstacle.surface() == source:
				end = minf(boundary, 1.0)
				exclusive_end = boundary <= 1.0
			else:
				begin = boundary
		elif obstacle.surface() != player.surface_state:
			continue
		if begin > end or end < 0:
			continue
		# Radial capsule segment lies on this surface. Pad angular bounds by its
		# full silhouette; Z is padded by capsule radius. Conservative at corners.
		var min_radius := player.cylinder_radius + player.capsule_radius if obstacle.surface() == 1 else player.cylinder_radius - player.capsule_height + player.capsule_radius
		var pad := asin(clampf(player.capsule_radius / maxf(min_radius, player.capsule_radius), 0, 1))
		var half_width := obstacle.angular_width() * 0.5 + pad
		var z_pad := obstacle.depth * 0.5 + player.capsule_radius
		# The existing fixed track loops; test every crossed copy, including frames
		# spanning an entire loop. No obstacle generation occurs here.
		var first := floori((minf(start_z, end_z) - obstacle.z_position - z_pad) / player.loop_length)
		var last := ceili((maxf(start_z, end_z) - obstacle.z_position + z_pad) / player.loop_length)
		for lap in range(first, last + 1):
			var center_z := obstacle.z_position + lap * player.loop_length
			var interval := _slab(start_z, end_z, center_z - z_pad, center_z + z_pad, Vector2(begin, end))
			if interval.x > interval.y:
				continue
			if obstacle.kind == RunnerObstacle.Kind.FULL_INNER:
				if not exclusive_end or interval.x < end:
					earliest = minf(earliest, interval.x)
				continue
			var center := deg_to_rad(obstacle.angle_degrees)
			var low_turn := floori((minf(start_angle,end_angle) - center - half_width) / TAU)
			var high_turn := ceili((maxf(start_angle,end_angle) - center + half_width) / TAU)
			for turn in range(low_turn, high_turn + 1):
				var angle := center + turn * TAU
				var hit := _slab(start_angle,end_angle,angle-half_width,angle+half_width,interval)
				if hit.x <= hit.y and (not exclusive_end or hit.x < end):
					earliest = minf(earliest, hit.x)
	return earliest

func _slab(start: float, end: float, low: float, high: float, interval: Vector2) -> Vector2:
	if is_equal_approx(start, end):
		return interval if start >= low and start <= high else Vector2(1, -1)
	var a := (low - start) / (end - start)
	var b := (high - start) / (end - start)
	return Vector2(maxf(interval.x, minf(a,b)), minf(interval.y, maxf(a,b)))
