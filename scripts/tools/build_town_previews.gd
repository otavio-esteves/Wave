extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Town previews require a rendered window; this tool does not benchmark FPS")
		quit(1)
		return
	var output := "res://builds/previews/town"
	var cell_path := ""
	var region := "town"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--cell="):
			cell_path = argument.trim_prefix("--cell=")
		if argument.begins_with("--region="):
			region = argument.trim_prefix("--region=")
	if region not in ["rural", "highway", "town"]:
		push_error("Preview region must be rural, highway or town")
		quit(1)
		return
	var index: int = {"rural": 1, "highway": 2, "town": 3}[region]
	if cell_path.is_empty():
		cell_path = "res://scenes/world/cells/sol-serra/cell-%d.tscn" % index
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_node("WaveSettings").set_graphics_preset("economy")
	# Reuse the journey's actual sky/sun without running its streaming or capture.
	var template: Node3D = load("res://scenes/world/drive_intercity.tscn").instantiate()
	var stage := Node3D.new()
	root.add_child(stage)
	for name in ["WorldEnvironment", "Sun"]:
		var node := template.get_node(NodePath(name))
		template.remove_child(node)
		node.owner = null
		stage.add_child(node)
	stage.get_node("Sun").shadow_enabled = false
	template.free()
	var town: Node3D = load(cell_path).instantiate()
	stage.add_child(town)
	var horizon: Node3D = load("res://scenes/world/cells/sol-serra/horizon.tscn").instantiate()
	horizon.position.z = 200 + (index - 1) * 400
	stage.add_child(horizon)
	var car: PlayerCar = load("res://scenes/cars/player_car.tscn").instantiate()
	car.position = Vector3(3.5, 0.36, -205)
	car.position.x = preload("res://scripts/world/intercity_layout.gd").point(-horizon.position.z - 205).x
	if region == "highway":
		car.position = Vector3(20, 0.36, -210)
	stage.add_child(car)
	car.set_physics_process(false)
	var camera := Camera3D.new()
	camera.near = 0.05
	camera.far = 1500
	camera.fov = 65
	stage.add_child(camera)
	camera.current = true
	var views := [
		{"name": "approach", "position": Vector3(3.5, 2.8, -42), "target": Vector3(0, 1.8, -150)},
		{"name": "square", "position": Vector3(24, 12, -205), "target": Vector3(-28, 1, -242)},
		{"name": "main-street", "position": Vector3(-4, 3.5, -195), "target": Vector3(13, 2, -306)},
	]
	if region == "rural":
		views = [{"name": "rural-stop", "position": Vector3(16, 7, -70), "target": Vector3(-24, 1, -103)},
			{"name": "stop-approach", "position": Vector3(4, 1.8, -30), "target": Vector3(4, 2.3, -72)},
			{"name": "rural-road", "position": Vector3(9, 2.8, -180), "target": Vector3(14, 1.8, -290)}]
		var layout = preload("res://scripts/world/intercity_layout.gd")
		views.append({"name": "rural-wayfinding", "position": Vector3(layout.center_x(-500) + 3.5, 2.4, -300), "target": Vector3(layout.center_x(-540) + 10, 2.75, -340)})
	elif region == "highway":
		var layout = preload("res://scripts/world/intercity_layout.gd")
		views = [{"name": "refuge", "position": Vector3(-13, 6, -155), "target": Vector3(25, 1, -210)},
			{"name": "stop-return", "position": Vector3(layout.center_x(-905) - 3.5, 1.8, -305), "target": Vector3(layout.center_x(-860) - 3.5, 2.3, -260)},
			{"name": "highway-arrival", "position": Vector3(-6, 2.8, -300), "target": Vector3(0, 1.8, -390)}]
		views.append({"name": "stop-sign", "position": Vector3(layout.center_x(-700) + 3.5, 2.4, -100), "target": Vector3(layout.center_x(-742) + 10, 2.75, -142)})
	else:
		views.append({"name": "village-sign", "position": Vector3(3.5, 2.4, -2), "target": Vector3(11, 2.75, -22)})
		views.append({"name": "square-approach", "position": Vector3(3.5, 1.8, -178), "target": Vector3(3.5, 2.3, -230)})
		views.append({"name": "square-return", "position": Vector3(-3.5, 1.8, -306), "target": Vector3(-3.5, 2.3, -254)})
	for view in views:
		camera.position = view.position
		camera.look_at(view.target)
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view.name + ".png"))
	var file := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"cell": cell_path, "region": region, "preset": "economy", "window_size": str(root.size),
		"gpu": RenderingServer.get_video_adapter_name(), "views": views,
		"inventory": _inventory(town),
		"scope": "fixed art views, no capture, no performance conclusion; standalone region detail with journey sky/sun"}, "\t"))
	file.close()
	stage.queue_free()
	await process_frame
	print("Town previews saved: " + ProjectSettings.globalize_path(output))
	quit()


func _inventory(town: Node3D) -> Dictionary:
	var counts := {"direct_children": town.get_child_count(), "batches": 0, "instances": 0,
		"tree_cards": 0, "surface_meshes": 0, "colliders": town.get_node("Colliders").get_child_count()}
	for child in town.get_children():
		if child is MultiMeshInstance3D:
			counts.batches += 1
			counts.instances += child.multimesh.instance_count
			if child.material_override.resource_name == "street_tree":
				counts.tree_cards += child.multimesh.instance_count
		elif child is MeshInstance3D:
			counts.surface_meshes += 1
	return counts
