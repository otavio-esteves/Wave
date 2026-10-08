extends SceneTree

const Statistics = preload("res://scripts/tools/frame_statistics.gd")
const Capture = preload("res://scripts/tools/performance_capture.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Statistics.summarize([]).is_empty(), "empty capture has no fabricated FPS")
	var frames: Array[float] = [100.0]
	for index in 99:
		frames.append(10.0)
	var original := frames.duplicate()
	var summary: Dictionary = Statistics.summarize(frames)
	_check(frames == original, "statistics preserve chronological frame order")
	_check(is_equal_approx(summary.average_fps, 100000.0 / 1090.0), "average FPS uses frame count divided by actual duration")
	_check(summary.p95_frame_ms == 10.0 and summary.p99_frame_ms == 10.0 and summary.slowest_frame_ms == 100.0, "percentiles and worst frame expose different pacing properties")
	_check(summary.one_percent_low_fps == 10.0 and summary.frames_over_50_ms == 1 and summary.frames_over_33_33_ms == 1, "1 percent low and hitch counts expose an isolated slow frame")
	frames.append(80.0)
	summary = Statistics.summarize(frames)
	_check(is_equal_approx(summary.one_percent_low_fps, 1000.0 / 90.0), "1 percent tail rounds up and averages the slowest intervals")
	var single: Array[float] = [20.0]
	_check(Statistics.summarize(single).one_percent_low_fps == 50.0, "short captures handle a one-frame percentile safely")
	var capture := Node.new()
	capture.set_script(Capture)
	root.add_child(capture)
	capture.set_process(false)
	_check(capture._render_time(true) == null and capture._render_time(false) == null, "normal capture avoids blocking GPU timestamp queries on legacy drivers")
	capture._frames = original
	capture._rows.append([0.5, 90, 100, 80, 5000, 2.0, 1.0, null, 100000, null, null])
	capture._metadata = {"graphics": {"resolution": "1280x720"}, "benchmark": {"route_id": "test-v1"}}
	capture._focused_frames = 99
	capture._unfocused_frames = 1
	capture.elapsed = 1.09
	capture.recording = true
	capture.finish()
	_check(capture.buffer_statistics() == {"recording": false, "frames": 100, "sample_rows": 1}, "memory diagnostics inspect retained capture counts without altering saved intervals")
	var path: String = capture.last_capture_path
	_check(not path.is_empty() and not capture.recording, "capture writes all artifacts and stops recording")
	if not path.is_empty():
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))
		_check(saved.window_focus.focused_frames == 99 and saved.window_focus.unfocused_frames == 1, "capture preserves unfocused intervals instead of silently discarding them")
		_check(saved.benchmark.route_id == "test-v1" and saved.graphics.resolution == "1280x720", "JSON preserves captured configuration and route identity")
		_check(saved.sampled_monitors.viewport_gpu_ms == null and saved.sampled_monitors.static_memory_bytes == null, "unavailable monitors remain null rather than zero cost")
		var file := FileAccess.open(path + "-frames.csv", FileAccess.READ)
		var header := file.get_csv_line()
		var first := file.get_csv_line()
		var second := file.get_csv_line()
		_check(header == PackedStringArray(["frame", "elapsed_seconds", "frame_ms"]) and float(first[2]) == 100.0 and float(second[2]) == 10.0, "raw frame CSV retains hitch location and chronological intervals")
		file.close()
		var content := FileAccess.get_file_as_string(path + ".json")
		capture.finish()
		_check(FileAccess.get_file_as_string(path + ".json") == content, "finishing twice does not overwrite completed capture")
	var window_size := root.size
	capture._metadata["window_size"] = str(window_size)
	capture.recording = true
	root.size = window_size + Vector2i(1, 1)
	capture._process(0.016)
	_check(not capture.recording and capture._frames == original, "manual resizing ends capture before mixing resolutions")
	root.size = window_size
	var settings := root.get_node("WaveSettings")
	var config := ConfigFile.new()
	config.set_value("graphics", "resolution", "1600x900")
	config.set_value("graphics", "shadows", true)
	config.set_value("graphics", "cinematic_effects", true)
	config.save(settings.SETTINGS_PATH)
	settings.reload_settings()
	_check(settings.graphics.resolution == "1600x900" and settings.graphics.shadows and settings.graphics.cinematic_effects and not settings.graphics.post_effects and settings.graphics.fps_limit == 0, "old preferences survive with a safe default for new optional effects")
	settings.set_graphics("fps_limit", 60)
	settings.set_graphics_preset("legacy")
	_check(settings.graphics.fps_limit == 60, "graphics presets preserve the chosen FPS limit")
	var before: Dictionary = settings.graphics.duplicate()
	settings.set_graphics_preset("invalid")
	_check(settings.graphics == before, "unknown preset cannot change saved graphics")
	capture.queue_free()
	await process_frame
	print("Performance smoke test: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
