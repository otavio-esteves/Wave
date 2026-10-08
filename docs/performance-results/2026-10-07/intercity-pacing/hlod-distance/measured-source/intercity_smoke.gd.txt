extends SceneTree

const WORLD := "res://scenes/world/drive_intercity.tscn"
const MANIFEST := "res://scenes/world/cells/sol-serra/manifest.json"
const Layout = preload("res://scripts/world/intercity_layout.gd")
var checks := 0
var failures := 0
var rendered := false


func _initialize() -> void:
	rendered = DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture_enabled := not "--no-capture" in args
	var detail_enter := 180.0
	for argument in args:
		if argument.begins_with("--detail-enter="):
			var value := argument.trim_prefix("--detail-enter=")
			if not value.is_valid_float() or not is_finite(value.to_float()) or value.to_float() <= 0 or value.to_float() >= 200:
				push_error("Diagnostic detail distance must be between 0 and 200 metres")
				quit(1)
				return
			detail_enter = value.to_float()
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset("medium" if "--balanced" in args else "economy")
	if "--no-vsync" in args:
		settings.set_graphics("vsync", false)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_check(manifest.cells.size() == 4 and manifest.cells[0].scene == "res://scenes/world/cells/vale/cell-0.tscn", "four-cell route reuses the authored urban cell unchanged")
	var connected := true
	for index in range(1, 4):
		var previous: Dictionary = manifest.cells[index - 1]
		var entry: Dictionary = manifest.cells[index]
		connected = connected and entry.region == Layout.REGIONS[index] and previous.neighbors.has(entry.id) and entry.neighbors.has(previous.id) and entry.bounds[2] + entry.bounds[5] == previous.bounds[2]
	_check(connected, "urban, rural, highway and town boundaries are contiguous with reciprocal neighbors")
	if not rendered:
		var output := "user://intercity-regenerated"
		var error: Error = preload("res://scripts/world/intercity_builder.gd").new().build_route(output)
		_check(error == OK, "route generator saves independently into isolated user data")
		for index in range(1, 4):
			var saved: Node3D = load(manifest.cells[index].scene).instantiate()
			var regenerated: Node3D = load("%s/cell-%d.tscn" % [output, index]).instantiate()
			_check(_geometry(saved) == _geometry(regenerated), "cell %d preserves serialized geometry, placement, UVs and collision on regeneration" % index)
			saved.free()
			regenerated.free()
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	await _frames(3)
	current_scene.intercity_button.pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path == WORLD, "the new menu action opens the continuous journey")
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	var hlod: WorldHLOD = world.get_node("Distant")
	hlod.detail_enter_distance = detail_enter
	hlod.update_representation()
	await _support(streamer)
	await _frames(8)
	var identities := [car.get_instance_id(), world.get_node("ChaseCamera").get_instance_id(), world.get_node("HUD").get_instance_id()]
	var capture := world.get_node("PerformanceCapture")
	var observer: Node = null
	if rendered and "--pacing-diagnostic" in args:
		observer = preload("res://tests/intercity_pacing_observer.gd").new()
		observer.car = car
		observer.streamer = streamer
		world.add_child(observer)
	if rendered:
		for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "pause", "camera_view", "camera_back"]:
			InputMap.action_erase_events(action)
			Input.action_release(action)
		if "--foreground" in args:
			root.grab_focus()
		await create_timer(10).timeout
		settings.apply_graphics()
		await create_timer(0.3).timeout
		if "--foreground" in args:
			root.grab_focus()
			await create_timer(0.3).timeout
		_check(root.size == settings.RESOLUTIONS[settings.graphics.resolution], "rendered route uses the requested native resolution")
		capture.benchmark_metadata = {"route": "sol-serra-proof-v1", "warmup_seconds": 10, "target_speed_kmh": 108, "return_turn": "heading reset at endpoint", "seed": 5547}
		if capture_enabled:
			capture.toggle()
	if observer != null:
		observer.begin("outward")
	var holds := streamer.blocking_events
	var outward := await _drive(car, -1350, false)
	if observer != null:
		observer.end()
	_check(outward.grounded and outward.arrived and outward.max_offset < 2.5, "normal vehicle inputs traverse urban, rural curves, highway and town with stable support")
	_check(streamer.blocking_events == holds and streamer.failure_count == 0, "outward traversal has no streaming safety holds or load failures")
	_check(streamer.current_cell == "link-3" and streamer.resident_count() <= 3 and streamer.released_cells > 0, "town arrival unloads the urban cell under the existing three-cell residency cap")
	if rendered:
		capture.finish()
	# Probe actual floor collision either side of every region boundary.
	var seams := true
	for boundary in [-200.0, -600.0, -1000.0]:
		world.teleport_to(Layout.point(boundary))
		await _support(streamer)
		await _frames(5)
		for dz in [-0.01, 0.0, 0.01]:
			for x in [-5.5, 0.0, 5.5]:
				var point := Vector3(Layout.center_x(boundary + dz) + x, 2, boundary + dz)
				var query := PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 4)
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
				seams = seams and not hit.is_empty() and absf(hit.position.y) < 0.001
	_check(seams, "all three joins have real collision across the full road width")
	world.teleport_to(Layout.point(-1350), PI)
	await _support(streamer)
	if rendered:
		capture.benchmark_metadata["leg"] = "return"
		if capture_enabled:
			capture.toggle()
	if observer != null:
		observer.begin("return")
	holds = streamer.blocking_events
	var returning := await _drive(car, 20, true)
	if observer != null:
		observer.end()
	_check(returning.arrived and returning.grounded and returning.max_offset < 2.5 and streamer.blocking_events == holds, "return drive reloads the urban cell without a gap or safety hold")
	if rendered:
		capture.finish()
	_check(identities == [car.get_instance_id(), world.get_node("ChaseCamera").get_instance_id(), world.get_node("HUD").get_instance_id()], "car, camera and HUD identities persist through four regions")
	_check(streamer.peak_resident_cells <= 3 and streamer.failure_count == 0, "resident set stays bounded as total world cells increase")
	car.reset_car()
	await _support(streamer)
	await _frames(5)
	_check(car.position.distance_to(car.spawn_transform.origin) < 0.1 and car.is_on_floor(), "reset restores the original urban spawn with registered collision")
	var file := FileAccess.open("user://intercity.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"rendered": rendered, "outward": outward, "return": returning, "streaming": streamer.snapshot(), "checks": checks, "failures": failures}, "\t"))
	file.close()
	if observer != null:
		observer.save(capture_enabled)
	if rendered and "--previews" in args:
		for z in [24.0, -350.0, -800.0, -1250.0]:
			world.teleport_to(Layout.point(z))
			await _support(streamer)
			await _frames(30)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://region-%d.png" % int(-z))
	world.get_node("HUD").set_paused(true)
	world.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(5)
	_check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and not paused, "journey returns to the menu and restores pause state")
	current_scene.queue_free()
	await _frames(5)
	OS.delay_msec(150)
	await _frames(5)
	await create_timer(0.2).timeout
	print("Intercity smoke test: %d checks, %d failures; data %s" % [checks, failures, OS.get_user_data_dir()])
	quit(0 if failures == 0 else 1)


func _drive(car: PlayerCar, destination: float, returning: bool) -> Dictionary:
	var grounded := true
	var max_offset := 0.0
	var arrived := false
	for frame in 9000:
		var z := car.position.z
		if (returning and z >= destination) or (not returning and z <= destination):
			arrived = true
			break
		var target_z := z + (20 if returning else -20)
		var offset := Layout.point(target_z) - car.position
		var heading := atan2(-offset.x, -offset.z)
		var steering := clampf(-angle_difference(car.rotation.y, heading) * 2, -1, 1)
		for action in ["steer_left", "steer_right", "accelerate", "brake"]:
			Input.action_release(action)
		Input.action_press("steer_left" if steering < 0 else "steer_right", absf(steering))
		if car.drive_speed < 29.7:
			Input.action_press("accelerate", 0.7)
		elif car.drive_speed > 30.3:
			Input.action_press("brake", 0.4)
		await _frames(1)
		grounded = grounded and car.is_on_floor()
		max_offset = maxf(max_offset, absf(car.position.x - Layout.center_x(car.position.z) - 3.5))
	for action in ["steer_left", "steer_right", "accelerate", "brake"]:
		Input.action_release(action)
	return {"arrived": arrived, "grounded": grounded, "max_offset": max_offset, "end_z": car.position.z}


func _support(streamer: WorldStreamer) -> void:
	for frame in 900:
		await _frames(1)
		if not streamer.blocked:
			return
	_check(false, "destination support becomes available within the test deadline")


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		if not rendered:
			OS.delay_usec(2000)


func _geometry(node: Node) -> Array:
	var result: Array = [node.name, node.get_class()]
	if node is Node3D:
		result.append(node.transform)
	if node is CollisionShape3D:
		result.append(node.shape.size)
	if node is MultiMeshInstance3D:
		result.append(node.multimesh.instance_transforms)
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			result.append(node.mesh.surface_get_arrays(surface))
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
