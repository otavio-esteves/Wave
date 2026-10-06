extends SceneTree

const WORLD := "res://scenes/world/drive_streamed_corridor.tscn"
var failed := false
var legs: Array[Dictionary] = []
var rss_samples: Array[Dictionary] = []
var startup: Node
var capture_enabled := true
var capture_node: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Streaming benchmark requires a rendered display")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset("legacy")
	if "--no-vsync" in args:
		settings.set_graphics("vsync", false)
	root.unresizable = true
	startup = Node.new()
	startup.set_script(preload("res://scripts/tools/startup_observer.gd"))
	root.add_child(startup)
	change_scene_to_file(WORLD)
	for frame in 10:
		await process_frame
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	var hlod: WorldHLOD = world.get_node("Distant")
	hlod.enabled = "--no-hlod" not in args
	hlod.update_representation()
	var capture := world.get_node("PerformanceCapture")
	capture_node = capture
	capture_enabled = "--no-capture" not in args
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "camera_view", "camera_back", "pause"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	if "--foreground" in args:
		root.grab_focus()
	await create_timer(10.0).timeout
	settings.apply_graphics()
	await create_timer(0.3).timeout
	if root.size != Vector2i(1280, 720) or streamer.blocked:
		push_error("Streaming benchmark requires native 720p and startup support")
		quit(1)
		return
	var target := 220.0 if "--speed-220" in args else 120.0
	var round_trip := "--round-trip" in args
	var cycles := 3 if "--three-cycles" in args else 1
	for argument in args:
		if argument.begins_with("--cycles="):
			cycles = argument.trim_prefix("--cycles=").to_int()
	if cycles < 1 or cycles > 6:
		push_error("Diagnostic cycles must be in 1..6")
		quit(1)
		return
	var startup_only := "--startup-only" in args
	var start_usec := Time.get_ticks_usec()
	capture.measure_render_time = "--profile-render-time" in args
	capture.benchmark_metadata = {"route_id": "vale-streaming-hlod-v1", "hlod_enabled": hlod.enabled, "seed": 5547, "target_kmh": target, "warmup_seconds": 10, "round_trip": round_trip, "cycles": cycles, "scripted_turnaround": round_trip, "screenshots_during_capture": false, "vehicle_top_speed_kmh": car.forward_speed * 3.6}
	_rss("before_capture", start_usec)
	streamer.mark("capture_start")
	if capture_enabled and not startup_only:
		capture.toggle()
	for cycle in (0 if startup_only else cycles):
		if cycle > 0:
			world.teleport_to(Vector3(3.5, 0.36, 24))
			await _support(streamer)
		await _drive(car, streamer, target, false, start_usec)
		if round_trip:
			# Diagnostic turn at the same position; input-driven travel on each leg.
			world.teleport_to(Vector3(3.5, 0.36, -580), PI)
			await _support(streamer)
			await _drive(car, streamer, target, true, start_usec)
	streamer.mark("capture_end")
	capture.finish()
	_rss("after_capture_finish", start_usec)
	var file := FileAccess.open("user://streaming.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "hlod": hlod.snapshot(), "startup": startup.snapshot(), "capture_enabled": capture_enabled and not startup_only, "capture_buffer": capture.buffer_statistics(), "capture_path": capture.last_capture_path, "target_kmh": target, "cycles": cycles, "round_trip": round_trip, "legs": legs, "rss_samples": rss_samples, "rss_scope": "Linux process VmRSS snapshots at leg endpoints; not per-frame cost, VRAM or an 8 GB certification", "streaming": streamer.snapshot(), "route_passed": not failed}, "\t") + "\n")
	file.close()
	print("Streaming route: passed=%s legs=%d resident=%d peak=%d releases=%d" % [not failed, legs.size(), streamer.resident_count(), streamer.peak_resident_cells, streamer.released_cells])
	startup.queue_free()
	world.queue_free()
	await process_frame
	for frame in 600:
		await process_frame
		if get_nodes_in_group("world_load_drain").is_empty():
			break
	await create_timer(0.2).timeout
	quit(1 if failed else 0)


func _drive(car: PlayerCar, streamer: WorldStreamer, target: float, returning: bool, start_usec: int) -> void:
	var holds := streamer.blocking_events
	var started := Time.get_ticks_msec()
	var grounded := true
	var maximum_speed := 0.0
	while Time.get_ticks_msec() - started < 60000:
		Input.action_release("accelerate")
		Input.action_release("brake")
		if car.get_speed_kmh() < target - 1:
			Input.action_press("accelerate", 0.7 if target < 200 else 1.0)
		elif car.get_speed_kmh() > target + 1:
			Input.action_press("brake", 0.3)
		await physics_frame
		await process_frame
		grounded = grounded and car.is_on_floor()
		maximum_speed = maxf(maximum_speed, car.get_speed_kmh())
		if (returning and car.position.z > 20) or (not returning and car.position.z < -580):
			break
	Input.action_release("accelerate")
	Input.action_release("brake")
	var reached := car.position.z > 20 if returning else car.position.z < -580
	var success := reached and grounded and streamer.blocking_events == holds and streamer.failure_count == 0 and absf(car.position.x - 3.5) < 0.2 and maximum_speed >= target - 2
	failed = failed or not success
	legs.append({"returning": returning, "passed": success, "grounded": grounded, "max_speed_kmh": maximum_speed, "safety_holds": streamer.blocking_events - holds, "end_position": [car.position.x, car.position.y, car.position.z], "elapsed_seconds": (Time.get_ticks_usec() - start_usec) / 1000000.0, "states": streamer.snapshot().states})
	_rss("return_end" if returning else "outward_end", start_usec)


func _support(streamer: WorldStreamer) -> void:
	var started := Time.get_ticks_msec()
	while streamer.blocked and Time.get_ticks_msec() - started < 15000:
		await process_frame
	if streamer.blocked:
		failed = true


func _rss(phase: String, start_usec: int) -> void:
	var started := Time.get_ticks_usec()
	var bytes: Variant = null
	if FileAccess.file_exists("/proc/self/status"):
		var file := FileAccess.open("/proc/self/status", FileAccess.READ)
		while file != null and not file.eof_reached():
			var line := file.get_line()
			if line.begins_with("VmRSS:"):
				bytes = line.trim_prefix("VmRSS:").strip_edges().split(" ", false)[0].to_int() * 1024
				break
	rss_samples.append({"phase": phase, "elapsed_seconds": (Time.get_ticks_usec() - start_usec) / 1000000.0, "read_cpu_ms": (Time.get_ticks_usec() - started) / 1000.0, "bytes": bytes, "resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "static_memory_bytes": OS.get_static_memory_usage(), "render_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "capture_buffer": capture_node.buffer_statistics()})
