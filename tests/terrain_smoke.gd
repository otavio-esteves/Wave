extends SceneTree

var world: Node3D
var car: PlayerCar
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	InputSetup.configure()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	_solid(Vector3(0, -0.3, 0), Vector3(120, 0.6, 120))
	_solid(Vector3(-25, 1.39, 0), Vector3(12, 0.4, 20), Vector3(0.16, 0, 0))
	_solid(Vector3(25, 1.2, 0), Vector3(12, 0.4, 20), Vector3(0, 0, 0.18))
	_solid(Vector3(0, 0.06, -7), Vector3(10, 0.12, 3))
	_solid(Vector3(0, 0.75, -23), Vector3(10, 1.5, 2))
	car = load("res://scenes/cars/player_car.tscn").instantiate()
	car.position = Vector3(-25, 0.36, 15)
	world.add_child(car)
	await _frames(10)
	Input.action_press("accelerate", 0.5)
	await _frames(125)
	_check(car.position.y > 1.0 and car.position.z < 5.0, "four-wheel car ascends a continuous ramp")
	var ramp_up := Basis.from_euler(Vector3(0.16, 0, 0)) * Vector3.UP
	_check(car.global_basis.y.angle_to(ramp_up) < deg_to_rad(2.0), "body and collider follow ramp pitch within two degrees")
	_check(car.is_on_floor(), "ascending car retains road contact")
	_release()
	var z_before := car.position.z
	car.velocity = car.global_basis.z * 5.0
	Input.action_press("brake")
	await _frames(35)
	_check(car.position.z > z_before + 2.0, "reverse descends the ramp along its plane")
	_check(car.global_basis.y.angle_to(ramp_up) < deg_to_rad(3.0), "reverse preserves terrain alignment")
	_release()
	car.reset_car()
	car.position = Vector3(25, 2.0, 0)
	await _frames(70)
	var bank_up := Basis.from_euler(Vector3(0, 0, 0.18)) * Vector3.UP
	_check(car.is_on_floor() and car.global_basis.y.angle_to(bank_up) < deg_to_rad(2.0), "cross slope tilts both the car and collider")
	var front := car.get_node("Visuals/FrontLeft") as Node3D
	_check(absf(front.position.y + 0.04) <= car.suspension_travel + 0.001, "suspension remains within travel limits")
	car.reset_car()
	car.position = Vector3(0, 0.36, 1)
	await _frames(10)
	car.forward_speed = 5.0
	Input.action_press("accelerate")
	var highest := 0.0
	for frame in 210:
		await _frames(1)
		highest = maxf(highest, car.position.y)
	_check(car.position.z < -11.0 and car.is_on_floor(), "car crosses and descends a 12 cm curb")
	_check(highest > 0.45 and highest < 0.9, "curb traversal raises the car without launching it")
	await _frames(180)
	_check(car.position.z > -20.4 and absf(car.drive_speed) < 0.3, "step traversal cannot climb a tall barrier")
	_release()
	car.reset_car()
	car.position = Vector3(0, 4, 15)
	await _frames(2)
	car.velocity = Vector3(3, 2, -5)
	var airborne_heading := car.get_heading()
	Input.action_press("steer_right")
	await _frames(12)
	_check(absf(car.velocity.x - 3.0) < 0.01 and absf(car.velocity.z + 5.0) < 0.01, "airborne car preserves horizontal launch momentum")
	_check(absf(car.get_heading() - airborne_heading) < 0.001 and car.velocity.y < 0.0, "airborne steering cannot rotate the car and gravity acts")
	_release()
	car.reset_car()
	_check(car.global_basis.is_equal_approx(car.spawn_transform.basis) and car.velocity == Vector3.ZERO, "reset clears terrain orientation and momentum")
	print("Terrain smoke test: %d checks, %d failures" % [checks, failures])
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _solid(position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = position
	body.rotation = rotation
	world.add_child(body)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _release() -> void:
	for action in ["accelerate", "brake", "steer_left", "steer_right"]:
		Input.action_release(action)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
