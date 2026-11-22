class_name CylinderRunnerPlayer
extends Node3D
## Kinematic surface attachment: local +Y is the head, local -Z is forward.
## Surface position/orientation are owned here for both running states.

signal longitudinal_wrapped(offset: Vector3)
signal surface_changed
signal transition_started
signal died

var dead := false
var collision_check: Callable

@export_range(0.1, 1.0, 0.01) var transition_duration: float = 0.25
@export_range(0.0, 1.0, 0.01) var switch_cooldown: float = 0.15
var transition = preload("res://scripts/surface_transition.gd").new()

enum SurfaceState { INSIDE, OUTSIDE }

var surface_state: SurfaceState = SurfaceState.INSIDE

@export_range(0.0, 80.0, 0.5) var movement_speed: float = 18.0
@export_range(0.0, 360.0, 1.0) var angular_speed: float = 130.0 ## Degrees/second.
@export_range(0.1, 40.0, 0.1) var steering_response: float = 12.0
@export_range(2.0, 100.0, 0.1) var cylinder_radius: float = 8.0
@export_range(0.5, 4.0, 0.1) var capsule_height: float = 2.0
@export_range(0.1, 1.0, 0.05) var capsule_radius: float = 0.45
@export var loop_start_z: float = -20.0
@export_range(10.0, 1000.0, 1.0) var loop_length: float = 100.0

var angular_position: float = 0.0
var angular_velocity: float = 0.0
var forward_position: float = -20.0
var _pending_touch_rotation: float = 0.0


func queue_touch_rotation(radians: float) -> void:
	if not dead:
		_pending_touch_rotation += radians


func clear_touch_rotation() -> void:
	_pending_touch_rotation = 0.0


func _ready() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = capsule_radius
	capsule.height = maxf(capsule_height, capsule_radius * 2.0)
	capsule_height = capsule.height
	$Body.mesh = capsule
	reset_run()


func reset_run() -> void:
	dead = false
	clear_touch_rotation()
	transition.active = false
	transition.cooldown_left = 0.0
	surface_state = SurfaceState.INSIDE
	angular_position = 0.0
	angular_velocity = 0.0
	forward_position = loop_start_z
	_update_surface_transform()
	surface_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Echo is excluded by default: holding Q must not repeatedly toggle.
	if event.is_action_pressed("switch_surface"):
		switch_surface()
		get_viewport().set_input_as_handled()


func switch_surface() -> void:
	if dead:
		return
	if transition.begin(get_surface_sign(), transition_duration):
		transition_started.emit()
		# Phase transfer: both visible endpoint views are safe, with no wall traversal.
		surface_state = SurfaceState.OUTSIDE if surface_state == SurfaceState.INSIDE else SurfaceState.INSIDE
		_update_surface_transform()
		surface_changed.emit()


func _finish_switch() -> void:
	_update_surface_transform()


func get_surface_sign() -> float:
	# Radial direction of local up: inward inside, outward outside.
	return -1.0 if surface_state == SurfaceState.INSIDE else 1.0


func get_running_radius() -> float:
	# CapsuleMesh.height includes both rounded ends; its origin is its center.
	return maxf(0.1, cylinder_radius + get_surface_sign() * capsule_height * 0.5)


func get_surface_up() -> Vector3:
	return basis.y


func _process(delta: float) -> void:
	advance(delta, Input.get_axis("steer_left", "steer_right"))


func advance(delta: float, steering: float) -> void:
	if dead:
		return
	# Exact exponential velocity integration keeps steering consistent across FPS.
	var target_velocity := clampf(steering, -1.0, 1.0) * deg_to_rad(angular_speed)
	var decay := exp(-steering_response * delta)
	var angle_step := target_velocity * delta
	angle_step += (angular_velocity - target_velocity) * (1.0 - decay) / steering_response
	angular_velocity = target_velocity + (angular_velocity - target_velocity) * decay
	# Consume drag distance smoothly without converting it into a held key or
	# clamping its total angle. Equal screen-width travel yields equal rotation.
	var touch_step := _pending_touch_rotation * (1.0 - decay)
	_pending_touch_rotation -= touch_step
	angle_step += touch_step
	# Velocity is measured in character-relative steering space. Keep D/right
	# moving toward local +X even though outside up reverses the angular tangent.
	var next_angle := angular_position - get_surface_sign() * angle_step
	var next_z := forward_position - movement_speed * delta
	var fraction := 1.0
	var has_collision := false
	if collision_check.is_valid():
		var hit: float = collision_check.call(self, angular_position, next_angle, forward_position, next_z, delta)
		has_collision = hit <= 1.0
		fraction = minf(hit, 1.0)
	if transition.advance(delta * fraction, switch_cooldown):
		_finish_switch()
	angular_position = wrapf(lerpf(angular_position, next_angle, fraction), -PI, PI)
	forward_position = lerpf(forward_position, next_z, fraction)
	var offset := Vector3.ZERO
	if forward_position < loop_start_z - loop_length:
		var previous_z := forward_position
		forward_position = loop_start_z - fposmod(loop_start_z - forward_position, loop_length)
		offset.z = forward_position - previous_z
	_update_surface_transform()
	if not offset.is_zero_approx():
		longitudinal_wrapped.emit(offset)
	if has_collision:
		end_run()


func end_run() -> void:
	if dead:
		return
	dead = true
	angular_velocity = 0.0
	clear_touch_rotation()
	if transition.active:
		surface_state = SurfaceState.INSIDE if transition.source_sign < 0 else SurfaceState.OUTSIDE
	transition.active = false
	_update_surface_transform()
	surface_changed.emit()
	died.emit()


func _update_surface_transform() -> void:
	# Zero angle is the bottom of the cylinder in either state.
	var outward := Vector3(sin(angular_position), -cos(angular_position), 0.0)
	var surface_up := outward * get_surface_sign()
	position = outward * get_running_radius() + Vector3(0.0, 0.0, forward_position)
	basis = Basis(surface_up.cross(Vector3.BACK), surface_up, Vector3.BACK)
