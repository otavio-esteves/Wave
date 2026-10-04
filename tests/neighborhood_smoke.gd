extends SceneTree

const CITY := "res://scenes/city/drive_neighborhood.tscn"
const Builder = preload("res://scripts/city/neighborhood_builder.gd")
const TRACK := "res://scenes/test_track.tscn"
const GeometryValidation = preload("res://scripts/city/neighborhood_validation.gd")

var world: DrivingWorld
var car: PlayerCar
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = load(CITY).instantiate()
	root.add_child(world)
	current_scene = world
	car = world.get_node("PlayerCar")
	await _frames(10)
	_check(car.is_on_floor() and car.velocity.length() < 0.1, "neighborhood spawn is clear and grounded")
	_check("BAIRRO DO SOL" in world.get_node("HUD/Overlay/Controls").text, "HUD identifies the current world")
	await _check_render_data()
	_report_geometry()
	var input_count := InputMap.action_get_events("accelerate").size()

	for center in [-70.0, 0.0, 70.0]:
		await _prepare(Vector3(center + 3.5, 0.36, 83.0), 0.0)
		Input.action_press("accelerate")
		await _frames(1260)
		_check(car.global_position.z < -82.0 and absf(car.global_position.x - center - 3.5) < 0.1 and car.is_on_floor(), "north-south street %s is continuous through intersections" % center)
		await _prepare(Vector3(-83.0, 0.36, center + 3.5), -PI * 0.5)
		Input.action_press("accelerate")
		await _frames(1260)
		_check(car.global_position.x > 82.0 and absf(car.global_position.z - center - 3.5) < 0.1 and car.is_on_floor(), "east-west street %s is continuous through intersections" % center)

	for center in [-210.0, 210.0]:
		await _prepare(Vector3(center + 3.5, 0.36, 231.0), 0.0)
		Input.action_press("accelerate")
		await _frames(3510)
		_check(car.global_position.z < -230.0 and car.is_on_floor(), "expanded outer north-south street %s spans 460 m" % center)
		await _prepare(Vector3(-231.0, 0.36, center + 3.5), -PI * 0.5)
		Input.action_press("accelerate")
		await _frames(3510)
		_check(car.global_position.x > 230.0 and car.is_on_floor(), "expanded outer east-west street %s spans 460 m" % center)

	await _prepare(Vector3(0.0, 0.36, 30.0), -PI * 0.5)
	Input.action_press("accelerate")
	await _frames(330)
	_check(car.global_position.x > 43.0 and car.is_on_floor(), "driveway admits the car without a curb blocking access")

	await _prepare(Vector3(47.0, 0.36, 34.0), 0.0)
	Input.action_press("accelerate")
	await _frames(180)
	_check(car.global_position.z > 25.5 and absf(car.drive_speed) < 0.3, "garage facade blocks the car")

	await _prepare(Vector3(3.5, 0.36, Builder.LIMIT - 11.0), PI)
	Input.action_press("accelerate")
	await _frames(180)
	_check(car.global_position.z < Builder.LIMIT - 3.8 and absf(car.drive_speed) < 0.3, "road-end barrier prevents leaving the neighborhood")
	Input.action_release("accelerate")
	car.reset_car()
	await _frames(3)
	_check(car.global_position.distance_to(car.spawn_transform.origin) < 0.1, "reset returns to the neighborhood spawn")

	await _tap_key(KEY_F3)
	_check(world.get_node("HUD/Overlay/Diagnostics").visible, "F3 displays performance diagnostics")
	await _tap_key(KEY_F3)
	_check(not world.get_node("HUD/Overlay/Diagnostics").visible, "F3 hides performance diagnostics")

	world.get_node("HUD").set_paused(true)
	world.get_node("HUD/Overlay/PauseMenu/Center/Buttons/World").pressed.emit()
	await _wait_for_scene(TRACK)
	_check(current_scene != null and current_scene.scene_file_path == TRACK, "pause menu changes from neighborhood to test track")
	if current_scene != null and current_scene.scene_file_path == TRACK:
		current_scene.get_node("HUD").set_paused(true)
		current_scene.get_node("HUD/Overlay/PauseMenu/Center/Buttons/World").pressed.emit()
		await _wait_for_scene(CITY)
	_check(current_scene != null and current_scene.scene_file_path == CITY, "pause menu returns to the neighborhood")
	_check(not paused, "world transitions restore active gameplay")
	_check(InputMap.action_get_events("accelerate").size() == input_count, "world transitions do not duplicate input bindings")

	print("Neighborhood smoke test: %d checks, %d failures" % [checks, failures])
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	# Allow the audio thread to complete its stop fade in wall time.
	OS.delay_msec(100)
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)


func _prepare(position: Vector3, heading: float) -> void:
	Input.action_release("accelerate")
	car.reset_car()
	# Keep route checks at 8 m/s without coupling them to pedal semantics.
	car.forward_speed = 8.0
	car.global_position = position
	car.rotation.y = heading
	world.get_node("ChaseCamera").snap_to_target()
	await _frames(5)
	car.velocity = -car.global_basis.z * 8.0


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _tap_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _wait_for_scene(path: String) -> void:
	for frame in range(20):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return


func _report_geometry() -> void:
	var batches := world.get_node("NeighborhoodMap").find_children("*", "MultiMeshInstance3D", true, false)
	var instances: int = 0
	var triangles: int = 0
	for batch: MultiMeshInstance3D in batches:
		instances += batch.multimesh.instance_count
		triangles += int(batch.multimesh.mesh.get_faces().size() / 3) * batch.multimesh.instance_count
	print("Map geometry: %d batches, %d primitive instances, %d triangles (excluding text, car, shadows)" % [batches.size(), instances, triangles])


func _check_render_data() -> void:
	var map: Node3D = world.get_node("NeighborhoodMap")
	var problems: PackedStringArray = GeometryValidation.validate(map)
	_check(problems.is_empty(), "serialized render geometry matches the floor and buildings: %s" % "; ".join(problems))
	var colliders: Node3D = map.get_node("CityColliders")
	colliders.position.x += 30.0
	_check(not GeometryValidation.validate(map).is_empty(), "validation detects collision parent displaced from visible geometry")
	colliders.position.x -= 30.0
	var original_transform := map.transform
	map.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(20, 0, 10))
	_check(GeometryValidation.validate(map).is_empty(), "validation accepts a shared world transform for geometry and colliders")
	map.transform = original_transform
	var packed := PackedScene.new()
	var error := packed.pack(map)
	var path := "user://neighborhood-render-roundtrip.tscn"
	if error == OK:
		error = ResourceSaver.save(packed, path)
	var survived := false
	if error == OK:
		var saved := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if saved != null:
			var reloaded := saved.instantiate() as Node3D
			survived = GeometryValidation.validate(reloaded).is_empty()
			reloaded.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(survived, "saving and reloading the map preserves all render placements")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
