extends SceneTree

# Run on a real display without --headless or --fixed-fps. This measures the
# reference route with automated controls; driving feel still needs a player.
const WAYPOINTS: Array[Vector3] = [
	Vector3(3.5, 0, -66.5), Vector3(66.5, 0, -66.5),
	Vector3(66.5, 0, 66.5), Vector3(30, 0, 66.5), Vector3(30, 0, 40),
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
	root.get_node("WaveSettings").set_graphics("resolution", "1280x720")
	root.get_node("WaveSettings").set_graphics("shadows", true)
	if "--no-shadows" in OS.get_cmdline_user_args():
		root.get_node("WaveSettings").set_graphics("shadows", false)
	if "--low-resolution" in OS.get_cmdline_user_args():
		root.get_node("WaveSettings").set_graphics("resolution", "960x540")
	if "--economy" in OS.get_cmdline_user_args():
		root.get_node("WaveSettings").set_economy_mode()
	current_scene.drive_button.pressed.emit()
	for frame in 5:
		await process_frame
	await create_timer(10.0).timeout
	var world := current_scene
	var car := world.get_node("PlayerCar") as PlayerCar
	var capture := world.get_node("PerformanceCapture")
	world.get_node("HUD/Overlay/Diagnostics").show()
	capture.toggle()
	var waypoint := 0
	var start := Time.get_ticks_msec()
	while waypoint < WAYPOINTS.size() and Time.get_ticks_msec() - start < 90000:
		var offset := WAYPOINTS[waypoint] - car.global_position
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
	print("Rendered reference route: %d/%d waypoints; screenshots: %s" % [waypoint, WAYPOINTS.size(), OS.get_user_data_dir()])
	current_scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if waypoint == WAYPOINTS.size() else 1)
