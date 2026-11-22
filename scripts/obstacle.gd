class_name RunnerObstacle
extends MeshInstance3D
## Arc prism attached to one surface; the full inner type forces a 360-degree arc.
enum Kind { PARTIAL_INNER, FULL_INNER, PARTIAL_OUTER }
@export var kind: Kind = Kind.PARTIAL_INNER
@export_range(0, 360, 1) var angle_degrees: float = 0.0
@export_range(1, 360, 1) var width_degrees: float = 90.0
@export var z_position: float = -40.0
@export var cylinder_radius: float = 8.0
@export_range(0.1, 5, 0.1) var height: float = 2.4
@export_range(0.1, 5, 0.1) var depth: float = 1.2

func surface() -> int:
	return 1 if kind == Kind.PARTIAL_OUTER else 0
func angular_width() -> float:
	return TAU if kind == Kind.FULL_INNER else deg_to_rad(width_degrees)
func _ready() -> void:
	rebuild()
func rebuild() -> void:
	position.z = z_position
	var color := Color(1.0, 0.12, 0.20) if surface() == 0 else Color(1.0, 0.72, 0.10)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.7
	material.roughness = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	var build := SurfaceTool.new()
	build.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(2, ceili(angular_width() / deg_to_rad(5.0)))
	var low := cylinder_radius - height if surface() == 0 else cylinder_radius + 0.015
	var high := cylinder_radius - 0.015 if surface() == 0 else cylinder_radius + height
	for i in range(count):
		var a := deg_to_rad(angle_degrees) - angular_width() * 0.5 + angular_width() * i / count
		var b := a + angular_width() / count
		var ra := Vector3(sin(a), -cos(a), 0)
		var rb := Vector3(sin(b), -cos(b), 0)
		var v: Array[Vector3] = []
		for z in [-depth * 0.5, depth * 0.5]:
			v.append(ra * low + Vector3(0,0,z))
			v.append(rb * low + Vector3(0,0,z))
			v.append(rb * high + Vector3(0,0,z))
			v.append(ra * high + Vector3(0,0,z))
		for face in [[0,1,2,3], [7,6,5,4], [0,4,5,1], [3,2,6,7]]:
			_quad(build, v, face)
		if i == 0:
			_quad(build, v, [0,3,7,4])
		if i == count - 1:
			_quad(build, v, [1,5,6,2])
	build.generate_normals()
	mesh = build.commit()
func _quad(build: SurfaceTool, vertices: Array[Vector3], face: Array) -> void:
	for i in [0,1,2,0,2,3]:
		build.add_vertex(vertices[face[i]])
