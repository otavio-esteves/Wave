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
	var cycle := world.get_node("DayNightCycle")
	cycle.running = false
	cycle.set_hour(16.5)
	world.get_node("PlayerCar").set_physics_process(false)
	world.get_node("HUD/Overlay").hide()
	var camera := Camera3D.new()
	camera.far = 2400
	camera.near = 0.1
	world.add_child(camera)
	camera.current = true
	var views := [
		{"name": "overview", "position": Vector3(35, 260, 280), "target": Vector3(0, 5, 0), "fov": 58.0},
		{"name": "expanded-overview", "position": Vector3(40, 930, 940), "target": Vector3(0, 5, 0), "fov": 65.0},
		{"name": "valley", "position": Layout.position(-420, 180, 14), "target": Layout.position(-400, 70, 3), "fov": 62.0},
		{"name": "eastern-hill", "position": Layout.position(445, 40, 17), "target": Layout.position(440, -80, 4), "fov": 62.0},
		{"name": "centre", "position": Layout.position(50, 115, 12), "target": Layout.position(60, -10, 2), "fov": 60.0},
		{"name": "hill", "position": Layout.node(22) + Vector3(-12, 5, 12), "target": Layout.node(35) + Vector3.UP * 2, "fov": 65.0},
	]
	var player: Node3D = world.get_node("PlayerCar")
	views.append({"name": "car-street", "position": player.global_position + Vector3(4.6, 2.6, -5.8), "target": player.global_position + Vector3.UP * 0.5, "fov": 38.0})
	views.append({"name": "car-rear", "position": player.global_position + player.global_basis * Vector3(3.6, 1.7, 4.8), "target": player.global_position + Vector3.UP * 0.5, "fov": 38.0})
	views.append({"name": "car-front", "position": player.global_position + player.global_basis * Vector3(-3.6, 1.7, -4.8), "target": player.global_position + Vector3.UP * 0.5, "fov": 38.0})
	views.append({"name": "car-braking", "position": player.global_position + player.global_basis * Vector3(3.6, 1.7, 4.8), "target": player.global_position + Vector3.UP * 0.5, "fov": 38.0})
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
		if view.name == "car-braking":
			player.velocity = Vector3.ZERO
			player.drive_speed = 0.0
			Input.action_press("brake")
			player.set_physics_process(true)
			for frame in 3:
				await physics_frame
				await process_frame
			player.set_physics_process(false)
			Input.action_release("brake")
		camera.near = 5.0 if "overview" in view.name else 0.1
		camera.position = view.position
		camera.fov = view.fov
		camera.look_at(view.target)
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view.name + ".png"))
	# Same driving camera and scene, inspected at real cycle phases.
	camera.position = player.global_position + player.global_basis * Vector3(4.6, 3.0, 3.5)
	camera.fov = 62.0
	camera.look_at(player.global_position + player.global_basis * Vector3(0, 0, -12))
	for phase in [{"name": "dawn", "hour": 6.25}, {"name": "day", "hour": 12.0}, {"name": "sunset", "hour": 18.0}, {"name": "night", "hour": 23.0}]:
		cycle.set_hour(phase.hour)
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(phase.name + ".png"))
	cycle.set_hour(23.0)
	camera.position = player.global_position + Vector3.UP * 3
	camera.fov = 75.0
	camera.look_at(camera.position - cycle.sun_direction, Vector3.FORWARD)
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("moon-stars.png"))
	cycle.set_hour(23.0)
	# Headlight comparison uses the normal playable nighttime lighting.
	camera.position = player.global_position + player.global_basis * Vector3(4.6, 3.0, 3.5)
	camera.fov = 62.0
	camera.look_at(player.global_position + player.global_basis * Vector3(0, 0, -12))
	for enabled in [true, false]:
		player.headlights_on = enabled
		player._update_lamps()
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("headlights-%s.png" % ("on" if enabled else "off")))
	var file := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "window_size": str(root.size), "preset": preset, "blocks": Layout.BLOCK_COUNT, "area_m2": Layout.HALF_WIDTH * Layout.HALF_DEPTH * 4,
		"views": views, "scope": "spawn uses real ChaseCamera/HUD; other views are static with fog and distance culling disabled; phase images and headlights use the implemented day/night cycle with the clock held for capture; no FPS or human approval"}, "\t"))
	world.queue_free()
	for frame in 5:
		await process_frame
	# Preview generation must not leave the player with its capture preset.
	settings.graphics = previous_graphics
	settings.save_settings()
	print("Pilot city previews: " + output)
	quit()
