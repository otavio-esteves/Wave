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
	_solid(Vector3(0, -0.3, 0), Vector3(600, 0.6, 600))
	_solid(Vector3(0, 0.12, -7), Vector3(20, 0.24, 4))
	_solid(Vector3(0, 0.5, -22), Vector3(20, 1, 2))
	_solid(Vector3(40, 2.0, 0), Vector3(16, 0.4, 24), Vector3(0.30, 0, 0))
	_solid(Vector3(100, 0.03, 100), Vector3(50, 0.06, 100), Vector3.ZERO, 0.46)
	for simulation in [false, true]:
		car = load("res://scenes/cars/player_car.tscn").instantiate()
		car.simulation_handling = simulation
		car.position = Vector3(0, 0.36, 1)
		world.add_child(car)
		await _frames(10)
		car.forward_speed = 2.0
		Input.action_press("accelerate", 0.4)
		await _frames(480)
		_check(car.position.z < -11 and car.is_on_floor(), "24 cm curb is traversable at walking speed")
		await _frames(600)
		_check(car.position.z > -19.5 and absf(car.drive_speed) < 0.3, "tall barriers still stop the vehicle")
		await _prepare(Vector3(0, 0.65, -7))
		car.velocity = Vector3(0, 0, 2)
		Input.action_press("brake")
		await _frames(330)
		_check(car.position.z > 0 and car.is_on_floor(), "curb descent in reverse preserves support")
		await _prepare(Vector3(-3, 0.36, 1))
		car.rotation.y = -PI / 6
		Input.action_press("accelerate", 0.5)
		await _frames(480)
		_check(car.position.z < -11 and car.is_on_floor(), "24 cm curb also works diagonally")
		await _prepare(Vector3(40, 2.7, 0))
		Input.action_press("handbrake")
		await _frames(60)
		var held := car.position
		await _frames(120)
		_check(car.position.distance_to(held) < 0.05, "parking brake holds a 17 degree hill")
		Input.action_release("handbrake")
		car.velocity = car.global_basis.z * 0.4
		car.forward_speed = 15
		Input.action_press("accelerate")
		await _frames(150)
		_check(car.drive_speed > 2 and car.position.z < held.z - 2, "motor launches uphill despite a small rollback")
		await _prepare(Vector3(-80, 0.36, 100))
		car.forward_speed = 40
		car.velocity = Vector3(0, 0, -20)
		Input.action_press("brake", 0.5)
		await _frames(60)
		var partial := car.drive_speed
		_check(partial > 13 and partial < 17, "half brake decelerates progressively without instant stopping")
		await _prepare(Vector3(-80, 0.36, 100))
		car.velocity = Vector3(0, 0, -20)
		Input.action_press("brake")
		await _frames(60)
		_check(car.drive_speed < partial - 3 and car.drive_speed > 7, "full brake is stronger and remains traction limited")
		_release()
		await _prepare(Vector3(-80, 0.36, 100))
		car.velocity = Vector3(4, 0, -18)
		Input.action_press("steer_right", 0.6)
		Input.action_press("handbrake")
		await _frames(30)
		_check(absf(car.lateral_speed) > 1, "handbrake develops a controllable sideways slide")
		_release()
		await _frames(240)
		_check(absf(car.lateral_speed) < 0.5 and car.velocity.is_finite(), "sliding recovers smoothly after the handbrake is released")
		await _prepare(Vector3(-80, 0.36, 100))
		car.forward_speed = 10
		Input.action_press("accelerate")
		await _frames(300)
		_check(car.drive_speed > 9.8 and car.drive_speed <= 10.05, "speed governor holds a low limit under sustained throttle")
		car.velocity = -car.global_basis.z * 20
		await _frames(60)
		_check(car.drive_speed > 17 and car.drive_speed < 20, "overspeed removes engine torque without abrupt automatic braking")
		await _prepare(Vector3(100, 0.42, 100))
		car.forward_speed = 40
		Input.action_press("accelerate")
		await _frames(60)
		_check(car.surface_friction < 0.5 and car.drive_speed > 1 and car.drive_speed < 4.6, "low grip limits engine traction in both handling profiles")
		await _prepare(Vector3(100, 0.42, 100))
		car.velocity = Vector3(0, 0, -20)
		Input.action_press("accelerate")
		Input.action_press("brake")
		await _frames(60)
		_check(car.drive_speed > 14 and car.drive_speed < 17, "pressing both pedals respects the low-grip braking limit")
		_release()
		car.queue_free()
		await process_frame
	print("Handling checks: %d passed / %d failed" % [checks - failures, failures])
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _prepare(position: Vector3) -> void:
	_release()
	car.reset_car()
	car.position = position
	await _frames(20)

func _solid(position: Vector3, size: Vector3, rotation := Vector3.ZERO, friction := 1.05) -> void:
	var body := StaticBody3D.new()
	body.set_meta("friction", friction)
	body.set_meta("surface", "grama" if friction < 0.5 else "asfalto")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	body.rotation = rotation
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
	var profile := "simulation" if car.simulation_handling else "arcade"
	if condition:
		print("PASS (%s): %s" % [profile, message])
	else:
		failures += 1
		push_error("FAIL (%s): %s [position=%s speed=%.3f]" % [profile, message, car.position, car.drive_speed])
