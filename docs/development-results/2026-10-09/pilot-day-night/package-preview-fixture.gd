extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not FileAccess.file_exists("res://project.binary") or FileAccess.file_exists("res://project.godot"):
		push_error("Fixture requires actual exported package")
		quit(1)
		return
	root.get_node("WaveSettings").set_graphics_preset("medium")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	for frame in 3:
		await process_frame
	current_scene.pilot_button.pressed.emit()
	await scene_changed
	for frame in 15:
		await process_frame
	var world := current_scene
	var car := world.get_node("PlayerCar")
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "headlights", "advance_time"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	car.set_physics_process(false)
	var cycle := world.get_node("DayNightCycle")
	cycle.running = false
	var output := "/home/otavio/Projects/Wave/docs/art-results/2026-10-09/pilot-day-night"
	for phase in [{"name": "day", "hour": 16.5}, {"name": "night", "hour": 23.0}]:
		cycle.set_hour(phase.hour)
		for frame in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("package-driving-" + phase.name + ".png"))
	print("PACK_PREVIEW_OK: GPU=%s blocks=%s area=%s homes=%s grass=%s clock=%s" % [RenderingServer.get_video_adapter_name(), world.get_node("City").get_meta("block_count"), world.get_node("City").get_meta("area_m2"), world.get_node("City").get_meta("parcel_count"), world.get_node("City").get_meta("grass_tuft_count"), cycle.clock_text()])
	world.queue_free()
	for frame in 5:
		await process_frame
	quit()
