extends SceneTree

const WORLD := "res://scenes/corridor/drive_corridor.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Corridor benchmark requires a rendered display")
		quit(1)
		return
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset("medium" if "--medium" in OS.get_cmdline_user_args() else "legacy")
	if "--no-vsync" in OS.get_cmdline_user_args():
		settings.set_graphics("vsync", false)
	root.unresizable = true
	change_scene_to_file(WORLD)
	for frame in 10:
		await process_frame
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var capture := world.get_node("PerformanceCapture")
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "camera_view", "camera_back", "pause"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	if "--foreground" in OS.get_cmdline_user_args():
		root.grab_focus()
	await create_timer(10.0).timeout
	settings.apply_graphics()
	await create_timer(0.3).timeout
	if root.size != Vector2i(1280, 720):
		push_error("Corridor benchmark requires native 1280x720")
		quit(1)
		return
	if "--previews" in OS.get_cmdline_user_args():
		await _previews(world, car)
	else:
		capture.measure_render_time = "--profile-render-time" in OS.get_cmdline_user_args()
		capture.benchmark_metadata = {"route_id": "avenue-do-vale-v1", "length_m": 600, "target_kmh": 120, "warmup_seconds": 10, "seed": 5547, "screenshots_during_capture": false, "vehicle_top_speed_kmh": car.forward_speed * 3.6}
		capture.toggle()
		var started := Time.get_ticks_msec()
		while car.global_position.z > -580.0 and Time.get_ticks_msec() - started < 60000:
			Input.action_release("accelerate")
			Input.action_release("brake")
			if car.get_speed_kmh() < 119.0:
				Input.action_press("accelerate", 0.7)
			elif car.get_speed_kmh() > 121.0:
				Input.action_press("brake", 0.3)
			await physics_frame
			await process_frame
		Input.action_release("accelerate")
		Input.action_release("brake")
		capture.finish()
		var success := car.global_position.z < -580 and absf(car.global_position.x - 3.5) < 0.2 and car.is_on_floor()
		print("Corridor route: reached=%s position=%s speed=%.1f window=%s" % [success, car.global_position, car.get_speed_kmh(), root.size])
		if not success:
			quit(1)
			return
	world.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()


func _previews(world: Node3D, car: PlayerCar) -> void:
	# No PerformanceCapture runs during readback or PNG encoding.
	var positions: Array[Vector3] = [Vector3(3.5, 0.36, 6), Vector3(3.5, 0.36, -94), Vector3(3.5, 0.36, -321), Vector3(3.5, 0.36, -480)]
	for index in positions.size():
		car.reset_car()
		car.global_position = positions[index]
		car.set_physics_process(false)
		world.get_node("ChaseCamera").snap_to_target()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://corridor-%d.png" % index)
	car.set_physics_process(true)
	print("Corridor previews: " + OS.get_user_data_dir())
