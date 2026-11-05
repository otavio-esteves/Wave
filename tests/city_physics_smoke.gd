extends SceneTree

var failures := 0
var checks := 0

class ScriptedCollider:
	extends CollisionShape3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputSetup.configure()
	_compaction_contract()
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
	preload("res://scripts/city/pilot_city_physics.gd").prepare(city, car.position)
	_check(city.get_node("Solids_8_0").process_mode == Node.PROCESS_MODE_DISABLED and city.get_node("Solids_0_0").process_mode == Node.PROCESS_MODE_INHERIT, "distant solids are disabled before the city first enters a physics space")
	_check(city.get_node("Solids_0_0").get_child_count() == 0 and city.get_meta("authored_solid_shape_count") == 2, "static solids retain native collision data without individual scene nodes")
	var compact: StaticBody3D = city.get_node("Solids_0_0")
	var owner_id: int = compact.get_shape_owners()[0]
	_check(compact.shape_owner_get_transform(owner_id).origin == Vector3(30, 1, 30) and compact.shape_owner_get_shape(owner_id, 0).size == Vector3(2, 2, 2), "compaction preserves the authored solid shape dimensions and transform")
	root.add_child(world)
	car.set_physics_process(false)
	var physics := preload("res://scripts/city/pilot_city_physics.gd").new()
	world.add_child(physics)
	await _frames()
	_check(_hit(world, Vector3(30, 1, 30)) and not _hit(world, Vector3(1030, 1, 30)), "near solids collide while distant solids leave the broad phase")
	_check(physics.active_shapes == 1 and physics.total_shapes == 2, "physics residency counts only the active solid shapes")
	paused = true
	await process_frame
	paused = false
	await _frames()
	_check(_hit(world, Vector3(30, 1, 30)) and not _hit(world, Vector3(1030, 1, 30)), "pause and resume cannot reactivate disabled distant solids")
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


func _compaction_contract() -> void:
	var city := Node3D.new()
	var body := StaticBody3D.new()
	body.name = "Solids_-3_2"
	city.add_child(body)
	var plain := CollisionShape3D.new()
	plain.shape = BoxShape3D.new()
	plain.shape.size = Vector3(3, 5, 7)
	plain.transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(-320, 2, 320))
	plain.disabled = true
	var shape := plain.shape
	var placement := plain.transform
	body.add_child(plain)
	var scripted := ScriptedCollider.new()
	scripted.shape = BoxShape3D.new()
	body.add_child(scripted)
	var physics = preload("res://scripts/city/pilot_city_physics.gd")
	physics.prepare(city, Vector3(-320, 0, 320))
	var native_id := -1
	for id in body.get_shape_owners():
		if body.shape_owner_get_owner(id) == body:
			native_id = id
	_check(native_id >= 0 and body.shape_owner_get_shape(native_id, 0) == shape and body.shape_owner_get_transform(native_id).is_equal_approx(placement), "native compaction retains rotated negative-coordinate transforms and the original shape resource")
	_check(native_id >= 0 and body.is_shape_owner_disabled(native_id), "disabled authored solids remain disabled after native compaction")
	_check(body.get_child_count() == 1 and scripted.get_parent() == body, "colliders with runtime scripts retain their original nodes")
	physics.prepare(city, Vector3(-320, 0, 320))
	_check(physics.shape_count(body) == 2 and city.get_meta("authored_solid_shape_count") == 2, "repeating preparation cannot duplicate native shape owners")
	city.free()


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
