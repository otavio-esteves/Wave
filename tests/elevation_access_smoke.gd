extends "res://tests/elevation_smoke.gd"


func _run() -> void:
	change_scene_to_file(WORLD)
	await scene_changed
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	var z := Layout.LOOKOUT_Z
	for entering in [true, false]:
		var start := Layout.point(z, 3.5 if entering else 21.0)
		var end := Layout.point(z, 21.0 if entering else 3.5)
		world.teleport_to(start, -PI / 2 if entering else PI / 2)
		await _support(streamer)
		await _frames(8)
		var holds := streamer.blocking_events
		var grounded := true
		var arrived := false
		var max_deviation := 0.0
		for frame in 600:
			if (entering and car.position.x >= end.x) or (not entering and car.position.x <= end.x):
				arrived = true
				break
			Input.action_release("accelerate")
			Input.action_release("brake")
			Input.action_press("accelerate" if car.drive_speed < 5 else "brake", 0.5)
			await _frames(1)
			grounded = grounded and car.is_on_floor()
			max_deviation = maxf(max_deviation, absf(car.position.z - z))
		Input.action_release("accelerate")
		Input.action_release("brake")
		_check(arrived and max_deviation < 0.5, "lookout %s is drivable through the open shoulder" % ("entrance" if entering else "exit"))
		_check(grounded and streamer.blocking_events == holds, "lookout %s preserves contact without a streaming hold" % ("entrance" if entering else "exit"))
	var cell: Node3D = streamer.records[1].node
	# Verify the shelter's pillar really blocks a horizontal vehicle-height ray.
	var pillar := cell.get_node("Mirante/Pillar1") as MeshInstance3D
	var center := pillar.global_position
	var query := PhysicsRayQueryParameters3D.create(center - Vector3.RIGHT, center + Vector3.RIGHT, 1, [car.get_rid()])
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	_check(not hit.is_empty() and absf(hit.position.x - center.x + 0.09) < 0.01, "shelter pillar has real obstacle collision outside the parking path")
	query = PhysicsRayQueryParameters3D.create(Vector3(180, 120, z), Vector3(180, -40, z), 1, [car.get_rid()])
	hit = world.get_world_3d().direct_space_state.intersect_ray(query)
	_check(hit.is_empty() and not streamer.has_support(Vector3(180, 50, z)), "distant scenery cannot authorize driving beyond the support bounds")
	_check(streamer.failure_count == 0 and streamer.peak_resident_cells <= 3, "lookout exploration respects the existing residency cap")
	world.queue_free()
	await _frames(5)
	OS.delay_msec(150)
	await _frames(5)
	await create_timer(0.2).timeout
	print("Elevation access: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
