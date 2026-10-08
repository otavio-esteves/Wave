extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputSetup.configure()
	for height in [0.12, 0.20, 0.28, 0.30]:
		for heading in [0.0, -PI / 6, PI]:
			await _curb(height, heading)
	await _curb(0.28, 0.0, true)
	await _curb(0.28, 0.0, false, 18.0)
	await _curb(0.28, -PI / 6, false, 18.0)
	await _hill()
	print("Ground navigation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _curb(height: float, heading: float, simulation: bool = false, speed: float = 1.2) -> void:
	var world := Node3D.new()
	root.add_child(world)
	_box(world, Vector3(0, -0.3, 0), Vector3(80, 0.6, 100))
	# Adjacent raised sidewalk sections, matching real street geometry.
	for z in [-6.0, -10.0, -14.0]:
		_box(world, Vector3(0, height / 2, z), Vector3(20, height, 4))
	var car = load("res://scenes/cars/player_car.tscn").instantiate()
	_apply_diagnostic_script(car)
	car.simulation_handling = simulation
	car.position = Vector3(0, 0.36, 1 if heading != PI else -21)
	car.rotation.y = heading
	car.forward_speed = speed
	car.reverse_speed = 1.2
	world.add_child(car)
	await _frames(12)
	if speed > 1.2:
		car.velocity = -car.global_basis.z * speed
	Input.action_press("brake" if heading == PI else "accelerate", 0.6)
	# Reverse uses the original heading, approaching the curb rear first.
	if heading == PI:
		car.rotation.y = 0
	var arrived := false
	var peak := 0.0
	var minimum_speed := speed
	for frame in 1700:
		await _frames(1)
		peak = maxf(peak, car.position.y)
		if speed > 1.2 and car.position.z < -3 and car.position.z > -17:
			minimum_speed = minf(minimum_speed, Vector2(car.velocity.x, car.velocity.z).length())
		if (heading == PI and car.position.z > -2) or (heading != PI and car.position.z < -19):
			arrived = true
			break
	_release()
	_check(arrived, "%.0f cm sidewalk at heading %.0f, simulation=%s crosses every seam and exits at %.1f m/s; end=%s" % [height * 100, rad_to_deg(heading), simulation, speed, car.position])
	_check(peak < height + 0.65, "sidewalk traversal does not launch the body")
	if speed > 1.2:
		_check(arrived and minimum_speed > speed * 0.7, "sidewalk crossing preserves speed; minimum=%.2f m/s" % minimum_speed)
	world.queue_free()
	await _frames(3)


func _hill() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var body := StaticBody3D.new()
	var floor := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	for index in 200:
		var z0 := -float(index * 4)
		var z1 := z0 - 4
		var a := Vector3(-40, _height(z0), z0)
		var b := Vector3(40, a.y, z0)
		var c := Vector3(-40, _height(z1), z1)
		var d := Vector3(40, c.y, z1)
		faces.append_array(PackedVector3Array([a, c, b, b, c, d]))
	shape.set_faces(faces)
	floor.shape = shape
	body.add_child(floor)
	world.add_child(body)
	var car = load("res://scenes/cars/player_car.tscn").instantiate()
	_apply_diagnostic_script(car)
	car.position = Vector3(0, 0.36, -12)
	world.add_child(car)
	await _frames(12)
	var arrived := false
	var stalled := 0
	for frame in 6500:
		Input.action_release("accelerate")
		Input.action_release("brake")
		Input.action_press("accelerate" if car.drive_speed < 18 else "brake", 0.6)
		await _frames(1)
		if car.position.z < -100 and absf(car.drive_speed) < 0.2:
			stalled += 1
		if car.position.z < -600:
			arrived = true
			break
	_release()
	_check(arrived and stalled < 10, "coarse continuous hill climbs and descends without catching; end=%s stalled=%d" % [car.position, stalled])
	world.queue_free()
	await _frames(3)


func _height(z: float) -> float:
	return 9 * (1 - cos(TAU * (-z - 100) / 400)) if z < -100 and z > -500 else 0.0


func _apply_diagnostic_script(car: Node) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--car-script="):
			car.set_script(load(argument.trim_prefix("--car-script=")))


func _box(world: Node3D, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var floor := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	floor.shape = shape
	body.position = position
	body.add_child(floor)
	world.add_child(body)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release() -> void:
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
