extends SceneTree

# Inspect the authored meshes in the playable world, preserving fog and culling.
const Layout = preload("res://scripts/city/pilot_city_layout.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual review requires a rendered window")
		quit(1)
		return
	var output := "res://builds/previews/refinement"
	var preset := "medium"
	var selected := PackedStringArray()
	var no_shadows := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--preset="):
			preset = argument.trim_prefix("--preset=")
		if argument.begins_with("--views="):
			selected = argument.trim_prefix("--views=").split(",")
		if argument == "--no-shadows":
			no_shadows = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var settings := root.get_node("WaveSettings")
	var previous: Dictionary = settings.graphics.duplicate(true)
	settings.set_graphics_preset(preset)
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
		Input.action_release(action)
	var world := current_scene
	var player: PlayerCar = world.get_node("PlayerCar")
	var cycle := world.get_node("DayNightCycle")
	if no_shadows:
		world.get_node("Sun").shadow_enabled = false
	cycle.running = false
	cycle.set_hour(16.5)
	for frame in 12:
		await physics_frame
		await process_frame
	player.set_physics_process(false)
	if selected.is_empty() or "driving" in selected:
		await _capture(output, "driving")
	world.get_node("HUD/Overlay").hide()
	var camera := Camera3D.new()
	camera.far = 5000
	world.add_child(camera)
	camera.current = true
	var views: Array[Dictionary] = []
	for item in [{"name": "car-front", "position": Vector3(-3.4, 1.45, -4.6)}, {"name": "car-rear", "position": Vector3(3.4, 1.45, 4.6)}, {"name": "car-side", "position": Vector3(-5.8, 1.3, 0.0)}, {"name": "car-detail", "position": Vector3(-2.4, 0.8, -2.9)}]:
		views.append({"name": item.name, "position": player.global_position + player.global_basis * item.position, "target": player.global_position + Vector3.UP * 0.5, "fov": 43.0})
	var addresses := world.get_node("City").find_children("Address*", "Node3D", false, false)
	addresses.sort_custom(func(a, b): return a.position.distance_squared_to(player.position) < b.position.distance_squared_to(player.position))
	for index in mini(3, addresses.size()):
		var address: Node3D = addresses[index]
		var basis := Basis(Vector3.UP, address.rotation.y)
		views.append({"name": "residence-%d" % index, "position": address.position + basis * Vector3(9, 1.9, 14), "target": address.position + basis * Vector3(-3, 1.5, -5), "fov": 58.0})
	var benches: Array = world.get_node("City").get_meta("review_benches", [])
	if not benches.is_empty():
		var bench: Dictionary = benches[0]
		var basis := Basis(Vector3.UP, bench.yaw)
		views.append({"name": "street-furniture", "position": bench.position + basis * Vector3(3.6, 1.8, 4.8), "target": bench.position + Vector3.UP * 0.6, "fov": 56.0})
	views.append({"name": "aurora", "position": Layout.position(145, 315, 3.2), "target": Layout.position(150, 265, 3), "fov": 64.0})
	views.append({"name": "gardens", "position": Layout.position(-840, -210, 3.2), "target": Layout.position(-870, -370, 3), "fov": 64.0})
	views.append({"name": "downtown", "position": Layout.position(941, 90, 3.2), "target": Layout.position(946, -160, 15), "fov": 64.0})
	for view in views:
		if not selected.is_empty() and view.name not in selected:
			continue
		camera.position = view.position
		camera.fov = view.fov
		camera.look_at(view.target)
		# Proximity systems continue to follow the player, as in actual gameplay.
		await _capture(output, view.name)
	camera.position = player.global_position + player.global_basis * Vector3(-3.4, 1.45, -4.6)
	camera.fov = 43
	camera.look_at(player.global_position + Vector3.UP * 0.5)
	for phase in [{"name": "car-day", "hour": 12.0}, {"name": "car-night", "hour": 23.0}]:
		if not selected.is_empty() and phase.name not in selected:
			continue
		cycle.set_hour(phase.hour)
		await _capture(output, phase.name)
	var context := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	context.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "preset": preset, "resolution": str(root.size), "blocks": Layout.BLOCK_COUNT, "views": views, "selected_views": selected, "diagnostic_no_shadows": no_shadows, "scope": "Static visual review, playable fog and ranges; no performance or human approval. Shadow disabling is explicitly marked when requested."}, "\t"))
	world.queue_free()
	for frame in 5:
		await process_frame
	settings.graphics = previous
	settings.save_settings()
	print("Visual review: " + output)
	quit()

func _capture(output: String, label: String) -> void:
	if current_scene != null and current_scene.has_node("VehicleReflection"):
		current_scene.get_node("VehicleReflection").refresh()
	for frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if error != OK:
		push_error("Capture failed: " + error_string(error))
		quit(1)
