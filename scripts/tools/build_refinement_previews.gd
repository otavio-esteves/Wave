extends SceneTree

# Inspect the authored meshes in the playable world, preserving fog and culling.
const Layout = preload("res://scripts/city/pilot_city_layout.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual review requires a rendered window")
		quit(1)
		return
	var output := "res://builds/previews/refinement"
	var preset := "medium"
	var selected := PackedStringArray()
	var no_shadows := false
	var follow_review_camera := false
	var tone_variants := false
	var tone_captures: Array[Dictionary] = []
	var context_note := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--preset="):
			preset = argument.trim_prefix("--preset=")
		if argument.begins_with("--views="):
			selected = argument.trim_prefix("--views=").split(",")
		if argument == "--no-shadows":
			no_shadows = true
		if argument == "--follow-review-camera":
			follow_review_camera = true
		if argument == "--tone-variants":
			tone_variants = true
		if argument.begins_with("--context-note="):
			context_note = argument.trim_prefix("--context-note=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var settings := root.get_node("WaveSettings")
	var previous: Dictionary = settings.graphics.duplicate(true)
	settings.set_graphics_preset(preset)
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
		Input.action_release(action)
	var world := current_scene
	var player: PlayerCar = world.get_node("PlayerCar")
	var rig := world.get_node("ChaseCamera")
	rig.set_process_unhandled_input(false)
	if root.focus_entered.is_connected(rig._capture_mouse):
		root.focus_entered.disconnect(rig._capture_mouse)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cycle := world.get_node("DayNightCycle")
	if no_shadows:
		world.get_node("Sun").shadow_enabled = false
	cycle.running = false
	cycle.set_hour(16.5)
	for frame in 12:
		await physics_frame
		await process_frame
	player.set_physics_process(false)
	var hero_transform := player.global_transform
	var hero_shadow_visible: bool = player.get_node("ContactShadow").visible
	var reflection := world.get_node_or_null("VehicleReflection") as ReflectionProbe
	var hero_reflections_enabled := reflection != null and reflection.visible
	if selected.is_empty() or "driving" in selected:
		await _capture(output, "driving")
		if tone_variants:
			var environment := world.get_node("WorldEnvironment").environment as Environment
			var original_mode := environment.tonemap_mode
			for variant in [["linear", Environment.TONE_MAPPER_LINEAR], ["filmic", Environment.TONE_MAPPER_FILMIC], ["aces", Environment.TONE_MAPPER_ACES]]:
				environment.tonemap_mode = variant[1]
				var label := "driving-tone-" + str(variant[0])
				await _capture(output, label, false, 4)
				tone_captures.append({"capture": label, "mode": variant[1], "exposure": environment.tonemap_exposure, "contrast": environment.adjustment_contrast, "saturation": environment.adjustment_saturation})
			environment.tonemap_mode = original_mode
	world.get_node("HUD/Overlay").hide()
	var camera := Camera3D.new()
	camera.far = 5000
	world.add_child(camera)
	camera.current = true
	var views: Array[Dictionary] = []
	for item in [{"name": "car-front", "position": Vector3(-3.4, 1.45, -4.6)}, {"name": "car-rear", "position": Vector3(3.4, 1.45, 4.6)}, {"name": "car-side", "position": Vector3(-5.8, 1.3, 0.0)}, {"name": "car-detail", "position": Vector3(-2.4, 0.8, -2.9)}]:
		views.append({"name": item.name, "position": player.global_position + player.global_basis * item.position, "target": player.global_position + Vector3.UP * 0.5, "fov": 43.0})
	var addresses := world.get_node("City").find_children("Address*", "Node3D", false, false)
	addresses.sort_custom(func(a, b): return a.position.distance_squared_to(player.position) < b.position.distance_squared_to(player.position))
	for index in mini(3, addresses.size()):
		var address: Node3D = addresses[index]
		var basis := Basis(Vector3.UP, address.rotation.y)
		views.append({"name": "residence-%d" % index, "position": address.position + basis * Vector3(9, 1.9, 14), "target": address.position + basis * Vector3(-3, 1.5, -5), "fov": 58.0})
	var benches: Array = world.get_node("City").get_meta("review_benches", [])
	if not benches.is_empty():
		var bench: Dictionary = benches[0]
		var basis := Basis(Vector3.UP, bench.yaw)
		views.append({"name": "street-furniture", "position": bench.position + basis * Vector3(3.6, 1.8, 4.8), "target": bench.position + Vector3.UP * 0.6, "fov": 56.0})
	views.append({"name": "aurora", "position": Layout.position(145, 315, 3.2), "target": Layout.position(150, 265, 3), "fov": 64.0})
	views.append({"name": "gardens", "position": Layout.position(-840, -210, 3.2), "target": Layout.position(-870, -370, 3), "fov": 64.0})
	views.append({"name": "downtown", "position": Layout.position(941, 90, 3.2), "target": Layout.position(946, -160, 15), "fov": 64.0})
	for view in views:
		if not selected.is_empty() and view.name not in selected:
			continue
		camera.position = view.position
		camera.fov = view.fov
		camera.look_at(view.target)
		if follow_review_camera:
			var urban_view: bool = view.name in ["aurora", "gardens", "downtown"] or str(view.name).begins_with("residence-") or view.name == "street-furniture"
			player.global_transform = hero_transform
			player.get_node("Visuals").visible = not urban_view
			player.get_node("ContactShadow").visible = hero_shadow_visible and not urban_view
			_set_review_reflections(world, hero_reflections_enabled and not urban_view)
			if urban_view:
				player.global_position = view.position - Vector3.UP * 2.0
			_refresh_proximity(world)
		# Normal review keeps selection on the player. An urban review can move
		# that selector to the filmed district, matching a player actually there.
		await _capture(output, view.name)
	player.global_transform = hero_transform
	player.get_node("Visuals").show()
	player.get_node("ContactShadow").visible = hero_shadow_visible
	_set_review_reflections(world, hero_reflections_enabled)
	_refresh_proximity(world)
	camera.position = player.global_position + player.global_basis * Vector3(-3.4, 1.45, -4.6)
	camera.fov = 43
	camera.look_at(player.global_position + Vector3.UP * 0.5)
	for phase in [{"name": "car-day", "hour": 12.0}, {"name": "car-night", "hour": 23.0}]:
		if not selected.is_empty() and phase.name not in selected:
			continue
		cycle.set_hour(phase.hour)
		await _capture(output, phase.name)
	var context := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	context.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "preset": preset, "graphics": settings.graphics.duplicate(true), "resolution": str(root.size), "blocks": Layout.BLOCK_COUNT, "views": views, "selected_views": selected, "diagnostic_no_shadows": no_shadows, "selection_follows_review_camera": follow_review_camera, "surface_finish_revision": world.get_node("City").get_meta("surface_finish_revision", "authored"), "tone_variants": tone_captures, "concurrency_note": context_note, "scope": "Static visual review, playable fog and ranges; no performance or human approval. Shadow disabling, tone variants and camera-following proximity selection are explicitly marked when requested."}, "\t"))
	context.close()
	world.queue_free()
	for frame in 5:
		await process_frame
	settings.graphics = previous
	settings.save_settings()
	print("Visual review: " + output)
	# Match the game's audio shutdown path, after releasing the reviewed world.
	# Leaving from a frame callback without the stop fade can stall a driver.
	await settings.quit_game()


func _refresh_proximity(world: Node) -> void:
	for name in ["CityPhysics", "CityVisualLOD", "CityFoliageLOD"]:
		var system := world.get_node_or_null(NodePath(name))
		if system != null and system.has_method("refresh"):
			system.refresh()


func _set_review_reflections(world: Node, enabled: bool) -> void:
	var reflection := world.get_node_or_null("VehicleReflection") as ReflectionProbe
	if reflection != null and reflection.visible != enabled:
		# This probe affects only the hero's dedicated visual layer. Capturing
		# six city faces while that car is hidden cannot change an urban review.
		reflection.set_enabled(enabled)

func _capture(output: String, label: String, refresh_reflection: bool = true, settle_frames: int = 16) -> void:
	if refresh_reflection and current_scene != null and current_scene.has_node("VehicleReflection"):
		current_scene.get_node("VehicleReflection").refresh()
	for frame in settle_frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if error != OK:
		push_error("Capture failed: " + error_string(error))
		quit(1)
