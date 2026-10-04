class_name InputSetup
extends RefCounted


static func configure() -> void:
	_add_key("accelerate", KEY_W)
	_add_key("accelerate", KEY_UP)
	_add_axis("accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_key("brake", KEY_S)
	_add_key("brake", KEY_DOWN)
	_add_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_key("steer_left", KEY_A)
	_add_key("steer_left", KEY_LEFT)
	_add_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_key("steer_right", KEY_D)
	_add_key("steer_right", KEY_RIGHT)
	_add_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_add_key("handbrake", KEY_SPACE)
	_add_button("handbrake", JOY_BUTTON_A)
	_add_key("camera_back", KEY_C)
	_add_button("camera_back", JOY_BUTTON_Y)
	_add_key("reset_car", KEY_R)
	_add_button("reset_car", JOY_BUTTON_B)
	_add_key("pause", KEY_ESCAPE)
	_add_button("pause", JOY_BUTTON_START)
	_add_key("toggle_diagnostics", KEY_F3)
	_add_key("capture_performance", KEY_F4)


static func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


static func _add_key(action: StringName, key: Key) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


static func _add_button(action: StringName, button: JoyButton) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


static func _add_axis(action: StringName, axis: JoyAxis, direction: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = direction
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
