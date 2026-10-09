extends SceneTree

const Layout = preload("res://scripts/city/pilot_city_layout.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Pilot city previews require a rendered window")
		quit(1)
		return
	var output := "res://builds/previews/pilot-city"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var preset := "medium" if "--medium" in OS.get_cmdline_user_args() else "economy"
	var settings := root.get_node("WaveSettings")
	var previous_graphics: Dictionary = settings.graphics.duplicate(true)
	settings.set_graphics_preset(preset)
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("driving-spawn.png"))
	var world := current_scene
	world.get_node("PlayerCar").set_physics_process(false)
	world.get_node("HUD/Overlay").hide()
	var camera := Camera3D.new()
	camera.far = 1200
	camera.near = 0.1
	world.add_child(camera)
	camera.current = true
	var views := [
		{"name": "overview", "position": Vector3(35, 260, 280), "target": Vector3(0, 5, 0), "fov": 58.0},
		{"name": "centre", "position": Layout.position(-55, 118, 12), "target": Layout.position(-70, 45, 2), "fov": 60.0},
		{"name": "hill", "position": Layout.node(5) + Vector3(-12, 5, 12), "target": Layout.node(2) + Vector3.UP * 2, "fov": 65.0},
	]
	var player: Node3D = world.get_node("PlayerCar")
	views.append({"name": "car-street", "position": player.global_position + Vector3(4.6, 2.6, -5.8), "target": player.global_position + Vector3.UP * 0.5, "fov": 38.0})
	var tree_origin := Vector3.ZERO
	var tree_distance := INF
	for geometry in world.get_node("City").get_children():
		if geometry is MultiMeshInstance3D and geometry.name.begins_with("tree_bark"):
			for placement in geometry.multimesh.instance_transforms:
				var point: Vector3 = geometry.global_transform * placement.origin
				if point.distance_squared_to(player.global_position) < tree_distance:
					tree_distance = point.distance_squared_to(player.global_position)
					tree_origin = point
	views.append({"name": "tree-front", "position": tree_origin + Vector3(6, 3.8, 9), "target": tree_origin + Vector3.UP * 3.8, "fov": 52.0})
	views.append({"name": "tree-side", "position": tree_origin + Vector3(-9, 3.8, 4), "target": tree_origin + Vector3.UP * 3.8, "fov": 52.0})
	var address := world.get_node("City").find_children("Address*", "Node3D", false, false)[0] as Node3D
	views.append({"name": "residence", "position": address.position + Basis(Vector3.UP, address.rotation.y) * Vector3(10, 2.5, 17), "target": address.position + Basis(Vector3.UP, address.rotation.y) * Vector3(-4, 1.5, -5), "fov": 55.0})
	world.get_node("WorldEnvironment").environment.fog_enabled = false
	for geometry in world.find_children("*", "GeometryInstance3D", true, false):
		geometry.visibility_range_end = 0.0
	for view in views:
		camera.near = 5.0 if view.name == "overview" else 0.1
		camera.position = view.position
		camera.fov = view.fov
		camera.look_at(view.target)
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view.name + ".png"))
	var file := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "window_size": str(root.size), "preset": preset, "blocks": 6,
		"views": views, "scope": "spawn uses real ChaseCamera/HUD; other views are static with fog and distance culling disabled; no FPS or human approval"}, "\t"))
	world.queue_free()
	await process_frame
	# Preview generation must not leave the player with its capture preset.
	settings.graphics = previous_graphics
	settings.save_settings()
	print("Pilot city previews: " + output)
	quit()
