extends SceneTree
var failures := 0
var switches := 0
var distance := 0.0
var size := Vector2(1280, 720)
var touch: RunnerTouchInput
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func press(id: int, point: Vector2, down: bool, time: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = point * size
	event.pressed = down
	touch.handle_touch(event, size, time)
func drag(id: int, point: Vector2, time: int) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = point * size
	touch.handle_touch(event, size, time)
func tap(time: int, id: int = 0) -> void:
	press(id, Vector2(0.5, 0.5), true, time)
	press(id, Vector2(0.5, 0.5), false, time + 40)
func run() -> void:
	var main = load("res://scenes/legacy_main.tscn").instantiate()
	root.add_child(main)
	main.get_node("Collision").enabled = false # Free-running regression fixture.
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var p = main.get_node("Player")
	touch = p.get_node("TouchInput")
	touch.switch_requested.connect(func(): switches += 1)
	touch.drag_rotation.connect(func(amount): distance += amount)
	for resolution in [Vector2(1280,720), Vector2(2560,1440), Vector2(2400,1080)]:
		for fps in [30,60,144]:
			size = resolution
			touch.reset_input()
			p.reset_run()
			distance = 0
			press(0, Vector2(0.1,0.5), true, 0)
			for step in range(1, fps + 1):
				drag(0, Vector2(0.1 + 0.5 * step / fps, 0.5), step * 1000 / fps)
				p.advance(1.0 / fps, 0)
			press(0, Vector2(0.6,0.5), false, 1010)
			for step in range(fps):
				p.advance(1.0 / fps, 0)
			check(absf(distance - PI) < 0.0001, "Drag not proportional across resolutions/FPS")
			check(absf(absf(p.angular_position) - PI) < 0.001, "Smoothed rotation lost distance")
			check(switches == 0, "Drag triggered switch")
	# Completed pair produces exactly one request, third tap alone does not.
	touch.reset_input()
	p.reset_run()
	tap(2000)
	check(switches == 0, "Single tap switched")
	tap(2150)
	check(switches == 1 and p.transition.active, "Double tap did not use existing switch")
	tap(2250)
	check(switches == 1, "Triple tap retriggered")
	var state = p.surface_state
	tap(2350)
	check(switches == 2 and p.surface_state == state, "Transition lock not respected")
	p.advance(0.25,0)
	tap(2500)
	tap(2600)
	check(p.surface_state == state, "Cooldown not respected")
	p.advance(0.2,0)
	# Drag goes out and returns: still a drag, not a tap.
	touch.reset_input()
	var count := switches
	press(0, Vector2(0.5,0.5), true, 3000)
	drag(0, Vector2(0.7,0.5), 3050)
	drag(0, Vector2(0.5,0.5), 3100)
	press(0, Vector2(0.5,0.5), false, 3120)
	tap(3200)
	check(switches == count, "Return drag treated as first tap")
	# Second finger can double tap while first keeps steering.
	touch.reset_input()
	press(0, Vector2(0.2,0.5), true, 4000)
	drag(0, Vector2(0.3,0.5), 4050)
	tap(4100,1)
	drag(0, Vector2(0.4,0.5), 4180)
	tap(4250,1)
	check(switches == count + 1, "Second finger could not switch while steering")
	var right: Vector3 = p.basis.x
	var position_before: Vector3 = p.position
	drag(0, Vector2(0.5,0.5), 4300)
	p.advance(1.0 / 60.0, 0)
	check((p.position - position_before).dot(right) > 0, "Touch inverted after surface change")
	touch.reset_input()
	check(is_zero_approx(p._pending_touch_rotation), "Focus/cancel left pending movement")
	# Mouse event is never recognized by the touch recognizer.
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	touch.handle_touch(mouse, size, 5000)
	check(switches == count + 1, "Mouse duplicated touch")
	# Long press, timeout and spatially separate taps.
	touch.reset_input()
	tap(6000)
	tap(7000)
	check(switches == count + 1, "Expired tap paired")
	touch.reset_input()
	press(0, Vector2(0.5,0.5), true, 8000)
	press(0, Vector2(0.5,0.5), false, 8600)
	tap(8700)
	check(switches == count + 1, "Long press paired")
	touch.reset_input()
	tap(9000)
	press(0, Vector2(0.9,0.5), true, 9100)
	press(0, Vector2(0.9,0.5), false, 9140)
	check(switches == count + 1, "Distant taps paired")
	# Route real Godot touch events through the scene's _unhandled_input handler.
	touch.reset_input()
	p.reset_run()
	touch.process_mode = Node.PROCESS_MODE_ALWAYS
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = Vector2(100,300)
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var motion := InputEventScreenDrag.new()
	motion.index = 0
	motion.position = Vector2(400,300)
	motion.relative = Vector2(300,0)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	check(p._pending_touch_rotation > 0, "Actual screen event did not reach controller")
	var cancel := InputEventScreenTouch.new()
	cancel.index = 0
	cancel.canceled = true
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	check(is_zero_approx(p._pending_touch_rotation), "Touch cancellation not handled")
	touch.process_mode = Node.PROCESS_MODE_INHERIT
	print("Touch validation failures: ", failures)
	quit(0 if failures == 0 else 1)
