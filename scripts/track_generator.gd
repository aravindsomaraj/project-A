class_name RunnerGenerator
extends Node3D
@export var seed_value: int = 1337
@export var pattern_library: Resource = preload("res://patterns/standard.tres")
@export_range(80, 400, 10) var minimum_segment_length: float = 80.0
@export_range(0.5, 3, 0.1) var reaction_time: float = 1.0
@export var debug_log := false
@export var forced_patterns: PackedInt32Array = []
var patterns: Array = []
var segment_length := 80.0
var pool: Array[Node3D] = []
var active: Array[Node3D] = []
var next_z := 0.0
var next_index := 0
var history: Array[String] = [] # Bounded debug history only.
var rng := RandomNumberGenerator.new()
var player: CylinderRunnerPlayer
var obstacle_root: Node3D
var shared_mesh: Mesh
var shared_material: Material
var templates: Array = []
const SEGMENT = preload("res://scenes/track_segment.tscn")
const OBSTACLE = preload("res://scenes/obstacle.tscn")

func configure(p: CylinderRunnerPlayer, root: Node3D) -> void:
	player = p
	obstacle_root = root
	patterns = pattern_library.patterns.duplicate(true)
	for i in range(patterns.size()-1,-1,-1):
		if not patterns[i] is Dictionary or not pattern_valid(patterns[i]):
			push_warning("Ignoring invalid pattern at library index %d" % i)
			patterns.remove_at(i)
	segment_length = maxf(minimum_segment_length, ceil(required_spacing() / 10.0) * 10.0)
	var wall := RunnerTunnel.new()
	wall.cylinder_radius = player.cylinder_radius
	wall.tunnel_length = segment_length
	wall.rebuild()
	shared_mesh = wall.mesh
	shared_material = wall.material_override
	wall.free()
	for pattern in patterns:
		var cache: Array = []
		for spec in pattern.obstacles:
			var o: RunnerObstacle = OBSTACLE.instantiate()
			o.kind = int(spec[0])
			o.angle_degrees = spec[1]
			o.width_degrees = spec[2]
			o.cylinder_radius = player.cylinder_radius
			o.rebuild()
			cache.append([o.mesh, o.material_override])
			o.free()
		templates.append(cache)
	player.longitudinal_wrapped.connect(_rebase)
	reset_course()

func required_spacing() -> float:
	# Worst half-turn, steering acceleration/braking, one switch and outstanding
	# cooldown, plus human reaction allowance and full collision slab clearance.
	return player.movement_speed * (PI / maxf(deg_to_rad(player.angular_speed), 0.01) + 8.0 / maxf(player.steering_response, 0.1) + player.transition_duration + player.switch_cooldown + reaction_time) + 2.0 * (0.6 + player.capsule_radius)

func pattern_valid(pattern: Dictionary) -> bool:
	if player.angular_speed <= 0.0 or player.steering_response <= 0.0:
		return false
	if not pattern.has_all(["id","surface","angle","obstacles"]):
		return false
	if pattern.obstacles.size() > 2 or int(pattern.surface) not in [0,1]:
		return false
	var radius := player.cylinder_radius - player.capsule_height + player.capsule_radius
	var padding := rad_to_deg(asin(clampf(player.capsule_radius / maxf(radius,player.capsule_radius),0,1))) + 10.0
	for spec in pattern.obstacles:
		if not spec is Array or spec.size() != 3 or int(spec[0]) not in [0,1,2] or spec[2] <= 0 or spec[2] > 360:
			return false
		if (1 if int(spec[0]) == 2 else 0) == int(pattern.surface):
			if int(spec[0]) == 1 or absf(rad_to_deg(angle_difference(deg_to_rad(pattern.angle),deg_to_rad(spec[1])))) <= float(spec[2]) * 0.5 + padding:
				return false
	return true

func reset_course() -> void:
	for segment in active:
		segment.hide()
		for o in segment.obstacles:
			o.hide()
	active.clear()
	rng.seed = seed_value
	next_z = 0
	next_index = 0
	history.clear()
	ensure_ahead(player.forward_position - 200.0)

func ensure_ahead(limit: float) -> void:
	while next_z > limit:
		var segment: Node3D = null
		for candidate in pool:
			if candidate not in active:
				segment = candidate
				break
		if segment == null:
			segment = SEGMENT.instantiate()
			add_child(segment)
			segment.wall.mesh = shared_mesh
			segment.wall.material_override = shared_material
			for i in range(2):
				var o: RunnerObstacle = OBSTACLE.instantiate()
				obstacle_root.add_child(o)
				segment.obstacles.append(o)
			pool.append(segment)
		var selected := -1
		if next_index > 0 and not patterns.is_empty():
			selected = rng.randi_range(0, patterns.size()-1)
			if not forced_patterns.is_empty():
				selected = posmod(forced_patterns[(next_index-1) % forced_patterns.size()], patterns.size())
			if not pattern_valid(patterns[selected]):
				push_warning("Rejected unsafe pattern; leaving clear segment: %s" % patterns[selected])
				selected = -1
		segment.sequence_index = next_index
		segment.pattern_index = selected
		segment.start_z = next_z
		segment.position.z = next_z
		segment.show()
		for i in range(2):
			var o: RunnerObstacle = segment.obstacles[i]
			o.hide()
			if selected >= 0 and i < patterns[selected].obstacles.size():
				var spec: Array = patterns[selected].obstacles[i]
				o.kind = int(spec[0])
				o.angle_degrees = spec[1]
				o.width_degrees = spec[2]
				o.z_position = next_z - segment_length * 0.5
				o.position.z = o.z_position
				o.cylinder_radius = player.cylinder_radius
				o.mesh = templates[selected][i][0]
				o.material_override = templates[selected][i][1]
				o.show()
		active.append(segment)
		var description := "%d:%s" % [next_index, str(patterns[selected].id) if selected >= 0 else "clear"]
		history.append(description)
		if history.size() > 64:
			history.pop_front()
		if debug_log:
			print("seed=",seed_value," segment=",description," z=",next_z)
		next_z -= segment_length
		next_index += 1

func retire_behind() -> void:
	for i in range(active.size()-1,-1,-1):
		var segment = active[i]
		if segment.start_z - segment_length > player.forward_position + 30.0:
			segment.hide()
			for o in segment.obstacles:
				o.hide()
			active.remove_at(i)

func _rebase(offset: Vector3) -> void:
	next_z += offset.z
	for segment in active:
		segment.start_z += offset.z
		segment.position.z += offset.z
		for o in segment.obstacles:
			o.z_position += offset.z
			o.position.z += offset.z
