extends SceneTree

const WORLD := "res://scenes/world/drive_streamed_corridor.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	Engine.max_fps = 240
	_run.call_deferred()


func _run() -> void:
	var output := "user://hlod-regenerated"
	var error: Error = preload("res://scripts/world/corridor_cells_builder.gd").new().build(output)
	var stored: Node3D = load("res://scenes/world/cells/vale/distant.tscn").instantiate()
	var regenerated: Node3D = load(output + "/distant.tscn").instantiate()
	_check(error == OK and stored.get_child_count() == 3, "offline pipeline saves exactly one distant group per corridor cell")
	var identical := true
	var bounded := true
	var triangles := 0
	for index in 3:
		var group: Node3D = stored.get_child(index)
		var other: Node3D = regenerated.get_child(index)
		var mesh: MeshInstance3D = group.get_node("Silhouette")
		identical = identical and group.position == other.position and mesh.mesh.surface_get_arrays(0) == other.get_node("Silhouette").mesh.surface_get_arrays(0) and group.get_node("Trees").multimesh.instance_transforms == other.get_node("Trees").multimesh.instance_transforms
		bounded = bounded and group.get_child_count() == 2 and mesh.mesh.get_surface_count() == 1 and mesh.material_override.vertex_color_use_as_albedo and mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mesh.material_override.albedo_texture == null
		for child in group.get_children():
			bounded = bounded and child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		triangles += group.get_meta("triangles")
	_check(identical, "regeneration preserves merged geometry colors and tree placements exactly")
	_check(bounded and stored.find_children("*", "CollisionObject3D", true, false).is_empty() and stored.find_children("*", "CollisionShape3D", true, false).is_empty(), "distant groups use two render batches without opaque textures shadows or collision support")
	_check(triangles == 1324, "three distant groups preserve authored silhouettes with 1324 total triangles including trees")
	var serialized := FileAccess.get_file_as_string("res://scenes/world/cells/vale/distant.tscn")
	_check(not serialized.contains("PackedScene") and not serialized.contains("cell-0.tscn") and not serialized.contains("cell-1.tscn") and not serialized.contains("cell-2.tscn"), "distant artifact cannot preload or pin any detailed cell scene")
	stored.free()
	regenerated.free()
	change_scene_to_file(WORLD)
	await scene_changed
	# Physical controller input must not move the stationary HLOD probes.
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "pause", "camera_view", "camera_back", "headlights"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	await _frames(5)
	var world: Node3D = current_scene
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	var hlod: WorldHLOD = world.get_node("Distant")
	await _wait(streamer, "vale-0", true)
	_check(streamer.records[0].node.visible and not hlod.get_node("vale-0").visible and hlod.get_node("vale-1").visible and hlod.get_node("vale-2").visible, "spawn draws detailed current cell and distant unloaded neighbors without overlapping representations")
	world.teleport_to(Vector3(3.5, 0.36, -30))
	await _wait(streamer, "vale-1", true)
	_check(streamer.records[1].node.visible and not hlod.get_node("vale-1").visible, "preloaded neighbor becomes detailed inside the entry distance")
	world.teleport_to(Vector3(3.5, 0.36, -10))
	await _frames(6)
	var inside_band: bool = streamer.records[1].node.visible
	world.teleport_to(Vector3(3.5, 0.36, 10))
	await _frames(6)
	var simplified: bool = not streamer.records[1].node.visible and hlod.get_node("vale-1").visible
	var query := PhysicsRayQueryParameters3D.create(Vector3(3.5, 2, -210), Vector3(3.5, -2, -210))
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	_check(simplified and not hit.is_empty() and streamer.has_support(Vector3(3.5, 0, -210)), "distant rendering leaves actual resident floor collision and streamer support intact")
	world.teleport_to(Vector3(3.5, 0.36, -10))
	await _frames(6)
	var transitions := hlod.transitions
	for z in [-11.0, -9.0, -11.0, -9.0]:
		world.teleport_to(Vector3(3.5, 0.36, z))
		await _frames(3)
	_check(inside_band and not streamer.records[1].node.visible and hlod.transitions == transitions, "hysteresis preserves the previous representation through reversals inside its band")
	world.teleport_to(Vector3(3.5, 0.36, -580), PI)
	await _wait(streamer, "vale-2", true)
	await _wait(streamer, "vale-0", false)
	_check(hlod.get_node("vale-0").visible and not streamer.blocked, "released starting cell retains its distant silhouette while destination supports motion")
	hlod.enabled = false
	hlod.update_representation()
	var disabled: bool = hlod.snapshot().visible_proxies.is_empty()
	for record in streamer.records:
		disabled = disabled and (record.node == null or record.node.visible)
	_check(disabled, "A/B diagnostic disables proxies and restores every resident detailed visual")
	hlod.enabled = true
	hlod.update_representation()
	var distant := world.get_node("Distant")
	world.queue_free()
	await _frames(5)
	_check(not is_instance_valid(distant), "closing world releases all distant representation nodes")
	# Accelerated fixed-fps timers do not give the audio mixer real stop time.
	OS.delay_msec(150)
	await _frames(3)
	for frame in 600:
		await _frames(1)
		if get_nodes_in_group("world_load_drain").is_empty():
			break
	await create_timer(0.2).timeout
	print("HLOD smoke test: %d checks, %d failures" % [checks, failures])
	quit.call_deferred(0 if failures == 0 else 1)


func _wait(streamer: WorldStreamer, id: String, resident: bool) -> void:
	for frame in 600:
		await _frames(1)
		for record in streamer.records:
			if record.id == id and (record.node != null) == resident:
				await _frames(5)
				return
	_check(false, "cell %s residency reaches %s within deadline" % [id, resident])


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		# Fixed-FPS headless simulation must leave wall time for loader workers.
		if DisplayServer.get_name() == "headless":
			OS.delay_usec(4167)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
