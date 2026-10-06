extends SceneTree

# Run on a real display without --headless or --fixed-fps. This measures the
# reference route with automated controls; driving feel still needs a player.
const WAYPOINTS: Array[Vector3] = [
	Vector3(3.5, 0, -66.5), Vector3(66.5, 0, -66.5),
	Vector3(66.5, 0, 66.5), Vector3(30, 0, 66.5), Vector3(30, 0, 40),
]


const RESIDENTIAL_WAYPOINTS: Array[Vector3] = [
	Vector3(3.5, 0, -136.5), Vector3(206.5, 0, -136.5),
	Vector3(206.5, 0, 136.5), Vector3(3.5, 0, 136.5), Vector3(3.5, 0, 83),
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("The reference route requires a visible rendered window.")
		quit(1)
		return
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://main-menu.png")
	if "--check-display" in OS.get_cmdline_user_args():
		var menu := current_scene
		menu.graphics_button.pressed.emit()
		root.get_node("WaveSettings").set_graphics("resolution", "960x540")
		menu.graphics_options.open()
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://graphics-options.png")
		root.get_node("WaveSettings").set_graphics("fullscreen", true)
		await create_timer(0.3).timeout
		root.get_node("WaveSettings").set_graphics("fullscreen", false)
		await create_timer(0.3).timeout
		if root.size != Vector2i(960, 540):
			push_error("Window resolution did not restore after fullscreen: %s" % root.size)
			quit(1)
			return
		menu.graphics_options.close()
	var settings := root.get_node("WaveSettings")
	settings.set_balanced_mode()
	if "--no-shadows" in OS.get_cmdline_user_args():
		root.get_node("WaveSettings").set_graphics("shadows", false)
	if "--low-resolution" in OS.get_cmdline_user_args():
		root.get_node("WaveSettings").set_graphics("resolution", "960x540")
	if "--economy" in OS.get_cmdline_user_args():
		root.get_node("WaveSettings").set_economy_mode()
	if "--legacy" in OS.get_cmdline_user_args():
		settings.set_graphics_preset("legacy")
	if "--high" in OS.get_cmdline_user_args():
		settings.set_quality_mode()
	if "--no-aa" in OS.get_cmdline_user_args():
		settings.set_graphics("antialiasing", false)
	var expected_size: Vector2i = settings.RESOLUTIONS[settings.graphics["resolution"]]
	root.unresizable = true
	current_scene.drive_button.pressed.emit()
	for frame in 5:
		await process_frame
	await create_timer(10.0).timeout
	settings.apply_graphics()
	await create_timer(0.3).timeout
	if root.size != expected_size:
		push_error("Benchmark window differs from requested size: %s != %s" % [root.size, expected_size])
		quit(1)
		return
	var world := current_scene
	var car := world.get_node("PlayerCar") as PlayerCar
	var capture := world.get_node("PerformanceCapture")
	capture.measure_render_time = "--profile-render-time" in OS.get_cmdline_user_args()
	for action: String in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "camera_view", "camera_back", "pause"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	var residential := "--residential" in OS.get_cmdline_user_args()
	var points: Array[Vector3] = RESIDENTIAL_WAYPOINTS if residential else WAYPOINTS
	capture.benchmark_metadata = {"route_id": "residential-v1" if residential else "urban-center-v1", "warmup_seconds": 10.0, "straight_target_mps": 12.0, "corner_target_mps": 6.0, "waypoints": points, "expected_window": str(expected_size)}
	world.get_node("HUD/Overlay/Diagnostics").show()
	if "--foreground" in OS.get_cmdline_user_args():
		root.grab_focus()
		await create_timer(0.3).timeout
	if "--no-vsync" in OS.get_cmdline_user_args():
		root.get_node("WaveSettings").set_graphics("vsync", false)
	capture.toggle()
	var waypoint := 0
	var start := Time.get_ticks_msec()
	var timeout_ms := 150000 if residential else 90000
	while waypoint < points.size() and Time.get_ticks_msec() - start < timeout_ms:
		var offset := points[waypoint] - car.global_position
		offset.y = 0.0
		if offset.length() < 6.0:
			waypoint += 1
			continue
		var heading := atan2(-offset.x, -offset.z)
		var error := angle_difference(car.rotation.y, heading)
		var steering := clampf(-error * 2.0, -1.0, 1.0)
		var corner := absf(error) > 0.35 or offset.length() < 15.0
		var target_speed := 6.0 if corner else 12.0
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		Input.action_release("accelerate")
		Input.action_release("brake")
		if steering < 0:
			Input.action_press("steer_left", -steering)
		else:
			Input.action_press("steer_right", steering)
		if car.drive_speed < target_speed - 0.3:
			Input.action_press("accelerate", 0.7)
		elif car.drive_speed > target_speed + 0.3:
			Input.action_press("brake", 0.4)
		await physics_frame
		await process_frame
	for action: String in ["accelerate", "brake", "steer_left", "steer_right"]:
		Input.action_release(action)
	capture.finish()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://neighborhood.png")
	print("Rendered reference route: %d/%d waypoints; screenshots: %s" % [waypoint, points.size(), OS.get_user_data_dir()])
	current_scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if waypoint == points.size() else 1)
