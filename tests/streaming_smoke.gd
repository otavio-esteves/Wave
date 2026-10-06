extends SceneTree

const WORLD := "res://scenes/world/drive_streamed_corridor.tscn"
const MANIFEST := "res://scenes/world/cells/vale/manifest.json"
var checks := 0
var failures := 0


func _initialize() -> void:
	# Cap normal runs; fixed-FPS headless runs yield wall time in _frames().
	Engine.max_fps = 240
	_run.call_deferred()


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_check(manifest.cells.size() == 3 and manifest.version == 1, "offline manifest contains exactly three independently stored cells")
	var total_colliders := 0
	var shapes: Array[Node3D] = []
	for entry in manifest.cells:
		var cell: Node3D = load(entry.scene).instantiate()
		shapes.append(cell)
		total_colliders += cell.get_node("Colliders").get_child_count()
		_check(cell.get_node("Colliders/Floor").shape.size.z == entry.bounds[5], "cell %s owns a bounded floor and local colliders" % entry.id)
	_check(total_colliders == 853, "partition preserves 850 props and replaces one global floor with three touching floors")
	var material_a: Material = _material(shapes[0], "plaster")
	_check(material_a != null and material_a == _material(shapes[1], "plaster") and material_a.resource_path.begins_with("res://scenes/world/cells/vale/shared/"), "cells share external materials rather than embedding complete independent palettes")
	for cell in shapes:
		cell.free()
	var observer := Node.new()
	observer.set_script(preload("res://scripts/tools/startup_observer.gd"))
	root.add_child(observer)
	var world := await _open()
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	await _ready_motion(streamer)
	var entry: Dictionary = observer.snapshot()
	var measured := 0.0
	var chronological := true
	for row in entry.frames:
		chronological = chronological and row.interval_ms > 0.0 and row.elapsed_ms >= measured
		measured += row.interval_ms
	_check(entry.completed and not entry.frames.is_empty() and chronological and absf(measured - entry.scene_entry_ms) < 0.01 and not observer.is_processing(), "startup observer retains chronological entry intervals and stops only after support is ready")
	observer.queue_free()
	var player_id := car.get_instance_id()
	var camera_id := world.get_node("ChaseCamera").get_instance_id()
	var hud_id := world.get_node("HUD").get_instance_id()
	_check(car.is_on_floor() and streamer.resident_count() == 1, "stationary spawn activates only its supporting cell; preload expands with movement")
	var holds := streamer.blocking_events
	Input.action_press("accelerate")
	var grounded := true
	for frame in 1600:
		await _frames(1)
		grounded = grounded and car.is_on_floor()
		if car.position.z < -580:
			break
	Input.action_release("accelerate")
	_check(car.position.z < -580 and grounded and streamer.blocking_events == holds, "220 km/h outward traversal crosses both seams without missing support or a safety hold")
	await _frames(8)
	_check(streamer.current_cell == "vale-2" and streamer.resident_count() == 2 and streamer.released_cells >= 1, "far first cell releases nodes/resources while the ending cell remains supported")
	_check(car.get_instance_id() == player_id and world.get_node("ChaseCamera").get_instance_id() == camera_id and world.get_node("HUD").get_instance_id() == hud_id, "player camera and HUD identities survive cell transitions")
	world.teleport_to(Vector3(3.5, 0.36, -580), PI)
	await _ready_motion(streamer)
	holds = streamer.blocking_events
	Input.action_press("accelerate")
	grounded = true
	for frame in 1600:
		await _frames(1)
		grounded = grounded and car.is_on_floor()
		if car.position.z > 20:
			break
	Input.action_release("accelerate")
	_check(car.position.z > 20 and grounded and streamer.blocking_events == holds, "return drive reloads the first cell and crosses both seams with continuous support")
	_check(streamer.peak_resident_cells <= 3 and streamer.failure_count == 0, "resident set respects the configured three-cell cap")
	world.teleport_to(Vector3(3.5, 0.36, -300))
	await _ready_motion(streamer)
	await _frames(80)
	for frame in 600:
		if streamer.resident_count() == 3:
			break
		await _frames(1)
	var seams_ok := true
	for z in [-200.01, -200.0, -199.99, -400.01, -400.0, -399.99]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(3.5, 2, z), Vector3(3.5, -2, z))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or absf(hit.position.y) >= 0.001:
			print("Seam probe: z=%s hit=%s states=%s" % [z, hit, streamer.snapshot().states])
		seams_ok = seams_ok and not hit.is_empty() and absf(hit.position.y) < 0.001
	_check(seams_ok, "serialized cell floor seams have real collision support on both sides")
	var requests := _events(streamer, "request")
	for index in 20:
		world.teleport_to(Vector3(3.5, 0.36, -199 if index % 2 == 0 else -201))
		await _frames(3)
	_check(_events(streamer, "request") == requests, "boundary reversal uses hysteresis without load/unload cycling")
	world.teleport_to(Vector3(3.5, 0.36, -580))
	await _ready_motion(streamer)
	await _frames(20)
	car.reset_car()
	await _ready_motion(streamer)
	_check(car.position.distance_to(car.spawn_transform.origin) < 0.1 and car.is_on_floor() and streamer.current_cell == "vale-0", "reset reactivates original support before driving resumes")
	await _close(world)

	world = await _open(90)
	car = world.get_node("PlayerCar")
	streamer = world.get_node("WorldStreamer")
	await _frames(10)
	var held := car.global_transform
	_check(streamer.blocked and streamer.resident_count() == 0, "injected slow I/O holds motion while no supporting cell exists")
	paused = true
	var states: Dictionary = streamer.snapshot().states
	await _frames(30)
	_check(car.global_transform == held and streamer.snapshot().states == states and streamer.resident_count() == 0, "pause freezes activation and movement even if threaded I/O completes")
	paused = false
	world.teleport_to(Vector3(3.5, 0.36, -580))
	await _ready_motion(streamer)
	await _frames(120)
	_check(_events(streamer, "obsolete_result") >= 1 and not _has_event(streamer, "vale-0", "instantiate"), "obsolete first-cell result is drained without activation after teleport")
	_check(car.is_on_floor() and car.position.y > 0.3 and streamer.current_cell == "vale-2", "delayed teleport resumes only after destination support is registered")
	await _close(world)

	var broken := manifest.duplicate(true)
	broken.cells[0].scene = "user://missing-cell.tscn"
	world = await _open(0, _manifest(broken, "missing"))
	car = world.get_node("PlayerCar")
	streamer = world.get_node("WorldStreamer")
	await _frames(140)
	var errors := streamer.failure_count
	await _frames(60)
	_check(streamer.blocked and errors == 1 and streamer.failure_count == 1 and absf(car.position.y - 0.36) < 0.00001, "missing resource fails once and cannot drop the car or retry every frame")
	await _close(world)
	var invalid := Node.new()
	var packed := PackedScene.new()
	packed.pack(invalid)
	ResourceSaver.save(packed, "user://invalid-cell.tscn")
	invalid.free()
	broken.cells[0].scene = "user://invalid-cell.tscn"
	world = await _open(0, _manifest(broken, "invalid-root"))
	streamer = world.get_node("WorldStreamer")
	await _frames(140)
	_check(streamer.blocked and streamer.failure_count == 1 and streamer.records[0].node == null, "invalid root activation is rejected and released safely")
	await _close(world)
	var empty := Node3D.new()
	packed = PackedScene.new()
	packed.pack(empty)
	ResourceSaver.save(packed, "user://empty-cell.tscn")
	empty.free()
	broken.cells[0].scene = "user://empty-cell.tscn"
	world = await _open(0, _manifest(broken, "missing-floor"))
	streamer = world.get_node("WorldStreamer")
	await _frames(200)
	_check(streamer.blocked and streamer.failure_count == 1 and streamer.records[0].node == null, "a Node3D cell without the promised collision floor cannot authorize movement")
	await _close(world)
	broken = manifest.duplicate(true)
	broken.cells[0].neighbors = ["unknown"]
	world = await _open(0, _manifest(broken, "invalid-manifest"))
	streamer = world.get_node("WorldStreamer")
	await _frames(10)
	_check(streamer.failure_count == 1 and streamer.records.is_empty() and streamer.blocked, "invalid manifest neighbors fail before any load request")
	await _close(world)
	world = await _open(120)
	streamer = world.get_node("WorldStreamer")
	await _frames(2)
	var streamer_id := streamer.get_instance_id()
	await _close(world)
	await _frames(40)
	for frame in 600:
		if get_nodes_in_group("world_load_drain").is_empty():
			break
		await _frames(1)
	_check(get_nodes_in_group("world_load_drain").is_empty(), "outstanding loader result is consumed before shutdown")
	_check(not is_instance_id_valid(streamer_id) and not paused and get_nodes_in_group("wave_audio").is_empty(), "world destruction with a pending load frees streamer/audio and drains without a callback to freed nodes")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(3)
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)
	_check(current_scene.scene_file_path == WORLD, "Enter on the default menu action opens the city walk")
	streamer = current_scene.get_node("WorldStreamer")
	await _ready_motion(streamer)
	current_scene.get_node("HUD").set_paused(true)
	current_scene.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(6)
	_check(not paused and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and get_nodes_in_group("wave_audio").is_empty(), "HUD returns from streamed world to menu and releases audio even during loading")
	current_scene.queue_free()
	await _frames(3)
	OS.delay_msec(150)
	await _frames(3)
	await create_timer(0.2).timeout
	print("Streaming smoke test: %d checks, %d failures" % [checks, failures])
	quit.call_deferred(0 if failures == 0 else 1)


func _open(delay: int = 0, path: String = MANIFEST) -> Node3D:
	var world: Node3D = load(WORLD).instantiate()
	world.get_node("WorldStreamer").request_delay_frames = delay
	world.get_node("WorldStreamer").manifest_file = path
	root.add_child(world)
	current_scene = world
	await _frames(2)
	return world


func _close(world: Node3D) -> void:
	world.queue_free()
	await _frames(3)
	OS.delay_msec(50)
	await _frames(3)


func _ready_motion(streamer: WorldStreamer) -> void:
	for frame in 600:
		await _frames(1)
		if not streamer.blocked:
			await _frames(5)
			return
	print("Startup timeout: ", streamer.snapshot())
	_check(false, "supporting cell becomes ready within test deadline")


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		# --fixed-fps advances simulation without honoring Engine.max_fps.
		# Workers still need real time for file I/O, even on a fast test host.
		if DisplayServer.get_name() == "headless":
			OS.delay_usec(4167)


func _manifest(document: Dictionary, suffix: String) -> String:
	var path := "user://manifest-%s.json" % suffix
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	return path


func _material(cell: Node3D, name: String) -> Material:
	for node in cell.get_children():
		if node is MultiMeshInstance3D and node.material_override.resource_name == name:
			return node.material_override
	return null


func _events(streamer: WorldStreamer, phase: String) -> int:
	var count := 0
	for event in streamer.events:
		if event.phase == phase:
			count += 1
	return count


func _has_event(streamer: WorldStreamer, id: String, phase: String) -> bool:
	for event in streamer.events:
		if event.cell == id and event.phase == phase:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
