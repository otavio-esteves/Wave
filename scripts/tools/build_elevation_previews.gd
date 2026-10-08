extends SceneTree

const Layout = preload("res://scripts/world/elevation_layout.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Elevation previews require a window; they do not benchmark FPS")
		quit(1)
		return
	var output := "res://builds/previews/elevation"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_node("WaveSettings").set_graphics_preset("economy")
	change_scene_to_file("res://scenes/world/drive_elevation.tscn")
	await scene_changed
	var world := current_scene
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	var camera := Camera3D.new()
	camera.far = 1200
	camera.fov = 65
	world.add_child(camera)
	camera.current = true
	var views := [
		{"name": "climb", "z": -155.0, "position": Layout.point(-145) + Vector3.UP * 2.3, "target": Layout.point(-260) + Vector3.UP},
		{"name": "crest", "z": -300.0, "position": Layout.point(-280) + Vector3.UP * 2.5, "target": Layout.point(-440) + Vector3.UP},
		{"name": "profile", "z": -300.0, "position": Vector3(70, 135, -350), "target": Vector3(0, 4, -360)},
		{"name": "shoulder", "z": -225.0, "position": Layout.point(-205, 12) + Vector3.UP * 3, "target": Layout.point(-245, 6.5)},
		{"name": "lookout", "z": Layout.LOOKOUT_Z, "position": Layout.point(-290, -9) + Vector3.UP * 5, "target": Layout.point(Layout.LOOKOUT_Z, 24) + Vector3.UP},
		{"name": "lookout-sign", "z": -225.0, "position": Layout.point(-225) + Vector3.UP * 2, "target": Layout.point(-245, 10.3) + Vector3.UP * 2},
	]
	for view in views:
		world.teleport_to(Layout.point(view.z), Layout.heading(view.z))
		for frame in 900:
			await process_frame
			var detail_ready := true
			for record in streamer.records:
				if record.wanted and record.node == null:
					detail_ready = false
			if not streamer.blocked and detail_ready:
				break
		if streamer.blocked:
			push_error("Preview failed to obtain physical terrain support")
			quit(1)
			return
		camera.position = view.position
		camera.look_at(view.target)
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view.name + ".png"))
	var file := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scene": world.scene_file_path, "preset": "economy", "window_size": str(root.size), "gpu": RenderingServer.get_video_adapter_name(), "views": views, "scope": "fixed lab views; no FPS capture or performance conclusion"}, "\t"))
	file.close()
	world.queue_free()
	for frame in 5:
		await process_frame
	await create_timer(0.2).timeout
	print("Elevation previews: " + ProjectSettings.globalize_path(output))
	quit()
