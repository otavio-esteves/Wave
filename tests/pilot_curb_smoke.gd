extends SceneTree

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var checks := 0
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("WaveSettings").set_graphics_preset("economy")
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	var car: PlayerCar = current_scene.get_node("PlayerCar")
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake"]:
		InputMap.action_erase_events(action)
	for edge in _edges([[87, 88], [113, 114], [119, 120], [120, 141]]):
		for side in [-1.0, 1.0]:
			await _cross(car, edge, side, false, false, 1.2)
			await _cross(car, edge, side, true, true, 2.5)
	# Compare speed retention at normal urban speed on the steep and curved edges.
	for edge in _edges([[87, 88], [120, 141]]):
		await _cross(car, edge, 1.0, false, false, 10.0)
	var file := FileAccess.open("user://pilot-curb-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "routes": results}, "\t"))
	current_scene.queue_free()
	await _frames(3)
	print("Pilot curb: %d checks, %d failures; %s" % [checks, failures, OS.get_user_data_dir()])
	quit.call_deferred(0 if failures == 0 else 1)

func _cross(car: PlayerCar, edge: Dictionary, side: float, returning: bool, reverse: bool, speed: float) -> void:
	var points := Layout.edge_points(edge.a, edge.b)
	var index := floori(points.size() * 0.3)
	var center := points[index]
	var tangent := (points[index + 1] - points[index - 1]).normalized()
	tangent.y = 0
	tangent = tangent.normalized()
	var right := tangent.cross(Vector3.UP) * side
	var start: Vector3 = center + right * (edge.width * 0.5 - 2.2 if not returning else edge.width * 0.5 + 5.5)
	var end: Vector3 = center + right * (edge.width * 0.5 + 5.5 if not returning else edge.width * 0.5 - 2.2)
	if reverse:
		end += tangent * 2.2 # Rear-first diagonal across the curb and its outer edge.
	var direction := (end - start).normalized()
	var body_forward := -direction if reverse else direction
	car.reset_car()
	car.position = Vector3(start.x, Layout.height_at(start.x, start.z) + 0.4, start.z)
	car.rotation = Vector3(0, atan2(-body_forward.x, -body_forward.z), 0)
	car.forward_speed = speed
	car.reverse_speed = speed
	await _frames(12)
	car.velocity = direction * speed
	var arrived := false
	var stalled := 0
	var air := 0
	var max_clearance := 0.0
	var lowest_speed := speed
	var previous_clearance := car.position.y - Layout.height_at(car.position.x, car.position.z)
	var max_jump := 0.0
	for frame in 1200:
		Input.action_press("brake" if reverse else "accelerate", 0.65)
		await _frames(1)
		var progress := (car.position - start).dot(direction)
		var clearance := car.position.y - Layout.height_at(car.position.x, car.position.z)
		max_clearance = maxf(max_clearance, clearance)
		max_jump = maxf(max_jump, absf(clearance - previous_clearance))
		previous_clearance = clearance
		air += 0 if car.is_on_floor() else 1
		if progress > 0.8:
			var actual := Vector2(car.velocity.x, car.velocity.z).length()
			lowest_speed = minf(lowest_speed, actual)
			stalled += 1 if actual < speed * 0.25 else 0
		if progress >= start.distance_to(end):
			arrived = true
			break
		if stalled > 90:
			break
	Input.action_release("accelerate")
	Input.action_release("brake")
	var result := {"edge": "%d-%d" % [edge.a, edge.b], "side": side, "returning": returning, "reverse": reverse, "speed": speed, "arrived": arrived, "stalled_frames": stalled, "air_frames": air, "max_clearance": max_clearance, "max_height_jump": max_jump, "minimum_speed": lowest_speed, "end": str(car.position)}
	results.append(result)
	print("Curb result: ", result)
	_check(arrived and stalled < 10, "actual curved hillside sidewalk traverses without catching: %s side %s reverse %s speed %s" % [result.edge, side, reverse, speed])
	_check(max_clearance < 0.7 and air < 10, "sidewalk transition preserves support without launching the vehicle")
	_check(max_jump < 0.045, "sidewalk contact changes height progressively rather than stepping the body upward")
	if speed >= 10:
		_check(lowest_speed > speed * 0.7, "urban-speed crossing retains at least seventy percent of approach speed")

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _edges(pairs: Array) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for pair in pairs:
		for edge in Layout.edges():
			if edge.a == pair[0] and edge.b == pair[1]:
				selected.append(edge)
	return selected
