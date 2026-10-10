extends SceneTree

const Layout = preload("res://scripts/world/elevation_layout.gd")
const WORLD := "res://scenes/world/drive_elevation.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	Engine.max_fps = 240
	_run.call_deferred()


func _run() -> void:
	var road_speed := 30.0 if "--fast" in OS.get_cmdline_user_args() else 18.0
	var output := "user://elevation-regenerated"
	var error: Error = preload("res://scripts/world/elevation_builder.gd").new().build(output)
	_check(error == OK, "offline terrain regenerates into isolated user data")
	var grove_count := 0
	for index in Layout.CELL_COUNT:
		var saved: Node3D = load("res://scenes/world/cells/elevation/cell-%d.tscn" % index).instantiate()
		var rebuilt: Node3D = load("%s/cell-%d.tscn" % [output, index]).instantiate()
		_check(_geometry(saved) == _geometry(rebuilt), "cell %d preserves saved meshes, normals, UVs and collision on regeneration" % index)
		var grove: MultiMesh = saved.get_node("Groves").multimesh
		grove_count += grove.instance_transforms.size()
		saved.free()
		rebuilt.free()
	_check(grove_count > 0, "tree placements survive headless generation and loading of saved scenes")
	var horizon: Node3D = load("res://scenes/world/cells/elevation/horizon.tscn").instantiate()
	var rebuilt_horizon: Node3D = load(output + "/horizon.tscn").instantiate()
	_check(_geometry(horizon) == _geometry(rebuilt_horizon), "distant ridge meshes regenerate without introducing physics support")
	horizon.free()
	rebuilt_horizon.free()
	var visual_joins := true
	for index in range(1, Layout.CELL_COUNT):
		var previous: Node3D = load("res://scenes/world/cells/elevation/cell-%d.tscn" % (index - 1)).instantiate()
		var next: Node3D = load("res://scenes/world/cells/elevation/cell-%d.tscn" % index).instantiate()
		for label in ["Road", "ShoulderLeft", "ShoulderRight", "Paint-57", "Paint0", "Paint57"]:
			var before: Array = previous.get_node(label).mesh.surface_get_arrays(0)
			var after: Array = next.get_node(label).mesh.surface_get_arrays(0)
			for edge in [[-5, 0], [-1, 2]]:
				var endpoint: Vector3 = before[Mesh.ARRAY_VERTEX][edge[0]] + Vector3(0, 0, -200.0 * (index - 1))
				var startpoint: Vector3 = after[Mesh.ARRAY_VERTEX][edge[1]] + Vector3(0, 0, -200.0 * index)
				visual_joins = visual_joins and endpoint.distance_to(startpoint) < 0.0001 and before[Mesh.ARRAY_TEX_UV][edge[0]].distance_to(after[Mesh.ARRAY_TEX_UV][edge[1]]) < 0.0001
		previous.free()
		next.free()
	_check(visual_joins, "saved asphalt, shoulders and paint have matching positions and UVs at every cell join")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	current_scene.elevation_button.pressed.emit()
	await scene_changed
	_isolate_driver_input()
	_check(current_scene.scene_file_path == WORLD, "menu opens the isolated elevation lab")
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	await _support(streamer)
	await _frames(8)
	_check(car.is_on_floor() and not streamer.blocked, "spawn has registered physical support")
	var identities := [car.get_instance_id(), world.get_node("ChaseCamera").get_instance_id(), world.get_node("HUD").get_instance_id()]
	var holds := streamer.blocking_events
	var outward := await _drive(car, -740, false, 3.5, road_speed)
	_check(outward.arrived and outward.grounded and outward.max_height > 18 and outward.max_pitch > 0.10 and outward.max_offset < 1.5, "real steering inputs follow the bends while climbing and descending the 18 m hill")
	_check(streamer.blocking_events == holds and streamer.failure_count == 0, "normal outward trip needs no safety hold")
	_check(streamer.released_cells > 0 and streamer.current_cell == "elevation-3" and streamer.peak_resident_cells <= 3, "four-cell trip releases terrain under the three-cell cap")
	var seams := true
	for boundary in [-200.0, -400.0, -600.0]:
		world.teleport_to(Layout.point(boundary), Layout.heading(boundary))
		await _support(streamer)
		await _frames(5)
		for dz in [-0.01, 0.0, 0.01]:
			for offset in [-7.9, -5.5, 0.0, 5.5, 7.9]:
				var z: float = boundary + dz
				var x: float = Layout.center_x(z) + offset
				var top := Vector3(x, Layout.height(z) + 2.0, z)
				var query := PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 4, 1, [car.get_rid()])
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
				seams = seams and not hit.is_empty() and absf(hit.position.y - Layout.height(z)) < 0.005
	_check(seams, "all elevation joins have real support across road and shoulders")
	world.teleport_to(Layout.point(-740), PI)
	await _support(streamer)
	holds = streamer.blocking_events
	var returning := await _drive(car, -15, true, 3.5, road_speed)
	_check(returning.arrived and returning.grounded and returning.max_offset < 1.5 and streamer.blocking_events == holds, "return follows the curves and reloads the first cell without holds")
	# Drive an actual shoulder through the sloped join and the crest.
	world.teleport_to(Layout.point(-150, 7.0), Layout.heading(-150))
	await _support(streamer)
	await _frames(8)
	holds = streamer.blocking_events
	var shoulder := await _drive(car, -460, false, 7.0, 12.0)
	_check(shoulder.arrived and shoulder.grounded and shoulder.max_offset < 0.9 and streamer.blocking_events == holds, "right shoulder supports a real drive through bends, crest and two cell seams")
	world.teleport_to(Layout.point(-460, -7.0), Layout.heading(-460, true))
	await _support(streamer)
	await _frames(8)
	holds = streamer.blocking_events
	var left_shoulder := await _drive(car, -150, true, -7.0, 12.0)
	_check(left_shoulder.arrived and left_shoulder.grounded and left_shoulder.max_offset < 0.9 and streamer.blocking_events == holds, "left shoulder supports the opposite-direction drive through the hill")
	_check(identities == [car.get_instance_id(), world.get_node("ChaseCamera").get_instance_id(), world.get_node("HUD").get_instance_id()], "car, camera and HUD persist across terrain changes")
	car.reset_car()
	await _support(streamer)
	await _frames(6)
	_check(car.is_on_floor() and car.position.distance_to(car.spawn_transform.origin) < 0.1, "reset restores the flat spawn with real support")
	# A resident cell alone is insufficient: remove its actual support shape.
	world.teleport_to(Layout.point(-300), Layout.heading(-300))
	await _support(streamer)
	await _frames(5)
	var record: Dictionary = streamer.records[1]
	var floor := record.node.get_node("Colliders/Support") as CollisionShape3D
	var held := car.global_position
	floor.disabled = true
	await _frames(6)
	_check(streamer.blocked and not streamer.has_support(Layout.point(-300)) and car.global_position.distance_to(held) < 0.1, "missing physical collision freezes motion even when the cell is resident")
	floor.disabled = false
	await _support(streamer)
	await _frames(5)
	_check(not streamer.blocked and car.is_on_floor(), "restoring collision releases the safety hold")
	# A malformed serialized surface cannot be authorized by its bounds.
	var malformed: Node3D = load("res://scenes/world/cells/elevation/cell-1.tscn").instantiate()
	malformed.position = record.origin
	var shape := ConcavePolygonShape3D.new()
	var incomplete: PackedVector3Array = Layout.faces(-200)
	incomplete.resize(incomplete.size() - 3)
	shape.set_faces(incomplete)
	malformed.get_node("Colliders/Support").shape = shape
	_check(not streamer._valid_floor(malformed, record), "a missing terrain triangle is rejected before activation")
	malformed.free()
	# Destroy and reopen with delayed requests: hold on registered terrain until
	# every footprint corner at an elevated seam is available, then resume.
	change_scene_to_file(WORLD)
	await scene_changed
	world = current_scene
	car = world.get_node("PlayerCar")
	streamer = world.get_node("WorldStreamer")
	streamer.request_delay_frames = 40
	world.teleport_to(Layout.point(-400), Layout.heading(-400))
	held = car.global_position
	await _frames(12)
	_check(streamer.blocked and car.global_position == held and car.velocity == Vector3.ZERO, "delayed terrain load holds an elevated seam teleport")
	await _support(streamer)
	await _frames(8)
	_check(car.is_on_floor() and not streamer.blocked and streamer.failure_count == 0, "delayed seam releases only after both physical surfaces register")
	# Exercise the real activation failure path, not only the validator directly.
	var invalid: Node3D = load("res://scenes/world/cells/elevation/cell-0.tscn").instantiate()
	invalid.get_node("Colliders/Support").queue_free()
	await _frames(2)
	var packed := PackedScene.new()
	packed.pack(invalid)
	ResourceSaver.save(packed, "user://invalid-elevation.tscn")
	invalid.free()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/world/cells/elevation/manifest.json"))
	manifest.cells[0].scene = "user://invalid-elevation.tscn"
	var file := FileAccess.open("user://invalid-elevation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	world = load(WORLD).instantiate()
	world.get_node("WorldStreamer").manifest_file = "user://invalid-elevation.json"
	root.add_child(world)
	current_scene.queue_free()
	current_scene = world
	streamer = world.get_node("WorldStreamer")
	car = world.get_node("PlayerCar")
	held = car.position
	await _frames(100)
	_check(streamer.failure_count == 1 and streamer.records[0].state == "failed" and streamer.records[0].node == null and streamer.blocked and car.position == held, "invalid terrain fails activation and holds the car without attaching an unsafe cell")
	world.get_node("HUD").set_paused(true)
	world.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(8)
	_check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and not paused, "lab returns to menu and clears pause")
	current_scene.queue_free()
	await _frames(5)
	OS.delay_msec(150)
	await _frames(5)
	await create_timer(0.2).timeout
	print("Elevation smoke: %d checks, %d failures; target_kmh=%s outward=%s return=%s shoulder=%s left_shoulder=%s" % [checks, failures, road_speed * 3.6, outward, returning, shoulder, left_shoulder])
	quit(0 if failures == 0 else 1)


func _drive(car: PlayerCar, destination: float, returning: bool, lane_offset: float = 3.5, speed: float = 18.0) -> Dictionary:
	var arrived := false
	var grounded := true
	var max_height := 0.0
	var max_pitch := 0.0
	var max_offset := 0.0
	var air_frames := 0
	for frame in 6500:
		if (returning and car.position.z >= destination) or (not returning and car.position.z <= destination):
			arrived = true
			break
		Input.action_release("accelerate")
		Input.action_release("brake")
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		var look_ahead := maxf(12, speed * 0.65)
		var aim := Layout.point(car.position.z + (look_ahead if returning else -look_ahead), lane_offset) - car.position
		var desired_heading := atan2(-aim.x, -aim.z)
		var steering := clampf(-angle_difference(car.get_heading(), desired_heading) * 2.0, -1, 1)
		Input.action_press("steer_left" if steering < 0 else "steer_right", absf(steering))
		if car.drive_speed < speed - 0.3:
			Input.action_press("accelerate", 0.6)
		elif car.drive_speed > speed + 0.3:
			Input.action_press("brake", 0.4)
		await _frames(1)
		grounded = grounded and car.is_on_floor()
		if not car.is_on_floor():
			air_frames += 1
		max_height = maxf(max_height, car.position.y)
		max_pitch = maxf(max_pitch, absf(car.rotation.x))
		max_offset = maxf(max_offset, absf(car.position.x - Layout.center_x(car.position.z) - lane_offset))
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	return {"arrived": arrived, "grounded": grounded, "air_frames": air_frames, "max_height": max_height, "max_pitch": max_pitch, "max_offset": max_offset, "end": car.position}


func _isolate_driver_input() -> void:
	# Preserve simulated action_press inputs while excluding host keyboard/gamepad events.
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "pause", "camera_view", "camera_back", "headlights", "ui_accept", "ui_cancel"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)


func _support(streamer: WorldStreamer) -> void:
	for frame in 900:
		await _frames(1)
		if not streamer.blocked:
			return
	_check(false, "support becomes available within the functional deadline")


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		OS.delay_usec(2000)


func _geometry(node: Node) -> Array:
	var result: Array = [node.name, node.get_class()]
	if node is Node3D:
		result.append(node.transform)
	if node is CollisionShape3D:
		result.append(node.shape.get_faces() if node.shape is ConcavePolygonShape3D else node.shape.size)
	if node is MultiMeshInstance3D:
		result.append(node.multimesh.instance_transforms)
		result.append(node.multimesh.custom_aabb)
		result.append(node.material_override.albedo_texture.resource_path)
	if node is Label3D:
		result.append(node.text)
	if node is MeshInstance3D:
		result.append(node.mesh.surface_get_arrays(0))
		result.append(node.material_override.albedo_color)
		if node.material_override.albedo_texture != null:
			result.append(node.material_override.albedo_texture.resource_path)
	for child in node.get_children():
		result.append(_geometry(child))
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
