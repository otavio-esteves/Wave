extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("HLOD previews require a rendered display")
		quit(1)
		return
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset("legacy")
	if "--no-vsync" in OS.get_cmdline_user_args():
		settings.set_graphics("vsync", false)
	root.unresizable = true
	change_scene_to_file("res://scenes/world/drive_streamed_corridor.tscn")
	for frame in 10:
		await process_frame
	var world: Node3D = current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	var hlod: WorldHLOD = world.get_node("Distant")
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "camera_view", "camera_back", "pause"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	if "--foreground" in OS.get_cmdline_user_args():
		root.grab_focus()
	await create_timer(10.0).timeout
	if root.size != Vector2i(1280, 720):
		quit(1)
		return
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 65.0
	camera.make_current()
	var views: Array[Dictionary] = [
		{"name": "spawn", "car_z": 24.0, "camera": Vector3(0, 8, 48), "look": Vector3(0, 3, -280)},
		{"name": "return", "car_z": -580.0, "camera": Vector3(0, 8, -612), "look": Vector3(0, 3, -290)},
		{"name": "resident-distance", "car_z": 10.0, "camera": Vector3(0, 8, 35), "look": Vector3(0, 3, -260)},
	]
	var samples: Array[Dictionary] = []
	for view in views:
		world.teleport_to(Vector3(3.5, 0.36, view.car_z))
		var started := Time.get_ticks_msec()
		while streamer.blocked and Time.get_ticks_msec() - started < 15000:
			await process_frame
		if streamer.blocked:
			push_error("HLOD preview lacks supported destination")
			quit(1)
			return
		car.set_physics_process(false)
		camera.global_position = view.camera
		camera.look_at(view.look)
		for enabled in [true, false]:
			hlod.enabled = enabled
			hlod.update_representation()
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			var label: String = view.name + ("-hlod" if enabled else "-resident-only")
			# Fixed matching views; no performance capture during readback/encoding.
			samples.append({"view": label, "streaming": streamer.snapshot(), "hlod": hlod.snapshot(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			root.get_texture().get_image().save_png("user://" + label + ".png")
	var report := {"scope": "matched fixed views for visual review and render counters; no FPS certification", "engine": Engine.get_version_info()["string"], "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "window_size": str(root.size), "preset": settings.get_graphics_preset(), "graphics": settings.graphics.duplicate(), "samples": samples}
	var file := FileAccess.open("user://hlod-previews.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("HLOD previews: " + OS.get_user_data_dir())
	world.queue_free()
	await process_frame
	for frame in 600:
		await process_frame
		if get_nodes_in_group("world_load_drain").is_empty():
			break
	await create_timer(0.2).timeout
	quit()
