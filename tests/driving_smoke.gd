extends SceneTree

var track: Node3D
var car: PlayerCar
var rig: Node3D
var hud: CanvasLayer
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	track = load("res://scenes/test_track.tscn").instantiate()
	root.add_child(track)
	current_scene = track
	car = track.get_node("PlayerCar")
	# The compact regression track uses its original speed; 220 km/h has a separate suite.
	car.forward_speed = 22.0
	rig = track.get_node("ChaseCamera")
	hud = track.get_node("HUD")
	await _frames(5)

	var events_before := InputMap.action_get_events("accelerate").size()
	InputSetup.configure()
	_check(InputMap.action_get_events("accelerate").size() == events_before, "input setup is idempotent")
	var axis := InputEventJoypadMotion.new()
	axis.device = 1
	axis.axis = JOY_AXIS_TRIGGER_RIGHT
	axis.axis_value = 0.6
	Input.parse_input_event(axis)
	await process_frame
	_check(Input.get_action_strength("accelerate") > 0.4, "analog throttle accepts a second controller")
	axis = InputEventJoypadMotion.new()
	axis.device = 1
	axis.axis = JOY_AXIS_TRIGGER_RIGHT
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	await process_frame

	await _prepare()
	Input.action_press("accelerate")
	await _frames(180)
	_check(car.drive_speed > 20.0 and car.drive_speed <= car.forward_speed + 0.1, "acceleration reaches the speed limit")
	_check(car.global_position.z < 20.0 and absf(car.global_position.x + 10.0) < 0.1, "straight driving remains straight")
	var driving_camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	_check(driving_camera.fov > rig.base_fov + 2.0, "field of view expands slightly with speed")
	var before_coasting := car.drive_speed
	Input.action_release("accelerate")
	await _frames(60)
	_check(car.drive_speed > 0.0 and car.drive_speed < before_coasting, "releasing the pedal coasts gradually")

	await _prepare()
	car.velocity = Vector3(0.0, 0.0, -12.0)
	Input.action_press("accelerate", 0.5)
	await _frames(30)
	_check(car.drive_speed > 12.5, "partial throttle applies torque above the old half-speed target")
	var half_throttle_speed := car.drive_speed
	await _prepare()
	car.velocity = Vector3(0.0, 0.0, -12.0)
	Input.action_press("accelerate")
	await _frames(30)
	_check(car.drive_speed > half_throttle_speed + 1.0, "full throttle accelerates faster than partial throttle")
	await _prepare()
	car.velocity = Vector3(0.0, 0.0, 5.0)
	Input.action_press("brake", 0.5)
	await _frames(20)
	_check(car.drive_speed < -5.0 and car.drive_speed >= -car.reverse_speed, "partial reverse pedal adds torque above half reverse speed")

	await _prepare()
	car.velocity = Vector3(0.0, 0.0, -12.0)
	Input.action_press("brake")
	await _frames(72)
	_check(absf(car.drive_speed) < 0.3, "brake stops the car before selecting reverse")
	await _frames(60)
	_check(car.drive_speed < -3.0 and car.drive_speed >= -car.reverse_speed - 0.1, "holding brake engages limited reverse")
	_release_actions()

	await _prepare()
	car.velocity = Vector3(0.0, 0.0, -8.0)
	Input.action_press("steer_right")
	await _frames(20)
	_check(car.rotation.y < -0.05, "right input turns right while driving forward")
	_check(car.steering_input > 0.9, "keyboard steering ramps up smoothly")
	var low_speed_angle := absf(car.steering_angle)
	car.velocity = -car.global_basis.z * car.forward_speed
	await _frames(2)
	_check(absf(car.steering_angle) < low_speed_angle, "steering angle decreases at high speed")

	await _prepare()
	car.velocity = Vector3(0.0, 0.0, 6.0)
	Input.action_press("steer_right")
	await _frames(20)
	_check(car.rotation.y > 0.05, "steering reverses naturally when backing up")

	await _prepare()
	car.velocity = Vector3(0.0, 0.0, -22.0)
	Input.action_press("steer_right")
	Input.action_press("handbrake")
	await _frames(30)
	var sliding_speed := absf(car.lateral_speed)
	_check(sliding_speed > 1.5, "handbrake allows lateral sliding in a turn")
	_release_actions()
	await _frames(90)
	_check(absf(car.lateral_speed) < 0.5, "tires recover grip after releasing handbrake")

	await _prepare(Vector3(4.4, 0.36, -8.0))
	car.velocity = Vector3(0.0, 0.0, -22.0)
	Input.action_press("accelerate")
	await _frames(60)
	_check(car.global_position.z > -12.8, "car does not pass through the test obstacle")
	_check(absf(car.drive_speed) < 0.5, "collision removes forward speed")

	await _prepare(Vector3(-20.0, 0.36, 6.0))
	car.velocity = Vector3(0.0, 0.0, -12.0)
	Input.action_press("accelerate")
	await _frames(60)
	_check(car.global_position.y > 1.0 and car.global_position.z < -5.0, "car climbs the practice ramp")
	await _frames(50)
	_release_actions()
	await _frames(100)
	_check(car.is_on_floor() and car.global_position.y < 0.5, "car lands stably after leaving the ramp")

	await _prepare(Vector3(0.0, 0.36, 56.0))
	var arm: SpringArm3D = rig.get_node("SpringArm3D")
	var camera: Camera3D = arm.get_node("Camera3D")
	await _frames(5)
	_check(arm.get_hit_length() < arm.spring_length - 1.0, "camera arm retracts against a wall")
	_check(camera.global_position.z < 59.2, "camera stays in front of the wall")
	Input.action_press("camera_back")
	await _frames(2)
	_check(camera.global_position.z < car.global_position.z, "rear view switches to the front of the car")
	Input.action_release("camera_back")
	car.reset_car()
	_check(car.velocity == Vector3.ZERO, "reset clears vehicle momentum")
	_check(rig.global_position.distance_to(car.global_position + Vector3.UP * rig.target_height) < 0.01, "reset snaps the camera to the car")
	car.global_position.y = -5.0
	await _frames(2)
	_check(car.global_position.distance_to(car.spawn_transform.origin) < 0.1, "falling below the track resets the car")

	await _prepare()
	Input.action_press("accelerate")
	await _frames(15)
	await _tap_escape()
	_check(paused and hud.get_node("Overlay/PauseMenu").visible, "Escape opens the pause menu")
	var paused_position := car.global_position
	await _frames(30)
	_check(car.global_position.is_equal_approx(paused_position), "pause freezes vehicle physics")
	await _tap_escape()
	await _frames(5)
	_check(not paused and car.global_position.distance_to(paused_position) > 0.01, "Escape resumes driving")
	hud.set_paused(true)
	hud.get_node("Overlay/PauseMenu/Center/Buttons/Reset").pressed.emit()
	_check(not paused and car.velocity == Vector3.ZERO, "pause menu reset returns to driving")
	_release_actions()

	car.forward_speed = 8.0
	await _prepare(Vector3(-33, 0.36, 31))
	car.velocity = Vector3(0, 0, -8)
	Input.action_press("accelerate")
	var hill_height := 0.0
	for frame in 320:
		await _frames(1)
		hill_height = maxf(hill_height, car.position.y)
	_check(hill_height > 1.75 and car.position.z < -8.0 and car.is_on_floor() and car.position.y < 0.65, "practice hill supports ascent, crest and continuous descent")
	await _prepare(Vector3(-40, 0.36, -27))
	car.forward_speed = 4.0
	car.rotation.y = -PI * 0.5
	Input.action_press("accelerate")
	await _frames(145)
	var bank_up := Basis.from_euler(Vector3(0, 0, 0.12)) * Vector3.UP
	_check(car.position.x > -33.5 and car.is_on_floor() and car.global_basis.y.angle_to(bank_up) < deg_to_rad(3.0), "practice bank is accessible from its low edge and aligns the car")
	car.forward_speed = 22.0
	_release_actions()
	print("Driving smoke test: %d checks, %d failures" % [checks, failures])
	track.queue_free()
	await process_frame
	# Allow the audio thread to complete its stop fade in wall time.
	OS.delay_msec(100)
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)


func _prepare(position: Vector3 = Vector3(-10.0, 0.36, 40.0)) -> void:
	_release_actions()
	car.reset_car()
	car.global_position = position
	rig.snap_to_target()
	await _frames(5)


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _tap_escape() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _release_actions() -> void:
	for action: StringName in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "camera_back", "reset_car"]:
		Input.action_release(action)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
