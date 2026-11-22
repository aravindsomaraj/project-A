class_name RunnerTunnel
extends MeshInstance3D
## One open-ended cylinder along -Z with distinct inward/outward faces.

@export_range(2.0, 100.0, 0.1) var cylinder_radius: float = 8.0
@export_range(40.0, 1000.0, 10.0) var tunnel_length: float = 200.0
@export_range(32, 256, 8) var radial_segments: int = 128
@export_range(1.0, 20.0, 1.0) var marking_spacing: float = 10.0


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var z := 0.0
	while z < tunnel_length:
		var band_end := minf(z + 0.14, tunnel_length)
		var panel_end := minf(z + marking_spacing, tunnel_length)
		for segment in range(radial_segments):
			var angle_a := TAU * float(segment) / radial_segments
			var angle_b := TAU * float(segment + 1) / radial_segments
			var sector := int(float(segment) * 16.0 / radial_segments)
			var panel_color := Color(0.14, 0.20, 0.27) if sector % 2 == 0 else Color(0.19, 0.26, 0.33)
			var stripe := segment % maxi(1, radial_segments >> 3) == 0
			if stripe:
				panel_color = Color(0.20, 0.62, 0.70)
			# A gold reference stripe identifies the starting floor after a full turn.
			if segment == (radial_segments * 3) >> 2:
				panel_color = Color(0.95, 0.56, 0.16)
			_append_quad(vertices, normals, colors, indices, angle_a, angle_b, z, band_end, Color(0.42, 0.64, 0.72))
			_append_quad(vertices, normals, colors, indices, angle_a, angle_b, band_end, panel_end, panel_color)
		z = panel_end
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var generated_mesh := ArrayMesh.new()
	generated_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Same radius, opposite faces. Back-face culling keeps the two surfaces from
	# fighting for depth and gives each side correct lighting normals.
	var exterior_normals := PackedVector3Array()
	var exterior_colors := PackedColorArray()
	var exterior_indices := indices.duplicate()
	for normal in normals:
		exterior_normals.append(-normal)
	for color in colors:
		# Remap cool blue panels/markings to a warm copper exterior.
		exterior_colors.append(Color(color.b, color.g * 0.65, color.r * 0.55, color.a))
	for index in range(0, exterior_indices.size(), 3):
		var second := exterior_indices[index + 1]
		exterior_indices[index + 1] = exterior_indices[index + 2]
		exterior_indices[index + 2] = second
	arrays[Mesh.ARRAY_NORMAL] = exterior_normals
	arrays[Mesh.ARRAY_COLOR] = exterior_colors
	arrays[Mesh.ARRAY_INDEX] = exterior_indices
	generated_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = generated_mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material_override = material


func _append_quad(vertices: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array, angle_a: float,
		angle_b: float, start_z: float, end_z: float, color: Color) -> void:
	var a := Vector3(cos(angle_a), sin(angle_a), 0.0)
	var b := Vector3(cos(angle_b), sin(angle_b), 0.0)
	var base := vertices.size()
	vertices.append(a * cylinder_radius + Vector3(0.0, 0.0, -start_z))
	vertices.append(b * cylinder_radius + Vector3(0.0, 0.0, -start_z))
	vertices.append(b * cylinder_radius + Vector3(0.0, 0.0, -end_z))
	vertices.append(a * cylinder_radius + Vector3(0.0, 0.0, -end_z))
	normals.append_array(PackedVector3Array([-a, -b, -b, -a]))
	colors.append_array(PackedColorArray([color, color, color, color]))
	# Clockwise when viewed from inside (Godot's front-face convention).
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
