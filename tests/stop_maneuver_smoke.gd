extends "res://tests/town_access_smoke.gd"

const DRIVE_ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "handbrake"]
var grounded := true
var entry_speed := 0.0


func _run() -> void:
	root.get_node("WaveSettings").set_graphics_preset("economy")
	change_scene_to_file("res://scenes/world/drive_intercity.tscn")
	await scene_changed
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	for action in DRIVE_ACTIONS + ["reset_car", "pause"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	var stops := [
		{"name": "rural stop", "z": Layout.RURAL_STOP_Z, "x": -23.0, "side": -1.0},
		{"name": "highway refuge", "z": Layout.HIGHWAY_STOP_Z, "x": 20.0, "side": 1.0},
		{"name": "town square", "z": Layout.TOWN_ORIGIN_Z + Layout.TOWN_SQUARE_Z, "x": -27.0, "side": -1.0},
	]
	for stop in stops:
		for returning in [false, true]:
			var direction := 1.0 if returning else -1.0
			var lane := -3.5 if returning else 3.5
			var start_z: float = stop.z - direction * 90.0
			world.teleport_to(Layout.point(start_z, lane), PI if returning else 0.0)
			await _support(streamer)
			await _frames(8)
			var holds := streamer.blocking_events
			grounded = true
			entry_speed = 0.0
			# Seed only the starting speed; all braking, steering and movement use inputs.
			car.velocity = -car.global_basis.z * (80.0 / 3.6)
			var approach: Array[Vector3] = []
			for distance in [65.0, 40.0, 20.0]:
				approach.append(Layout.point(stop.z - direction * distance, lane))
			var road_x: float = Layout.center_x(stop.z) + lane
			var turn_start := Vector3(road_x, 0.36, stop.z - direction * 8.0)
			approach.append(turn_start)
			var arrived := await _follow(car, approach, 80.0 / 3.6, turn_start)
			entry_speed = absf(car.drive_speed) * 3.6
			var turn: Array[Vector3] = []
			for step in range(1, 9):
				var angle := PI / 2 * step / 8.0
				turn.append(Vector3(road_x + stop.side * 8.0 * (1.0 - cos(angle)), 0.36, turn_start.z + direction * 8.0 * sin(angle)))
			turn.append(Vector3(stop.x, 0.36, stop.z))
			arrived = await _follow(car, turn, 16.0 / 3.6) and arrived
			_release()
			Input.action_press("handbrake")
			await _frames(120)
			var stop_position := car.position
			var label: String = stop.name + (" returning" if returning else " outward")
			_check(arrived and entry_speed <= 28.0 and car.velocity.length() < 0.6 and Vector2(car.position.x - stop.x, car.position.z - stop.z).length() < 3.0, label + " brakes from 80 km/h, turns into the entrance and stops")
			_check(grounded and streamer.blocking_events == holds, label + " maintains ground support throughout the approach and turn")
			_release()
			# Leave by driving forward along a loop in the existing open apron,
			# then turn back into the lane; do not reset heading inside the stop.
			var exit_path: Array[Vector3] = []
			for step in range(1, 17):
				var angle := PI * step / 16.0
				exit_path.append(Vector3(stop.x + stop.side * 4.0 * sin(angle), 0.36, stop.z + direction * 4.0 * (1.0 - cos(angle))))
			exit_path.append(Vector3(road_x + stop.side * 8.0, 0.36, stop.z + direction * 8.0))
			for step in range(1, 9):
				var angle := PI / 2 * step / 8.0
				exit_path.append(Vector3(road_x + stop.side * 8.0 * cos(angle), 0.36, stop.z + direction * 8.0 * (1.0 + sin(angle))))
			exit_path.append(Layout.point(stop.z + direction * 30.0, lane))
			var exited := await _follow(car, exit_path, 12.0 / 3.6)
			print("Maneuver %s: turn entry %.1f km/h, stopped at %s, exit %s" % [label, entry_speed, stop_position, car.position])
			_check(exited and grounded and streamer.blocking_events == holds, label + " returns to its travel lane using vehicle inputs")
			_release()
	_check(streamer.failure_count == 0 and streamer.peak_resident_cells <= 3, "six stop maneuvers preserve bounded streaming without load failures")
	world.queue_free()
	await _frames(5)
	OS.delay_msec(150)
	await _frames(5)
	await create_timer(0.2).timeout
	print("Stop maneuver smoke test: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _follow(car: PlayerCar, points: Array[Vector3], speed: float, braking_target: Vector3 = Vector3.INF) -> bool:
	var path: Array[Vector3] = [car.position]
	path.append_array(points)
	var index := 1
	for frame in 6000:
		var destination: Vector3 = path.back()
		if Vector2(car.position.x - destination.x, car.position.z - destination.z).length() < 0.9:
			_release()
			return true
		var segment := path[index] - path[index - 1]
		segment.y = 0
		var offset := car.position - path[index - 1]
		offset.y = 0
		var along := offset.dot(segment) / segment.length_squared()
		if along >= 1.0 and index < path.size() - 1:
			index += 1
			continue
		var closest := path[index - 1].lerp(path[index], clampf(along, 0.0, 1.0))
		if Vector2(car.position.x - closest.x, car.position.z - closest.z).length() > 3.0:
			break
		# Pursue a point ahead along the polyline, rather than steering back to
		# each tiny arc waypoint once it has passed behind the front bumper.
		var target := closest
		var remaining := 3.0
		for next in range(index, path.size()):
			var distance := target.distance_to(path[next])
			if distance >= remaining:
				target = target.lerp(path[next], remaining / distance)
				break
			target = path[next]
			remaining -= distance
		_release()
		var to_target := target - car.position
		var heading := atan2(-to_target.x, -to_target.z)
		var angle := angle_difference(car.get_heading(), heading)
		var wheel_angle := atan(2.0 * car.wheelbase * sin(angle) / maxf(Vector2(to_target.x, to_target.z).length(), 0.5))
		var limit := deg_to_rad(lerpf(car.low_speed_steering_degrees, car.high_speed_steering_degrees, clampf(absf(car.drive_speed) / car.forward_speed, 0.0, 1.0)))
		var steering := clampf(-wheel_angle / limit, -1.0, 1.0)
		Input.action_press("steer_left" if steering < 0 else "steer_right", absf(steering))
		var target_speed := speed
		if braking_target.is_finite():
			var distance := Vector2(car.position.x - braking_target.x, car.position.z - braking_target.z).length()
			target_speed = minf(speed, sqrt(pow(22.0 / 3.6, 2) + 2.0 * 5.0 * maxf(0.0, distance - 3.0)))
		Input.action_press("accelerate" if car.drive_speed < target_speed else "brake", 0.65)
		await _frames(1)
		grounded = grounded and car.is_on_floor()
	print("Maneuver missed destination %s from %s, speed %.1f km/h" % [path.back(), car.position, car.drive_speed * 3.6])
	_release()
	return false


func _release() -> void:
	for action in DRIVE_ACTIONS:
		Input.action_release(action)
