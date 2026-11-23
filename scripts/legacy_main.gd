extends Node3D


func _ready() -> void:
	var tunnel: RunnerTunnel = $Tunnel
	var player: CylinderRunnerPlayer = $Player
	var camera: CylinderRunnerCamera = $RunnerCamera
	player.cylinder_radius = tunnel.cylinder_radius
	for obstacle: RunnerObstacle in $Obstacles.get_children():
		if not is_equal_approx(obstacle.cylinder_radius, tunnel.cylinder_radius):
			obstacle.cylinder_radius = tunnel.cylinder_radius
			obstacle.rebuild()
	# Reuse the middle of the fixed mesh. The endpoints stay beyond the camera.
	# A whole number of marking periods makes the loop visually identical.
	player.loop_start_z = -tunnel.tunnel_length * 0.1
	player.loop_length = maxf(tunnel.marking_spacing,
		floorf(tunnel.tunnel_length * 0.5 / tunnel.marking_spacing) * tunnel.marking_spacing)
	player.reset_run()
	camera.snap_to_target()
	player.collision_check = $Collision.sweep
