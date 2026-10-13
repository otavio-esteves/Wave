extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputSetup.configure()
	var world := Node3D.new()
	var city := Node3D.new()
	city.name = "City"
	world.add_child(city)
	_solid(city, "Solids_0_0", Vector3(30, 1, 30), Vector3(2, 2, 2))
	_solid(city, "Solids_8_0", Vector3(1030, 1, 30), Vector3(2, 2, 2))
	_solid(city, "Support_0_0", Vector3(530, -0.5, 30), Vector3(1100, 1, 100))
	var car := preload("res://scenes/cars/player_car.tscn").instantiate() as PlayerCar
	car.name = "PlayerCar"
	car.position = Vector3(0, 0.4, 0)
	world.add_child(car)
	root.add_child(world)
	car.set_physics_process(false)
	var physics := preload("res://scripts/city/pilot_city_physics.gd").new()
	world.add_child(physics)
	await _frames()
	_check(_hit(world, Vector3(30, 1, 30)) and not _hit(world, Vector3(1030, 1, 30)), "near solids collide while distant solids leave the broad phase")
	_check(physics.active_shapes == 1 and physics.total_shapes == 2, "physics residency counts only the active solid shapes")
	car.position.x = 1000
	physics.refresh()
	await _frames()
	_check(not _hit(world, Vector3(30, 1, 30)) and _hit(world, Vector3(1030, 1, 30)), "moving across districts restores destination collisions and releases old ones")
	car.reset_car()
	car.set_physics_process(false)
	await _frames()
	_check(_hit(world, Vector3(30, 1, 30)) and not _hit(world, Vector3(1030, 1, 30)), "reset restores collision residency before driving resumes")
	car.position.x = 500
	physics.refresh()
	await _frames()
	_check(_hit(world, Vector3(30, 1, 30)), "retention margin prevents collision churn at the entry radius")
	car.position.x = 650
	physics.refresh()
	await _frames()
	_check(not _hit(world, Vector3(30, 1, 30)) and not _hit(world, Vector3(1030, 1, 30)), "old solids release beyond the retention radius before the next tile enters")
	car.position.x = 690
	physics.refresh()
	await _frames()
	_check(_hit(world, Vector3(1030, 1, 30)), "next solid tile activates within the entry radius")
	var query := PhysicsRayQueryParameters3D.create(Vector3(1030, 0.4, 20), Vector3(1030, -2, 20))
	_check(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "physical floor remains active even far from the player")
	world.queue_free()
	await process_frame
	print("City physics: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _solid(city: Node3D, name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	var shape := CollisionShape3D.new()
	shape.position = position
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	city.add_child(body)


func _hit(world: Node3D, position: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 3, position - Vector3.UP * 0.25)
	return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _frames() -> void:
	for index in 3:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)
