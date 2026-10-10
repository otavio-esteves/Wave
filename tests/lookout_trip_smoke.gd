extends "res://tests/elevation_smoke.gd"


func _run() -> void:
	root.get_node("WaveSettings").set_graphics_preset("economy")
	change_scene_to_file(WORLD)
	await scene_changed
	_isolate_driver_input()
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	var trip := world.get_node("LookoutTrip")
	await _support(streamer)
	await _frames(8)
	_check(trip.state == "driving" and trip.next_gate == 0 and trip.progress.value == 0, "entering the lab starts a fresh optional trip")
	_check(trip.panel.get_global_rect().intersection(world.get_node("HUD/Overlay/Telemetry").get_global_rect()).size == Vector2.ZERO and root.get_visible_rect().encloses(trip.panel.get_global_rect()), "trip panel stays on screen without overlapping telemetry")
	await _capture("start")
	var holds := streamer.blocking_events
	var approach := await _drive(car, -245, false)
	_check(approach.arrived and approach.grounded and trip.next_gate == 2 and trip.state == "driving", "real driving crosses the first two ordered route gates")
	await _drive(car, -286, false, 3.5, 5)
	_check(trip.state == "parking" and trip.next_gate == 3 and trip.parked_seconds == 0, "passing the crest requests parking without awarding roadside arrival")
	await _capture("approach")
	var arrived := await _seek(car, Layout.point(Layout.LOOKOUT_Z, 20))
	_check(arrived and trip.state == "parking" and trip.parked_seconds == 0, "entering the destination while moving does not complete the trip")
	Input.action_press("handbrake")
	await _frames(60)
	_check(trip.parked_seconds > 0 and trip.parked_seconds < trip.PARK_SECONDS, "standing in the parking area starts the arrival dwell")
	var floor := streamer.records[1].node.get_node("Colliders/Support") as CollisionShape3D
	floor.disabled = true
	await _frames(6)
	_check(streamer.blocked and trip.parked_seconds == 0 and trip.state == "parking", "missing physical support cancels dwell without awarding arrival")
	floor.disabled = false
	await _support(streamer)
	await _frames(12)
	_check(not streamer.blocked and trip.parked_seconds > 0 and trip.state == "parking", "restored support starts a fresh arrival dwell")
	var before_pause: float = trip.parked_seconds
	world.get_node("HUD").set_paused(true)
	await _frames(120)
	_check(trip.parked_seconds == before_pause and trip.state == "parking", "pause freezes the arrival dwell")
	world.get_node("HUD").set_paused(false)
	await _frames(180)
	_check(trip.state == "complete" and trip.progress.value == 100 and trip.label.text.contains("ALCANÇADO"), "two seconds parked completes the trip and updates the HUD")
	_check(streamer.blocking_events == holds + 1 and streamer.failure_count == 0, "the live trip holds only for the deliberately removed floor")
	await _capture("arrival")
	Input.action_release("handbrake")
	Input.action_press("accelerate", 0.3)
	await _frames(90)
	Input.action_release("accelerate")
	_check(trip.state == "complete", "exploration after arrival preserves the completed trip")
	Input.action_press("reset_car")
	await _frames(2)
	Input.action_release("reset_car")
	await _support(streamer)
	await _frames(5)
	_check(trip.state == "driving" and trip.next_gate == 0 and trip.parked_seconds == 0 and car.position.distance_to(car.spawn_transform.origin) < 0.1, "R restarts both car and trip")
	world.teleport_to(Layout.point(Layout.LOOKOUT_Z, 20))
	await _support(streamer)
	Input.action_press("handbrake")
	await _frames(180)
	_check(trip.state == "restart" and trip.next_gate == 0 and trip.progress.value == 0, "jumping directly to the parking area cannot award a trip")
	Input.action_release("handbrake")
	world.get_node("HUD").set_paused(true)
	world.get_node("HUD/Overlay/PauseMenu/Center/Buttons/Reset").pressed.emit()
	await _support(streamer)
	await _frames(5)
	_check(not paused and trip.state == "driving" and trip.next_gate == 0, "pause-menu reset restarts the activity and resumes play")
	var shortcut := await _drive(car, -140, false, 12, 10)
	_check(shortcut.arrived and shortcut.grounded and trip.next_gate == 0 and trip.progress.value == 0, "driving outside the road cannot skip the first route gate")
	world.get_node("HUD").set_paused(true)
	world.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(8)
	_check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and not paused and not is_instance_valid(trip), "returning to menu frees the activity and clears pause")
	current_scene.elevation_button.pressed.emit()
	await scene_changed
	await _frames(5)
	_check(current_scene.get_node("LookoutTrip").state == "driving" and current_scene.get_node("LookoutTrip").next_gate == 0, "a new visit begins a fresh session trip")
	current_scene.queue_free()
	await _frames(5)
	OS.delay_msec(150)
	await _frames(5)
	await create_timer(0.2).timeout
	print("Lookout trip: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _capture(label: String) -> void:
	if not "--previews" in OS.get_cmdline_user_args():
		return
	if DisplayServer.get_name() == "headless":
		_check(false, "HUD previews require a rendered window")
		return
	var output := "res://builds/previews/lookout-trip"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))


func _seek(car: PlayerCar, destination: Vector3) -> bool:
	var arrived := false
	for frame in 900:
		var offset := destination - car.position
		if Vector2(offset.x, offset.z).length() < 1:
			arrived = true
			break
		for action in ["steer_left", "steer_right", "accelerate", "brake"]:
			Input.action_release(action)
		var heading := atan2(-offset.x, -offset.z)
		var steering := clampf(-angle_difference(car.get_heading(), heading) * 2, -1, 1)
		Input.action_press("steer_left" if steering < 0 else "steer_right", absf(steering))
		Input.action_press("accelerate" if car.drive_speed < 5 else "brake", 0.5)
		await _frames(1)
	for action in ["steer_left", "steer_right", "accelerate", "brake"]:
		Input.action_release(action)
	return arrived
