extends SceneTree

const Layout = preload("res://scripts/race/circuit_layout.gd")
const RACE := "res://scenes/race/drive_race.tscn"
var checks := 0
var failures := 0
var world: Node3D
var car: PlayerCar
var timing: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file(RACE)
	await _frames(10)
	world = current_scene
	car = world.get_node("PlayerCar")
	timing = world.get_node("RaceTiming")
	_check(car.is_on_floor() and not timing.active, "race spawn is grounded behind the start line")
	var route: PackedVector3Array = timing.route
	_check(Layout.length_m(route) > 1200.0 and Layout.length_m(route) < 1300.0, "closed circuit has at least 1.2 km of continuous driving")
	_check(route[0].distance_to(route[-1]) < 7.0 and timing.checkpoints.size() == 16, "circuit closes with sixteen ordered checkpoints")
	var marker: Transform3D = timing.checkpoints[0]
	var forward := -marker.basis.z
	_check(not timing._crossed(marker, marker.origin + forward, marker.origin - forward), "crossing finish in reverse cannot start or finish a lap")
	_check(not timing._crossed(marker, marker.origin - forward + marker.basis.x * 15, marker.origin + forward + marker.basis.x * 15), "crossing beside the track cannot count as a checkpoint")
	var capture := world.get_node("PerformanceCapture")
	if DisplayServer.get_name() != "headless":
		root.get_node("WaveSettings").set_economy_mode()
		await create_timer(5.0).timeout
		capture.toggle()
	# Drive the actual car around the entire saved circuit through normal controls.
	car.forward_speed = 12.0
	var waypoint := 0
	var nearest := INF
	for index in route.size():
		var distance := route[index].distance_squared_to(Vector3(car.position.x, 0, car.position.z))
		if distance < nearest:
			nearest = distance
			waypoint = index + 2
	var finished := false
	var max_road_error := 0.0
	for frame in 9000:
		var point := route[waypoint % route.size()]
		var offset := point - car.position
		if Vector2(offset.x, offset.z).length() < 5.0:
			waypoint += 1
			point = route[waypoint % route.size()]
			offset = point - car.position
		var desired := atan2(-offset.x, -offset.z)
		var error := wrapf(desired - car.get_heading(), -PI, PI)
		var steer := clampf(-error * 2.0, -1.0, 1.0)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		if steer < 0.0:
			Input.action_press("steer_left", -steer)
		else:
			Input.action_press("steer_right", steer)
		Input.action_press("accelerate")
		await _frames(1)
		max_road_error = maxf(max_road_error, timing._distance_to_road(car.position))
		if timing.completed_laps > 0:
			finished = true
			break
	if capture.recording:
		capture.finish()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://race-lap.png")
	_check(finished, "a full lap driven with the real controller completes all checkpoints")
	_check(max_road_error < Layout.HALF_WIDTH and car.is_on_floor(), "full-lap test remains on asphalt without gaps or obstructing rails")
	_check(timing.best_lap > 90.0 and timing.last_lap == timing.best_lap, "lap timer stores the completed lap and best time")
	for action in ["accelerate", "steer_left", "steer_right"]:
		Input.action_release(action)
	# Cutting the infield invalidates a timed lap, and teleporting cannot complete it.
	car.position = Vector3.ZERO + Vector3.UP * 0.36
	await _frames(3)
	_check(timing.completed_laps == 1 and not timing.active, "teleport cannot award a lap")
	timing.active = true
	await _frames(2)
	_check(not timing.valid_lap, "leaving the asphalt invalidates the current lap")
	car.reset_car()
	_check(not timing.active and timing.elapsed == 0.0 and timing.best_lap > 0.0, "reset clears current run while preserving session best")
	var hud := world.get_node("HUD")
	hud.set_paused(true)
	timing.active = true
	var paused_time: float = timing.elapsed
	await _frames(5)
	_check(timing.elapsed == paused_time, "pause freezes the race timer")
	hud.get_node("Overlay/PauseMenu/Center/Buttons/World").pressed.emit()
	await _frames(10)
	_check(current_scene.scene_file_path == "res://scenes/city/drive_neighborhood.tscn" and not paused, "race pause menu returns to the neighborhood")
	current_scene.get_node("HUD").set_paused(true)
	current_scene.get_node("HUD/Overlay/PauseMenu/Center/Buttons/Race").pressed.emit()
	await _frames(10)
	_check(current_scene.scene_file_path == RACE and not paused, "neighborhood pause menu opens the circuit")
	print("Race smoke test: %d checks, %d failures, max route error %.2f m" % [checks, failures, max_road_error])
	current_scene.queue_free()
	await process_frame
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
