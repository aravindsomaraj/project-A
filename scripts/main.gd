extends Node3D
func _ready() -> void:
	process_priority = 20
	$Player.loop_length = 1000.0 # Floating origin only; generated content is shifted with it.
	$Player.reset_run()
	$RunnerCamera.snap_to_target()
	$Generator.configure($Player, $Obstacles)
	$Player.collision_check = _sweep
func _sweep(player: CylinderRunnerPlayer, a: float, b: float, z: float, next_z: float, delta: float) -> float:
	# Populate the entire proposed movement before collision, even on a long frame.
	$Generator.ensure_ahead(next_z - 200.0)
	return $Collision.sweep(player,a,b,z,next_z,delta)
func _process(_delta: float) -> void:
	$Generator.retire_behind()
func restart_course() -> void:
	$Generator.reset_course()
