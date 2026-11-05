extends SceneTree

const FixtureInput = preload("fixture_input.gd")
var world: Node3D
var car: PlayerCar
var rig: Node3D
var audio: Node
var checks := 0
var failures := 0
var measurements: Array[Dictionary] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="):
			Engine.physics_ticks_per_second = int(argument.get_slice("=", 1))
	_run.call_deferred()


func _run() -> void:
	InputSetup.configure()
	FixtureInput.isolate()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4000, 0.6, 4000)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -0.3
	world.add_child(floor_body)
	car = load("res://scenes/cars/player_car.tscn").instantiate()
	car.position.y = 0.36
	world.add_child(car)
	rig = load("res://scenes/cars/chase_camera.tscn").instantiate()
	world.add_child(rig)
	audio = load("res://scripts/audio/driving_audio.gd").new()
	world.add_child(audio)
	await _seconds(0.3)

	await _prepare(22.0)
	Input.action_press("accelerate", 0.7)
	Input.action_press("steer_right", 0.7)
	var grip_slip := 0.0
	for frame in Engine.physics_ticks_per_second * 3:
		await _frames(1)
		grip_slip = maxf(grip_slip, absf(_slip()))
	_check(grip_slip < deg_to_rad(4) and car.drift_amount == 0.0, "ordinary powered cornering stays planted without entering drift")
	_check(audio.tires.volume_db < -50.0, "planted cornering does not play a continuous tire squeal")
	_check(is_equal_approx(car.arcade_acceleration_scale, 0.4), "the previously chosen gradual acceleration is preserved")

	for direction: float in [-1.0, 1.0]:
		await _enter_slide(direction, 0.7)
		var speed_at_entry := car.get_speed_kmh()
		await _seconds(1.8)
		var slip := _slip()
		_check(slip * direction < -deg_to_rad(15) and absf(slip) < deg_to_rad(34), "short handbrake tap carries a bounded slide in either direction")
		_check(car.is_on_floor() and car.get_speed_kmh() > speed_at_entry * 0.75, "carried slide retains useful speed and ground contact without a boost")
		_check(audio.tires.volume_db > -30.0, "tire sound makes actual asphalt slip audible")
		var travel_heading := atan2(-car.velocity.x, -car.velocity.z)
		var body_to_travel := wrapf(travel_heading - car.get_heading(), -PI, PI)
		var body_to_camera := wrapf(rig.rotation.y - car.get_heading(), -PI, PI)
		_check(body_to_camera * body_to_travel > 0.0 and absf(body_to_camera) < absf(body_to_travel), "drift camera frames the corner exit while retaining visible body slip")
		measurements.append({"direction": direction, "slip_degrees": rad_to_deg(slip), "speed_kmh": car.get_speed_kmh()})
		_steer(-direction * 0.5)
		await _seconds(1.0)
		_check(car.drift_amount == 0.0 and absf(_slip()) < deg_to_rad(4), "countersteering catches a carried slide without spinning or reversing drift")
		_check(car.velocity.is_finite() and car.drive_speed > 0.0, "countersteer recovery preserves finite forward momentum")

	await _enter_slide(1.0, 0.7)
	await _seconds(1.5)
	var powered_slip := absf(_slip())
	Input.action_press("accelerate", 0.35)
	await _seconds(1.0)
	_check(absf(_slip()) < powered_slip - deg_to_rad(3), "feathering the accelerator reduces the drift angle")
	_release()
	await _seconds(1.5)
	_check(car.drift_amount == 0.0 and absf(car.lateral_speed) < 0.5, "lifting and centering recover normal grip progressively")

	await _enter_slide(1.0, 0.7)
	await _seconds(0.6)
	Input.action_press("brake")
	Input.action_release("accelerate")
	await _seconds(0.6)
	_check(car.drift_amount == 0.0, "service braking ends drift assistance")

	await _prepare(22.0)
	Input.action_press("handbrake")
	Input.action_press("steer_right", 0.7)
	await _seconds(6.0)
	_check(car.get_speed_kmh() < 0.5, "holding the handbrake still stops the vehicle")
	for speed: float in [4.0, -5.0]:
		await _prepare(speed)
		Input.action_press("handbrake")
		Input.action_press("steer_right", 0.7)
		await _seconds(0.2)
		_check(car.drift_amount == 0.0, "parking and reverse maneuvers never arm the forward drift assist")

	await _enter_slide(1.0, 0.7)
	await _seconds(0.5)
	car.reset_car()
	_check(car.drift_amount == 0.0 and audio.tires.volume_db <= -60.0 and audio.wind.volume_db <= -60.0, "reset clears drift, camera anticipation and vehicle feedback sounds")
	_check(rig.look_offset == Vector2.ZERO and is_equal_approx(rig.camera.fov, rig.base_fov), "reset restores the centered camera and resting field of view")
	_release()
	car.set_physics_process(false)
	car.velocity = Vector3.ZERO
	await _seconds(1.0)
	var resting_fov: float = rig.camera.fov
	car.velocity = Vector3(0, 0, -100.0 / 3.6)
	car.drive_speed = 100.0 / 3.6
	car.lateral_speed = 0.0
	await _seconds(1.5)
	var cruising_fov: float = rig.camera.fov
	_check(cruising_fov > resting_fov + 7.0 and cruising_fov < resting_fov + 12.0, "camera conveys urban cruising speed with a smooth bounded FOV increase")
	_check(audio.wind.volume_db > -45.0 and audio.tires.volume_db < -50.0, "cruising adds airflow without a false tire squeal")
	car.velocity = Vector3(0, 0, -70)
	car.drive_speed = 70.0
	await _seconds(1.0)
	_check(rig.camera.fov <= rig.base_fov + rig.speed_fov + 0.01 and absf(rig.rotation.z) < 0.001, "high-speed camera caps its FOV and keeps a level horizon")
	var top_pitch: float = audio.engine.pitch_scale
	car.drive_speed = 72.0
	await _seconds(1.0)
	_check(absf(audio.engine.pitch_scale - top_pitch) < 0.05, "top-gear sound avoids repeated artificial upshifts")
	rig.hood_view = true
	await _seconds(1.0)
	_check(rig.camera.fov <= rig.base_fov + 5.0 and rig.arm.spring_length == 0.0, "hood view retains restrained speed feedback")
	car.drive_speed = 8.2
	await _seconds(0.1)
	car.drive_speed = 7.8
	await _seconds(0.1)
	_check(audio.get("_gear") == 1, "gear hysteresis prevents pitch chatter around the shift point")
	car.drive_speed = 6.0
	await _seconds(0.1)
	_check(audio.get("_gear") == 0, "a deliberate slowdown permits a downshift")

	paused = true
	await process_frame
	_check(audio.tires.stream_paused and audio.wind.stream_paused, "pause suspends both new vehicle feedback layers")
	paused = false
	car.reset_car()
	world.queue_free()
	await process_frame
	OS.delay_msec(100)
	await process_frame
	var result := {"checks": checks, "failures": failures, "physics_hz": Engine.physics_ticks_per_second, "slides": measurements, "scope": "functional physics/camera/audio state; subjective feel and rendered FPS require playtesting"}
	var file := FileAccess.open("user://driving-feel-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("Driving feel: %d checks, %d failures; %s" % [checks, failures, JSON.stringify(result)])
	quit(0 if failures == 0 else 1)


func _enter_slide(direction: float, throttle: float) -> void:
	await _prepare(22.0)
	_steer(direction * 0.7)
	Input.action_press("handbrake")
	await _seconds(0.2)
	Input.action_release("handbrake")
	Input.action_press("accelerate", throttle)


func _prepare(speed: float) -> void:
	_release()
	car.reset_car()
	await _seconds(0.3)
	car.velocity = Vector3(0, 0, -speed)


func _steer(value: float) -> void:
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("steer_right" if value > 0.0 else "steer_left", absf(value))


func _slip() -> float:
	return atan2(car.lateral_speed, maxf(car.drive_speed, 0.1))


func _release() -> void:
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake"]:
		Input.action_release(action)


func _seconds(duration: float) -> void:
	await _frames(roundi(duration * Engine.physics_ticks_per_second))


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
