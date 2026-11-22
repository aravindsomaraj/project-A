class_name CylinderRunnerCamera
extends Camera3D
## Interpolate a surface frame, never Euler angles or a global-Y look-at.

@export var target: CylinderRunnerPlayer
@export_range(1.0, 15.0, 0.1) var follow_distance: float = 7.5
@export_range(0.1, 6.0, 0.1) var inward_height: float = 2.8 ## Height along local up (outward outside).
@export_range(0.0, 30.0, 0.5) var look_ahead: float = 11.0
@export_range(0.0, 3.0, 0.1) var focus_height: float = 0.5
@export_range(1.0, 50.0, 0.5) var position_response: float = 20.0
@export_range(1.0, 50.0, 0.5) var rotation_response: float = 20.0

var _surface_rotation := Quaternion.IDENTITY
var _axis_position := Vector3.ZERO
var _phase = preload("res://scripts/surface_phase_view.gd").new()
var _source_view: SubViewport
var _source_camera: Camera3D
var _source_body: MeshInstance3D
var _source_frame := Transform3D.IDENTITY
var _source_angle := 0.0
var _source_z := 0.0
var _preserve_follow := false


func _begin_transition() -> void:
	_source_frame = global_transform
	_source_angle = target.angular_position
	_source_z = target.forward_position
	_source_view.size = get_viewport().get_visible_rect().size
	_source_camera.global_transform = global_transform
	_source_camera.fov = fov
	_source_camera.near = near
	_source_camera.far = far
	_source_body.global_transform = target.global_transform
	_source_body.visible = true
	_source_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_phase.capture(_source_view.get_texture())
	_preserve_follow = true


func _ready() -> void:
	# Run after the player's render-frame movement, avoiding a one-frame delay.
	process_priority = 10
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	layer.add_child(_phase)
	if target != null:
		# Separate visual layers let each live view show the capsule on its own side.
		cull_mask = 3
		target.get_node("Body").layers = 2
		_source_view = SubViewport.new()
		_source_view.size = get_viewport().get_visible_rect().size
		_source_view.world_3d = get_world_3d()
		_source_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(_source_view)
		_source_camera = Camera3D.new()
		_source_camera.cull_mask = 5
		_source_view.add_child(_source_camera)
		_source_body = MeshInstance3D.new()
		_source_body.mesh = target.get_node("Body").mesh
		_source_body.material_override = target.get_node("Body").material_override
		_source_body.layers = 4
		_source_body.visible = false
		_source_view.add_child(_source_body)
		target.longitudinal_wrapped.connect(_on_target_wrapped)
		target.surface_changed.connect(snap_to_target)
		target.transition_started.connect(_begin_transition)
		snap_to_target()


func snap_to_target() -> void:
	if target == null:
		return
	_surface_rotation = target.global_basis.get_rotation_quaternion()
	var previous_z := _axis_position.z
	_axis_position = _target_axis_position()
	if _preserve_follow:
		_axis_position.z = previous_z
		_preserve_follow = false
	_apply_camera_transform()


func _process(delta: float) -> void:
	if target == null:
		return
	_phase.update_phase(target.transition.active, target.transition.weight())
	if target.transition.active:
		var angle_delta := target.angular_position - _source_angle
		var rotation := Basis(Vector3.BACK, angle_delta)
		_source_camera.global_basis = rotation * _source_frame.basis
		var source_xy := rotation * Vector3(_source_frame.origin.x, _source_frame.origin.y, 0)
		_source_camera.global_position = source_xy + Vector3(0, 0, _source_frame.origin.z + target.forward_position - _source_z)
		var outward := Vector3(sin(target.angular_position), -cos(target.angular_position), 0)
		var source_sign: float = target.transition.source_sign
		var up := outward * source_sign
		_source_body.global_position = outward * (target.cylinder_radius + source_sign * target.capsule_height * 0.5) + Vector3(0, 0, target.forward_position)
		_source_body.global_basis = Basis(up.cross(Vector3.BACK), up, Vector3.BACK)
	else:
		_source_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_source_body.visible = false
	_surface_rotation = _surface_rotation.slerp(
		target.global_basis.get_rotation_quaternion(), 1.0 - exp(-rotation_response * delta)
	).normalized()
	_axis_position = _axis_position.lerp(_target_axis_position(), 1.0 - exp(-position_response * delta))
	_apply_camera_transform()


func _target_axis_position() -> Vector3:
	return target.global_position - target.global_basis.y * target.get_surface_sign() * target.get_running_radius()


func _apply_camera_transform() -> void:
	var frame := Basis(_surface_rotation)
	# Reconstruct an orbit rather than lerping world positions across the circle.
	var surface_sign := target.get_surface_sign()
	var orbit_radius := maxf(0.0, target.get_running_radius() + surface_sign * inward_height)
	global_position = _axis_position + frame.y * surface_sign * orbit_radius + frame.z * follow_distance
	var focus := target.global_position - target.global_basis.z * look_ahead
	focus += target.global_basis.y * focus_height
	global_basis = Basis.looking_at(focus - global_position, frame.y)


func _on_target_wrapped(offset: Vector3) -> void:
	# Teleport only the longitudinal follow state; retain all angular smoothing.
	_axis_position += offset
	global_position += offset
