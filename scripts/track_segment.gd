extends Node3D
## A recycled section; mesh resource is shared, obstacle nodes belong to the pool.
var obstacles: Array[RunnerObstacle] = []
var sequence_index := -1
var pattern_index := -1
var start_z := 0.0
var wall: MeshInstance3D
func _init() -> void:
	wall = MeshInstance3D.new()
	add_child(wall)
