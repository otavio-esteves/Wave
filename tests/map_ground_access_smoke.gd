extends "res://tests/rally_access_smoke.gd"

const Circuit = preload("res://scripts/race/circuit_layout.gd")
const Intercity = preload("res://scripts/world/intercity_layout.gd")
const Elevation = preload("res://scripts/world/elevation_layout.gd")

func _run() -> void:
	var cases := [
		["res://scenes/test_track.tscn", [[Vector3(-33, 0.36, 30), Vector3(-33, 0.36, -18)]]],
		["res://scenes/city/drive_neighborhood.tscn", [[Vector3(5, 0.36, -34), Vector3(10, 0.36, -34)], [Vector3(-5, 0.36, -34), Vector3(-10, 0.36, -34)]]],
		["res://scenes/corridor/drive_corridor.tscn", _avenue_routes(-62)],
		["res://scenes/world/drive_streamed_corridor.tscn", _avenue_routes(-62)],
		["res://scenes/world/drive_intercity.tscn", _intercity_routes()],
		["res://scenes/race/drive_race.tscn", _circuit_routes()],
		["res://scenes/world/drive_elevation.tscn", _elevation_routes()],
	]
	for entry in cases:
		change_scene_to_file(entry[0])
		await scene_changed
		var world := current_scene
		for route in entry[1]:
			await _cross(world, route[0], route[1])
			await _cross(world, route[1], route[0])
		world.queue_free()
		await _frames(5)
		OS.delay_msec(150)
	print("Map ground access: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _avenue_routes(z: float) -> Array:
	return [[Vector3(3.5, 0.36, z), Vector3(7.9, 0.36, z)], [Vector3(-3.5, 0.36, z), Vector3(-7.9, 0.36, z)]]

func _intercity_routes() -> Array:
	var routes := _avenue_routes(-62)
	routes.append_array(_avenue_routes(-1130))
	for z in [-480.0, -850.0]:
		for side in [-1.0, 1.0]:
			routes.append([Intercity.point(z, side * 3.5), Intercity.point(z, side * 10)])
	return routes

func _circuit_routes() -> Array:
	var routes := []
	var points := Circuit.route()
	for index in [80, 260, 440]:
		var right := Circuit.tangent(points, index).cross(Vector3.UP).normalized()
		for side in [-1.0, 1.0]:
			var a: Vector3 = points[index] + right * side * 4 + Vector3.UP * 0.36
			var b: Vector3 = points[index] + right * side * 13 + Vector3.UP * 0.36
			routes.append([a, b])
	return routes

func _elevation_routes() -> Array:
	var routes := []
	for z in [-230.0, -425.0]:
		for side in [-1.0, 1.0]:
			routes.append([Elevation.point(z, side * 3.5), Elevation.point(z, side * 10)])
	return routes

func _cross(world: Node3D, start: Vector3, end: Vector3) -> void:
	var car: PlayerCar = world.get_node("PlayerCar")
	var direction := Vector3(end.x - start.x, 0, end.z - start.z).normalized()
	var heading := atan2(-direction.x, -direction.z)
	var streamer := world.get_node_or_null("WorldStreamer") as WorldStreamer
	if streamer != null:
		world.teleport_to(start, heading)
		for frame in 900:
			await _frames(1)
			OS.delay_usec(2000)
			if not streamer.blocked:
				break
	else:
		car.reset_car()
		car.global_position = start
		car.rotation = Vector3(0, heading, 0)
	await _frames(25)
	var holds := streamer.blocking_events if streamer != null else 0
	var arrived := false
	var grounded := 0
	var frames := 0
	var distance := Vector2(end.x - start.x, end.z - start.z).length()
	for frame in 1800:
		Input.action_release("accelerate")
		Input.action_release("brake")
		Input.action_press("accelerate" if car.drive_speed < 3 else "brake", 0.5)
		var error := wrapf(heading - car.get_heading(), -PI, PI)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		Input.action_press("steer_left" if error > 0 else "steer_right", minf(absf(error) * 2.4, 1.0))
		await _frames(1)
		frames += 1
		if streamer != null:
			OS.delay_usec(2000)
		if car.is_on_floor():
			grounded += 1
		if (car.global_position - start).dot(direction) >= distance:
			arrived = true
			break
	for action in ["accelerate", "brake", "steer_left", "steer_right"]:
		Input.action_release(action)
	var deviation := absf((car.global_position - start).dot(direction.cross(Vector3.UP)))
	_check(arrived and deviation < 0.75, "%s crosses ground transition %s -> %s; end=%s" % [world.scene_file_path.get_file(), start, end, car.global_position])
	_check(car.is_on_floor() and float(grounded) / maxi(frames, 1) > 0.97 and (streamer == null or streamer.blocking_events == holds), "crossing keeps physical ground contact without streaming holds")
