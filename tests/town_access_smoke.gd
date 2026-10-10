extends SceneTree

const Layout = preload("res://scripts/world/intercity_layout.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("WaveSettings").set_graphics_preset("economy")
	change_scene_to_file("res://scenes/world/drive_intercity.tscn")
	await scene_changed
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "pause"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	var routes := [
		{"z": Layout.TOWN_SQUARE_Z, "start_x": 3.5, "end_x": -27.0, "heading": PI / 2, "label": "avenue to square through the open curb"},
		{"z": Layout.TOWN_SQUARE_Z, "start_x": -27.0, "end_x": 3.5, "heading": -PI / 2, "label": "square back to avenue"},
		{"z": Layout.TOWN_CROSSROAD_Z, "start_x": 3.5, "end_x": 45.0, "heading": -PI / 2, "label": "crossroad to the eastern side street"},
		{"world_z": Layout.RURAL_STOP_Z, "start_x": Layout.point(Layout.RURAL_STOP_Z).x, "end_x": -21.0, "heading": PI / 2, "label": "road to rural stop through its fence opening"},
		{"world_z": Layout.RURAL_STOP_Z, "start_x": -21.0, "end_x": Layout.point(Layout.RURAL_STOP_Z).x, "heading": -PI / 2, "label": "rural stop back to road"},
		{"world_z": Layout.HIGHWAY_STOP_Z, "start_x": Layout.point(Layout.HIGHWAY_STOP_Z).x, "end_x": 20.0, "heading": -PI / 2, "label": "highway to roadside refuge through its fence opening"},
		{"world_z": Layout.HIGHWAY_STOP_Z, "start_x": 20.0, "end_x": Layout.point(Layout.HIGHWAY_STOP_Z).x, "heading": PI / 2, "label": "roadside refuge back to highway"},
	]
	for route in routes:
		var world_z: float = Layout.TOWN_ORIGIN_Z + route.z if route.has("z") else route.world_z
		world.teleport_to(Vector3(route.start_x, 0.36, world_z), route.heading)
		await _support(streamer)
		await _frames(8)
		var holds := streamer.blocking_events
		var grounded := true
		var arrived := false
		var max_deviation := 0.0
		# A half-throttle launch now takes longer to cover the side street;
		# retain the same endpoint, clearance and support requirements.
		for frame in 900:
			if (route.end_x < route.start_x and car.position.x <= route.end_x) or (route.end_x > route.start_x and car.position.x >= route.end_x):
				arrived = true
				break
			Input.action_release("accelerate")
			Input.action_release("brake")
			Input.action_press("accelerate" if car.drive_speed < 6 else "brake", 0.5)
			await _frames(1)
			grounded = grounded and car.is_on_floor()
			max_deviation = maxf(max_deviation, absf(car.position.z - world_z))
		Input.action_release("accelerate")
		Input.action_release("brake")
		print("Access %s: arrived=%s deviation=%.3f end=%s" % [route.label, arrived, max_deviation, car.position])
		_check(arrived and max_deviation < 0.5, route.label + " is physically drivable")
		_check(grounded and streamer.blocking_events == holds, route.label + " maintains support without streaming holds")
	_check(streamer.failure_count == 0 and streamer.peak_resident_cells <= 3, "town exploration preserves the bounded resident set")
	world.queue_free()
	await _frames(5)
	OS.delay_msec(150)
	await _frames(5)
	await create_timer(0.2).timeout
	print("Town access smoke test: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _support(streamer: WorldStreamer) -> void:
	for frame in 900:
		await _frames(1)
		if not streamer.blocked:
			return
	_check(false, "town collision support loads before the test deadline")


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		if DisplayServer.get_name() == "headless":
			OS.delay_usec(2000)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
