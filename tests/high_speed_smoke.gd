extends SceneTree

const Builder = preload("res://scripts/city/neighborhood_builder.gd")
var checks := 0
var failures := 0
var car: PlayerCar
var world: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/city/drive_neighborhood.tscn")
	await _frames(10)
	world = current_scene
	car = world.get_node("PlayerCar")
	_check(absf(car.forward_speed * 3.6 - 220.0) < 0.001, "default car allows 220 km/h")
	var saved_floor_size := 0.0
	for shape in world.get_node("NeighborhoodMap/CityColliders").get_children():
		if shape is CollisionShape3D and shape.shape is BoxShape3D:
			saved_floor_size = maxf(saved_floor_size, shape.shape.size.x)
	_check(absf(pow(saved_floor_size / 536.0, 2) - 5.0) < 0.00001, "map footprint is five times the previous area")
	car.position = Vector3(493.5, 0.36, 520)
	world.get_node("ChaseCamera").snap_to_target()
	await _frames(5)
	var capture := world.get_node("PerformanceCapture")
	capture.measure_render_time = "--profile-render-time" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		var settings := root.get_node("WaveSettings")
		settings.set_graphics_preset("legacy" if "--legacy" in OS.get_cmdline_user_args() else "economy")
		root.unresizable = true
		for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "camera_view", "camera_back", "pause"]:
			InputMap.action_erase_events(action)
			Input.action_release(action)
		await create_timer(5.0).timeout
		settings.apply_graphics()
		await create_timer(0.3).timeout
		_check(root.size == settings.RESOLUTIONS[settings.graphics["resolution"]], "high-speed benchmark confirms native window size")
		capture.benchmark_metadata = {"route_id": "high-speed-v2", "screenshot_during_capture": "--screenshot-at-speed" in OS.get_cmdline_user_args(), "warmup_seconds": 5.0, "target_kmh": 220.0, "fixture": "outer neighborhood avenue; not future highway"}
		if "--foreground" in OS.get_cmdline_user_args():
			root.grab_focus()
			await create_timer(0.3).timeout
		if "--no-vsync" in OS.get_cmdline_user_args():
			root.get_node("WaveSettings").set_graphics("vsync", false)
		capture.toggle()
	Input.action_press("accelerate")
	var previous := car.position
	var time_to_100 := 0.0
	for frame in 900:
		previous = car.position
		await _frames(1)
		if time_to_100 == 0.0 and car.get_speed_kmh() >= 100.0:
			time_to_100 = (frame + 1) / 60.0
	_check(time_to_100 > 3.0 and time_to_100 < 4.0, "real 0–100 acceleration is slower while top speed remains available")
	print("Measured 0–100: %.2f s" % time_to_100)
	var measured_speed := car.position.distance_to(previous) * 60.0 * 3.6
	if DisplayServer.get_name() != "headless" and "--screenshot-at-speed" in OS.get_cmdline_user_args():
		# Opt-in visual diagnostic: GPU readback/PNG encoding contaminate timing.
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://car-220.png")
	_check(car.get_speed_kmh() > 219.9 and car.get_speed_kmh() < 220.1, "full throttle reaches 220 km/h on the real map")
	_check(absf(car.position.x - 493.5) < 0.05 and car.position.z < 50.0 and car.position.z > -350.0 and car.is_on_floor(), "long outer avenue is continuous at maximum speed")
	_check(absf(measured_speed - car.get_speed_kmh()) < 0.5, "actual travel speed agrees with the 220 km/h speedometer")
	Input.action_release("accelerate")
	var before_coast := car.get_speed_kmh()
	await _frames(60)
	_check(car.get_speed_kmh() > 200.0 and car.get_speed_kmh() < before_coast, "high-speed coasting loses speed progressively")
	var braking_start := car.position
	Input.action_press("brake")
	for frame in 420:
		await _frames(1)
		if absf(car.drive_speed) < 0.1:
			break
	Input.action_release("brake")
	if capture.recording:
		capture.finish()
	_check(absf(car.drive_speed) < 0.1 and car.position.distance_to(braking_start) > 120.0 and car.position.distance_to(braking_start) < 200.0, "brakes stop the car from high speed within the available straight")
	var barrier := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 2, 0.1)
	collision.shape = box
	barrier.add_child(collision)
	barrier.position = Vector3(493.5, 1, -300)
	world.add_child(barrier)
	car.reset_car()
	car.position = Vector3(493.5, 0.36, -290)
	await _frames(5)
	car.velocity = Vector3(0, 0, -car.forward_speed)
	Input.action_press("accelerate")
	await _frames(20)
	_check(car.position.z > -298.3 and absf(car.drive_speed) < 0.2, "220 km/h collision does not tunnel through a thin barrier")
	Input.action_release("accelerate")
	# A separate large floor isolates tire forces from city obstacles.
	world.queue_free()
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(3000, 0.6, 3000)
	floor_collision.shape = floor_shape
	floor_body.position.y = -0.3
	floor_body.add_child(floor_collision)
	world.add_child(floor_body)
	car = load("res://scenes/cars/player_car.tscn").instantiate()
	car.position.y = 0.36
	world.add_child(car)
	await _frames(10)
	car.velocity = Vector3(0, 0, -car.forward_speed)
	Input.action_press("accelerate")
	Input.action_press("steer_right")
	var max_corner_acceleration := 0.0
	for frame in 120:
		await _frames(1)
		var turning := car.drive_speed * car.drive_speed / car.wheelbase * absf(tan(car.steering_angle))
		max_corner_acceleration = maxf(max_corner_acceleration, turning)
	_check(max_corner_acceleration <= car.max_lateral_acceleration + 0.2, "high-speed steering respects the tire-force limit")
	_check(absf(car.get_heading()) > 0.1 and absf(car.get_heading()) < 0.6 and car.is_on_floor(), "full steering at 220 km/h produces a stable broad turn")
	Input.action_release("accelerate")
	Input.action_release("steer_right")
	car.reset_car()
	car.velocity = Vector3(15, 0, -20)
	var initial_side := car.velocity.x
	await _frames(1)
	_check(initial_side - car.velocity.x <= car.max_lateral_acceleration / 60.0 + 0.03, "tires cannot erase a large lateral slip in one physics frame")
	car.reset_car()
	_check(car.velocity == Vector3.ZERO and car.global_basis.is_equal_approx(car.spawn_transform.basis), "reset clears high-speed momentum and steering")
	print("High speed smoke test: %d checks, %d failures" % [checks, failures])
	world.queue_free()
	await process_frame
	OS.delay_msec(150)
	await process_frame
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
