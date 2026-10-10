extends SceneTree

var checks := 0
var failures := 0
var world: Node3D
var rig: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	world = load("res://scenes/test_track.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	rig = world.get_node("ChaseCamera")
	world.get_node("PlayerCar").set_physics_process(false)
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
	await _frames(6)
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "driving captures the mouse")
	var count := InputMap.action_get_events("camera_look_right").size()
	InputSetup.configure()
	_check(InputMap.action_get_events("camera_look_right").size() == count, "camera gamepad bindings are idempotent")
	_mouse(Vector2(180, -70))
	await _frames(2)
	_check(rig.look_offset.x < -0.4 and rig.look_offset.y > 0.15, "mouse motion rotates the camera horizontally and vertically")
	var held: Vector2 = rig.look_offset
	await _frames(30)
	_check(rig.look_offset.is_equal_approx(held), "camera holds its angle briefly after manual input")
	await _frames(55)
	_check(rig.look_offset.length() < held.length() and rig.look_offset.length() > held.length() * 0.3, "return starts gradually rather than snapping")
	await _frames(240)
	_check(rig.look_offset.length() < 0.002, "inactivity restores the automatic chase view")
	_mouse(Vector2(0, -2000))
	await _frames(2)
	_check(rig.look_offset.y <= 0.24, "vertical mouse orbit cannot move the chase camera below the car")
	rig.snap_to_target()
	_axis(JOY_AXIS_RIGHT_X, 0.08)
	await _frames(20)
	_check(rig.look_offset == Vector2.ZERO, "right-stick drift inside the deadzone leaves the camera centered")
	_axis(JOY_AXIS_RIGHT_X, 0.75)
	await _frames(20)
	_check(rig.look_offset.x < -0.4, "right stick controls the camera on a second controller")
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_button(JOY_BUTTON_RIGHT_STICK, true)
	await _frames(2)
	_button(JOY_BUTTON_RIGHT_STICK, false)
	var center_start: float = rig.look_offset.length()
	await _frames(12)
	_check(rig.look_offset.length() < center_start * 0.8, "R3 starts a smooth return without waiting for the idle delay")
	_mouse(Vector2(170, -40))
	await _frames(2)
	var live_car: PlayerCar = world.get_node("PlayerCar")
	live_car.position.x += 4
	live_car.set_physics_process(true)
	await _frames(2)
	var pause_position := live_car.position
	var before_pause: Vector2 = rig.look_offset
	world.get_node("HUD").set_paused(true)
	await process_frame
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause releases the cursor for menus")
	_mouse(Vector2(300, 80))
	await process_frame
	_check(rig.look_offset == before_pause, "menu mouse motion never rotates the paused camera")
	_button(JOY_BUTTON_B, true)
	await process_frame
	_button(JOY_BUTTON_B, false)
	await _frames(2)
	_check(not paused, "Circle closes the pause menu")
	_check(live_car.position.distance_to(pause_position) < 0.2, "Circle cancels pause without also resetting the vehicle")
	live_car.set_physics_process(false)
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "resume restores mouse control")
	rig.snap_to_target()
	_button(JOY_BUTTON_X, true)
	await _frames(2)
	_button(JOY_BUTTON_X, false)
	_check(rig.hood_view, "Square switches to the hood camera")
	_mouse(Vector2(100, -40))
	await _frames(2)
	_check(absf(rig.arm.rotation.y) > 0.2 and rig.arm.spring_length == 0, "mouse also looks around from the hood camera")
	_button(JOY_BUTTON_Y, true)
	await _frames(2)
	_check(is_equal_approx(absf(rig.arm.rotation.y), PI), "Triangle overrides the orbit with a direct rear view")
	_button(JOY_BUTTON_Y, false)
	await _frames(2)
	_check(absf(rig.arm.rotation.y) < 1.0, "releasing rear view restores the manual orbit")
	world.get_node("PlayerCar").reset_car()
	await _frames(2)
	_check(not rig.hood_view and rig.look_offset == Vector2.ZERO, "vehicle reset clears manual camera offsets")
	live_car.position.x += 3
	live_car.set_physics_process(true)
	_button(JOY_BUTTON_B, true)
	await _frames(2)
	_button(JOY_BUTTON_B, false)
	_check(live_car.position.distance_to(live_car.spawn_transform.origin) < 0.2, "a fresh Circle press while driving still resets the vehicle")
	live_car.set_physics_process(false)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.5)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.3)
	_axis(JOY_AXIS_LEFT_X, -0.6)
	await _frames(2)
	_check(Input.get_action_strength("accelerate") > 0.45 and Input.get_action_strength("brake") > 0.25 and Input.get_axis("steer_left", "steer_right") < -0.5, "R2, L2 and left stick remain independent analog driving controls")
	for axis in [JOY_AXIS_TRIGGER_RIGHT, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_LEFT_X]:
		_axis(axis, 0.0)
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	await _frames(3)
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "returning to the main menu releases the cursor")
	_button(JOY_BUTTON_A, true)
	await _frames(2)
	_button(JOY_BUTTON_A, false)
	await _frames(5)
	_check(current_scene.scene_file_path == "res://scenes/city/drive_pilot_city.tscn" and current_scene.get_node_or_null("PlayerCar") is PlayerCar and current_scene.get_node_or_null("City") != null, "Cross selects the default pilot-city menu action")
	current_scene.queue_free()
	await _frames(2)
	print("Camera and gamepad: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _mouse(motion: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = motion
	event.screen_relative = motion
	if DisplayServer.get_name() == "headless" and not paused:
		# The dummy display cannot capture a cursor; exercise orbit math here.
		# The rendered run exercises actual mouse event delivery and capture.
		rig._add_look(-motion * rig.mouse_sensitivity)
	else:
		Input.parse_input_event(event)

func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 1
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

func _button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 1
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
