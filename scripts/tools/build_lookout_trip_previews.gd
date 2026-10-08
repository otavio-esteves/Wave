extends SceneTree

const Layout = preload("res://scripts/world/elevation_layout.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Trip HUD previews require a window")
		quit(1)
		return
	var output := "res://builds/previews/lookout-trip"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_node("WaveSettings").set_graphics_preset("economy")
	change_scene_to_file("res://scenes/world/drive_elevation.tscn")
	await scene_changed
	var world := current_scene
	var trip := world.get_node("LookoutTrip")
	for state in ["driving", "parking", "complete"]:
		if state != "driving":
			var z := -286.0 if state == "parking" else Layout.LOOKOUT_Z
			world.teleport_to(Layout.point(z, 3.5 if state == "parking" else 20), Layout.heading(z))
		for frame in 900:
			await process_frame
			if not world.streamer.blocked:
				break
		if world.streamer.blocked:
			push_error("HUD preview has no registered destination support")
			quit(1)
			return
		# These are staged UI views. Headless live-driving tests validate rules.
		trip.state = state
		trip.next_gate = 0 if state == "driving" else 3
		trip._update_readout()
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(state + ".png"))
	var file := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scene": world.scene_file_path, "preset": "economy", "window_size": str(root.size), "gpu": RenderingServer.get_video_adapter_name(), "scope": "three staged HUD states; rules validated separately by live headless inputs; no FPS capture"}, "\t"))
	file.close()
	world.queue_free()
	for frame in 5:
		await process_frame
	await create_timer(0.2).timeout
	print("Lookout trip HUD previews: " + ProjectSettings.globalize_path(output))
	quit()
