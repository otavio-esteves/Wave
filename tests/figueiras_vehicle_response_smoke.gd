extends SceneTree

const FixtureInput = preload("fixture_input.gd")
const CAR = preload("res://scenes/cars/player_car.tscn")
const RoadChassis = preload("res://scripts/vehicle/road_chassis.gd")

var _world: Node3D
var _floor: StaticBody3D
var _car: PlayerCar
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputSetup.configure()
	FixtureInput.isolate()
	_world = Node3D.new()
	root.add_child(_world)
	_floor = StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(160.0, 0.5, 160.0)
	collider.shape = slab
	collider.position.y = -0.25
	_floor.add_child(collider)
	_world.add_child(_floor)
	_car = CAR.instantiate()
	_car.road_car_tuning = true
	_car.progressive_steering = true
	_car.position.y = 0.4
	_world.add_child(_car)
	_check_combined_force()
	await _braking_while_cornering()
	await _handbrake_recovery()
	await _brake_then_reverse()
	await _parking_on_grade()
	await _engine_overrun()
	await _corner_contact()
	_release()
	print("Figueiras vehicle response: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check_combined_force() -> void:
	var straight := _braking_force(Vector2(16.0, 0.0))
	var sideslip := _braking_force(Vector2(16.0, 3.3))
	print("Tire forces at saturated brake pressure: %.2f m/s² straight, %.2f m/s² while producing %.2f m/s² laterally" %
		[-straight.x, -sideslip.x, -sideslip.y])
	_check(sideslip.x > straight.x + 0.9 and sideslip.y < -4.0 and sideslip.length() < 10.4,
		"at a saturated contact patch cornering and braking share the same grip")


func _braking_force(motion: Vector2) -> Vector2:
	var chassis := RoadChassis.new()
	var force := Vector2.ZERO
	for step in 16:
		chassis.yaw_rate = 0.0
		force = chassis.step(motion, 0.0, -15.0, 1.0, false, 0.0, 8.0, Vector2.ZERO, 1.0 / 60.0)
	return force


func _braking_while_cornering() -> void:
	var straight := await _trail_brake(0.0)
	var turning := await _trail_brake(1.0)
	var partial := await _trail_brake(0.0, 0.45)
	print("Braking for 0.70 s from 57.6 km/h: %.2f km/h straight, %.2f km/h turning, %.2f km/h with 45%% brake; turn %.2f°" %
		[straight.x, turning.x, partial.x, rad_to_deg(turning.y)])
	_check(turning.x < 45.0 and turning.y > deg_to_rad(8.0) and straight.y < deg_to_rad(0.2),
		"the front wheels still steer under heavy braking")
	_check(partial.x > straight.x + 7.0 and partial.x < 53.0,
		"a partial analog pedal scrubs less speed than full pressure")


func _trail_brake(steering: float, pressure := 1.0) -> Vector2:
	await _place(16.0)
	Input.action_press("brake", pressure)
	Input.action_press("steer_right", steering)
	var limit := 0.0
	for step in 42:
		await physics_frame
		var usage := _car._road.wheel_usage
		limit = maxf(limit, maxf(maxf(usage.x, usage.y), maxf(usage.z, usage.w)))
	if steering > 0.0:
		_check(limit <= 1.0001 and limit > 0.96, "the corner reaches the tire force limit without exceeding it")
	return Vector2(_car.get_speed_kmh(), absf(_car.get_heading()))


func _handbrake_recovery() -> void:
	await _place(14.0)
	Input.action_press("steer_right", 0.85)
	Input.action_press("handbrake")
	await _frames(31)
	var spin := _car._road.wheel_spin
	var slip_at_release := absf(_car.lateral_speed + _car.get_turn_rate() * _car.wheelbase * 0.5)
	var speed_at_release := _car.get_speed_kmh()
	_check(absf(spin.z) < 0.1 and absf(spin.w) < 0.1 and minf(spin.x, spin.y) > 6.0,
		"the rear wheels stop rolling with the lever held and the front wheels still roll")
	_check(speed_at_release < 48.0 and slip_at_release > 1.0,
		"a handbrake turn scrubs speed while the rear of the car travels sideways")
	_release()
	await _frames(62)
	print("Handbrake at 50.4 km/h: %.2f km/h and %.2f m/s rear-axle sideslip at release; %.2f m/s body sideslip after 1 s" %
		[speed_at_release, slip_at_release, absf(_car.lateral_speed)])
	_check(absf(_car.lateral_speed) < 0.5 and absf(_car.get_turn_rate()) < 0.2 and _car.drive_speed > 7.0,
		"releasing the lever restores rear grip and settles the car while it moves forward")


func _brake_then_reverse() -> void:
	await _place(4.0)
	Input.action_press("brake")
	var stopped_at := -1
	var reversed_at := -1
	for step in 100:
		await physics_frame
		if absf(_car.drive_speed) < 0.12 and stopped_at < 0:
			stopped_at = step
		if _car.drive_speed < -0.15:
			reversed_at = step
			break
	print("Brake/reverse transition: first stop at tick %d, reverse motion at tick %d" % [stopped_at, reversed_at])
	_check(stopped_at > 8 and reversed_at - stopped_at >= 13,
		"holding the reverse pedal brakes into a complete stop before engaging reverse")


func _parking_on_grade() -> void:
	_floor.rotation.x = -atan(0.15)
	await _place(0.0)
	var start := _car.global_position
	Input.action_press("handbrake")
	await _frames(90)
	_check(start.distance_to(_car.global_position) < 0.1 and _car.get_speed_kmh() < 0.3,
		"the lever holds the car on a 15 percent grade")
	Input.action_release("handbrake")
	await _frames(72)
	_check(start.distance_to(_car.global_position) > 0.36 and _car.get_speed_kmh() > 1.3,
		"releasing the lever lets gravity roll the car on the grade")
	_floor.rotation.x = 0.0


func _engine_overrun() -> void:
	await _place(15.0)
	await _frames(75)
	var lost := 15.0 - _car.drive_speed
	print("Coasting from 54.0 km/h on flat asphalt: %.2f m/s lost in 1.25 s" % lost)
	_check(lost > 1.25 and lost < 2.3 and _car.gearbox.engine_drag(0.0) == 0.0,
		"engine overrun slows a rolling Gol without dragging the engine at a standstill")


func _corner_contact() -> void:
	var right := _wall(Vector3(3.16, 0.72, 0.0), Vector3(0.14, 1.6, 10.0))
	var front := _wall(Vector3(0.0, 0.72, -3.16), Vector3(10.0, 1.6, 0.14))
	await _place(0.0)
	var hits: Array[float] = []
	var collect := func(strength: float) -> void: hits.append(strength)
	_car.impact.connect(collect)
	_car.global_basis = Basis(Vector3.UP, -PI * 0.25)
	_car.velocity = -_car.global_basis.z * 23.0
	await _frames(22)
	var p := _car.global_position
	print("Corner at 82.8 km/h: position %s, %.2f km/h remaining, %d impacts" % [p, _car.get_speed_kmh(), hits.size()])
	_check(p.x < 2.15 and p.z > -2.15 and _car.get_speed_kmh() < 6.0,
		"a diagonal approach into two thin walls dissipates forward speed within the corner")
	_check(hits.size() >= 1 and hits.size() <= 2,
		"the corner emits the contact onset without counting every sliding substep")
	_car.impact.disconnect(collect)
	right.queue_free()
	front.queue_free()


func _wall(site: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.position = site
	body.add_child(collider)
	_world.add_child(body)
	return body


func _place(speed: float) -> void:
	_release()
	_car.reset_car()
	await _frames(16)
	_car.velocity = -_car.global_basis.z * speed


func _release() -> void:
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for step in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)
