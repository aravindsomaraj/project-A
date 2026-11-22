class_name RunnerTouchInput
extends Node
## Touch recognition only. Movement, camera and switching policy remain elsewhere.
signal drag_rotation(radians: float)
signal switch_requested
signal input_cancelled

@export_range(30.0, 720.0, 5.0) var sensitivity: float = 360.0 ## Degrees per screen width.
@export_range(0.002, 0.08, 0.001) var drag_threshold: float = 0.015 ## Fraction of shorter viewport side.
@export_range(0.1, 0.5, 0.01) var tap_max_duration: float = 0.25
@export_range(0.15, 0.6, 0.01) var double_tap_interval: float = 0.30
@export_range(0.02, 0.2, 0.01) var double_tap_distance: float = 0.08

var _fingers: Dictionary = {}
var _steering_finger := -1
var _last_tap_ms := -1
var _last_tap_position := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# Never process mouse events as a second path. Godot's optional mouse-to-touch
	# emulation generates the same ScreenTouch/ScreenDrag events as a phone.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		handle_touch(event, get_viewport().get_visible_rect().size, Time.get_ticks_msec())
		get_viewport().set_input_as_handled()

func handle_touch(event: InputEvent, viewport_size: Vector2, now_ms: int) -> void:
	var short_side := maxf(1.0, minf(viewport_size.x, viewport_size.y))
	if event is InputEventScreenTouch:
		var point: Vector2 = event.position / short_side
		if event.canceled:
			reset_input()
			return
		if event.pressed:
			var allowed := true
			for finger in _fingers.values():
				if not finger.dragged:
					finger.allowed = false
					allowed = false
			_fingers[event.index] = {"start": point, "last": point, "time": now_ms, "dragged": false, "allowed": allowed}
			if _steering_finger == -1:
				_steering_finger = event.index
		else:
			if not _fingers.has(event.index):
				return
			var finger: Dictionary = _fingers[event.index]
			if finger.last.distance_to(point) > 0.0:
				_move_finger(event.index, point, short_side / maxf(viewport_size.x, 1.0))
			_fingers.erase(event.index)
			if _steering_finger == event.index:
				_steering_finger = -1
			if not finger.dragged and finger.allowed and now_ms - int(finger.time) <= tap_max_duration * 1000.0:
				if _last_tap_ms >= 0 and now_ms - _last_tap_ms <= double_tap_interval * 1000.0 and point.distance_to(_last_tap_position) <= double_tap_distance:
					_last_tap_ms = -1 # Consume the pair, even if the player rejects it on cooldown.
					switch_requested.emit()
				else:
					_last_tap_ms = now_ms
					_last_tap_position = point
			elif not finger.dragged:
				_last_tap_ms = -1
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		_move_finger(event.index, event.position / short_side, short_side / maxf(viewport_size.x, 1.0))

func _move_finger(index: int, point: Vector2, short_to_width: float) -> void:
	var finger: Dictionary = _fingers[index]
	var previous: Vector2 = finger.last
	if not finger.dragged and point.distance_to(finger.start) > drag_threshold:
		finger.dragged = true
		_last_tap_ms = -1
		previous = finger.start # Include the initial deadzone once this is a drag.
	if finger.dragged and index == _steering_finger:
		drag_rotation.emit((point.x - previous.x) * short_to_width * deg_to_rad(sensitivity))
	finger.last = point

func reset_input() -> void:
	_fingers.clear()
	_steering_finger = -1
	_last_tap_ms = -1
	input_cancelled.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_input()
