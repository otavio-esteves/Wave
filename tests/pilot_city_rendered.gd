extends "res://tests/pilot_city_smoke.gd"

func _run() -> void:
	if DisplayServer.get_name() == "headless" or "--fixed-fps" in OS.get_cmdline_args():
		push_error("Pilot render diagnostic needs a real window and uncapped simulation time")
		quit(1)
		return
	var settings := root.get_node("WaveSettings")
	var preset := "economy" if "--economy" in OS.get_cmdline_user_args() else "medium"
	settings.set_graphics_preset(preset)
	settings.set_graphics("vsync", false)
	settings.set_graphics("fps_limit", 0)
	change_scene_to_file(WORLD)
	await scene_changed
	var world: Node3D = current_scene
	var baseline_dir := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-dir="):
			baseline_dir = argument.trim_prefix("--baseline-dir=")
	var baseline := not baseline_dir.is_empty()
	if baseline:
		var probe := world.get_node_or_null("NeighborhoodReflection")
		if probe != null:
			probe.free()
		var path := baseline_dir.path_join("")
		var city: Node3D = load(path.path_join("pilot_city.tscn")).instantiate()
		world.get_node("City").free()
		city.name = "City"
		world.add_child(city)
		var old_world: Node3D = load(path.path_join("drive_pilot_city.tscn")).instantiate()
		world.get_node("WorldEnvironment").environment = old_world.get_node("WorldEnvironment").environment
		world.get_node("Sun").rotation = old_world.get_node("Sun").rotation
		world.get_node("Sun").light_color = old_world.get_node("Sun").light_color
		world.get_node("Sun").light_energy = old_world.get_node("Sun").light_energy
		# Preserve the immediately previous grade when doing a new-stage comparison.
		# Historical stage-0 runs still use their original no-probe/no-contact baseline.
		if "--baseline-current-grade" in OS.get_cmdline_user_args():
			var old_probe := old_world.get_node_or_null("NeighborhoodReflection")
			if old_probe != null:
				world.add_child(old_probe.duplicate())
		old_world.free()
		world.get_node("PlayerCar").contact_shadow_enabled = "--baseline-current-grade" in OS.get_cmdline_user_args()
		world.get_node("PlayerCar/Visuals/Body").mesh = load(path.path_join("body.tres"))
		for wheel in world.get_node("PlayerCar").wheels:
			wheel.mesh = load(path.path_join("wheel.tres"))
	for action in ACTIONS + ["reset_car", "pause", "camera_view", "camera_back"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	await create_timer(5.0).timeout
	settings.apply_graphics()
	var car: PlayerCar = world.get_node("PlayerCar")
	var route := Layout.route(Layout.CENTRE_LOOP, 1.5).slice(7)
	_place(car, route[0], route[1] - route[0])
	await create_timer(0.5).timeout
	var capture := world.get_node("PerformanceCapture")
	capture.benchmark_metadata = {"route_id": "pilot-centre-v1", "baseline": baseline, "warmup_seconds": 5.0, "target_kmh": 30.0, "scope": "one short local diagnostic, not exclusive-use or 8GB certification"}
	capture.toggle()
	var result := await _drive(car, route, 30.0 / 3.6)
	capture.finish()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://pilot-route.png")
	var file := FileAccess.open("user://pilot-render-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"result": result, "preset": preset, "baseline": baseline, "gpu": RenderingServer.get_video_adapter_name(), "window": str(root.size)}, "\t"))
	print("Pilot rendered diagnostic: %s, %s; %s" % [preset, result, OS.get_user_data_dir()])
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit.call_deferred(0 if result.arrived and result.ground_ratio > 0.99 else 1)
