extends CanvasLayer
## Minimal run status. Handles real touch explicitly with mouse emulation disabled.
var panel: CenterContainer
var restart_button: Button
var _finger := -1
@onready var player: CylinderRunnerPlayer = get_parent().get_node("Player")

func _ready() -> void:
	panel = CenterContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	var label := Label.new()
	label.text = "GAME OVER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	box.add_child(label)
	restart_button = Button.new()
	restart_button.text = "Restart  (R)"
	restart_button.custom_minimum_size = Vector2(280, 80)
	restart_button.add_theme_font_size_override("font_size", 28)
	box.add_child(restart_button)
	restart_button.pressed.connect(restart)
	player.died.connect(_game_over)
	panel.hide()

func _game_over() -> void:
	var input: RunnerTouchInput = player.get_node("TouchInput")
	input.reset_input()
	input.set_process_unhandled_input(false)
	panel.show()
	restart_button.grab_focus()

func restart() -> void:
	panel.hide()
	_finger = -1
	var input: RunnerTouchInput = player.get_node("TouchInput")
	input.reset_input()
	input.set_process_unhandled_input(true)
	player.reset_run()
	get_parent().get_node("RunnerCamera").snap_to_target()

func _input(event: InputEvent) -> void:
	if not player.dead:
		return
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		call_deferred("restart")
	elif event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.canceled:
			_finger = -1
		elif event.pressed and restart_button.get_global_rect().has_point(event.position):
			_finger = event.index
		elif not event.pressed and event.index == _finger:
			_finger = -1
			if restart_button.get_global_rect().has_point(event.position):
				call_deferred("restart")
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
