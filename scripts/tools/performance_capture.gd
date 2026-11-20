extends Node

const MAX_SECONDS := 180.0
const Statistics = preload("res://scripts/tools/frame_statistics.gd")
const SAMPLE_COLUMNS := ["elapsed_seconds", "fps", "draw_calls", "rendered_objects", "rendered_primitives", "process_ms", "physics_ms", "static_memory_bytes", "render_memory_bytes", "viewport_cpu_ms", "viewport_gpu_ms", "active_solid_shapes"]
var benchmark_metadata: Dictionary = {}
var measure_render_time := false
var _metadata: Dictionary = {}
var last_summary: Dictionary = {}
var last_capture_path := ""
var recording := false
var elapsed := 0.0
var _sample_time := 0.0
var _last_frame_usec := 0
var _segment_start_frame := -1
var _pending_segments: Array[Dictionary] = []
var _frames: Array[float] = []
var _focused_frames := 0
var _unfocused_frames := 0
var _focus_runs: Array[Dictionary] = []
var _rows: Array[Array] = []
var status := "F4: registrar desempenho"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("performance_capture")


func toggle() -> void:
	if DisplayServer.get_name() == "headless":
		status = "Medição gráfica requer uma janela visível"
		return
	if recording:
		finish()
	else:
		_start(Time.get_ticks_usec(), Time.get_unix_time_from_system())


# The route enters and leaves each section in SceneTree.process_frame, before
# this node's _process. Both sections share the same frame boundary.
func start_segment(boundary_usec: int, unix_seconds: float) -> void:
	_segment_start_frame = Engine.get_process_frames()
	_start(boundary_usec, unix_seconds)


func finish_segment(boundary_usec: int) -> void:
	if recording and Engine.get_process_frames() != _segment_start_frame:
		_record_interval(boundary_usec)
	finish()


func flush_segments() -> Array[String]:
	var paths: Array[String] = []
	for segment in _pending_segments:
		_save_capture(segment)
		paths.append(last_capture_path)
	_pending_segments.clear()
	return paths


func _start(start_usec: int, unix_seconds: float) -> void:
	recording = true
	elapsed = 0.0
	_sample_time = 0.0
	_last_frame_usec = start_usec
	# Detach from any completed sections awaiting serialization.
	_frames = []
	_focused_frames = 0
	_unfocused_frames = 0
	_rows = []
	_focus_runs = []
	last_summary = {}
	last_capture_path = ""
	_metadata = {
		"schema_version": 3,
		"capture_started_unix_seconds": unix_seconds,
		"fps_limit": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"world": get_parent().get("world_title"), "engine": Engine.get_version_info()["string"],
		"os": OS.get_name(), "cpu": OS.get_processor_name(), "cpu_threads": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"window_size": str(get_tree().root.size),
		"viewport_size": str(get_viewport().get_visible_rect().size),
		"graphics": get_node("/root/WaveSettings").graphics.duplicate(),
		"preset": get_node("/root/WaveSettings").get_graphics_preset(),
		"debug_build": OS.is_debug_build(),
		"benchmark": benchmark_metadata.duplicate(true),
		"memory_scope": "Godot static allocator and render allocations; not process RSS or total driver VRAM",
		"cpu_scope": "engine process/physics monitors and viewport submission; not gameplay attribution",
		"viewport_timing_enabled": measure_render_time,
	}
	if measure_render_time:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	status = "Gravando · F4 para salvar (máximo 180 s)"


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_last_frame_usec = 0


func _process(_delta: float) -> void:
	if not recording or Engine.get_process_frames() == _segment_start_frame:
		return
	if _metadata.has("window_size") and str(get_tree().root.size) != _metadata["window_size"]:
		# A manual desktop resize must not mix resolutions in the same capture.
		finish()
		return
	_record_interval(Time.get_ticks_usec())
	if elapsed >= MAX_SECONDS:
		finish()


func _record_interval(now: int) -> void:
	if _last_frame_usec == 0:
		_last_frame_usec = now
		return
	if now <= _last_frame_usec:
		return
	# Engine delta can be capped by max physics steps, hiding slow GPU frames.
	var delta := float(now - _last_frame_usec) / 1000000.0
	_last_frame_usec = now
	elapsed += delta
	_sample_time += delta
	_frames.append(delta * 1000.0)
	var focused := get_tree().root.has_focus()
	if _focus_runs.is_empty() or _focus_runs.back().focused != focused:
		_focus_runs.append({"first_frame": _frames.size() - 1, "focused": focused})
	if focused:
		_focused_frames += 1
	else:
		_unfocused_frames += 1
	if _sample_time >= 0.5:
		var city_physics := get_parent().get_node_or_null("CityPhysics")
		_rows.append([snappedf(elapsed, 0.01), Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			_available(Performance.get_monitor(Performance.MEMORY_STATIC)),
			_available(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
			_render_time(false), _render_time(true), city_physics.active_shapes if city_physics != null else null])
		_sample_time = 0.0


func finish() -> void:
	if not recording:
		return
	recording = false
	var segmented := _segment_start_frame >= 0
	_segment_start_frame = -1
	if measure_render_time and is_inside_tree():
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	if _frames.is_empty():
		status = "Sem quadros para salvar"
		return
	var snapshot := {
		"stamp": "%s-%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()],
		"metadata": _metadata, "frames": _frames, "rows": _rows, "duration": elapsed,
		"focused": _focused_frames, "unfocused": _unfocused_frames, "focus_runs": _focus_runs,
	}
	if segmented:
		_pending_segments.append(snapshot)
	else:
		_save_capture(snapshot)


func _save_capture(snapshot: Dictionary) -> void:
	last_capture_path = ""
	last_summary = {}
	var folder := "user://performance"
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if error != OK:
		status = "Não foi possível criar a pasta de medições"
		push_error(status)
		return
	var base := folder.path_join(snapshot.stamp)
	var csv := FileAccess.open(base + ".csv", FileAccess.WRITE)
	if csv == null:
		status = "Não foi possível salvar a medição"
		push_error(status)
		return
	csv.store_csv_line(PackedStringArray(SAMPLE_COLUMNS))
	for row: Array in snapshot.rows:
		var values := PackedStringArray()
		for value: Variant in row:
			values.append("" if value == null else str(value))
		csv.store_csv_line(values)
	csv.close()
	var frame_csv := FileAccess.open(base + "-frames.csv", FileAccess.WRITE)
	if frame_csv == null:
		status = "Amostras salvas; falha ao salvar intervalos de quadros"
		push_error(status)
		return
	frame_csv.store_csv_line(PackedStringArray(["frame", "elapsed_seconds", "frame_ms"]))
	var frames: Array[float] = snapshot.frames
	var frame_elapsed := 0.0
	for index in frames.size():
		frame_elapsed += frames[index] / 1000.0
		frame_csv.store_csv_line(PackedStringArray([str(index), str(frame_elapsed), str(frames[index])]))
	frame_csv.close()
	var summary: Dictionary = snapshot.metadata.duplicate(true)
	summary.merge(Statistics.summarize(frames), true)
	summary.merge({"duration_seconds": snapshot.duration, "frames": frames.size(), "time_source": "monotonic_wall_clock"})
	var monitors: Dictionary = {}
	for column in range(1, SAMPLE_COLUMNS.size()):
		var total := 0.0
		var peak := 0.0
		var minimum := INF
		var count := 0
		for row: Array in snapshot.rows:
			if row[column] == null:
				continue
			var value: float = row[column]
			total += value
			peak = maxf(peak, value)
			minimum = minf(minimum, value)
			count += 1
		monitors[SAMPLE_COLUMNS[column]] = {"mean": total / count, "max": peak, "min": minimum, "samples": count} if count > 0 else null
	summary["sampled_monitors"] = monitors
	summary["window_focus"] = {"focused_frames": snapshot.focused, "unfocused_frames": snapshot.unfocused, "runs": snapshot.focus_runs.duplicate(true), "scope": "focus observed at interval end; runs start at zero-based CSV frame; not occlusion or GPU utilization"}
	var json := FileAccess.open(base + ".json", FileAccess.WRITE)
	if json == null:
		status = "CSV salvo; falha ao salvar resumo"
		push_error(status)
		return
	json.store_string(JSON.stringify(summary, "\t"))
	json.close()
	last_summary = summary
	last_capture_path = base
	status = "Medição salva em user://performance"
	print("Performance capture: " + ProjectSettings.globalize_path(base))


func _available(value: float) -> Variant:
	# Several monitors return zero when unavailable on a renderer/release build.
	return value if value > 0.0 else null


func _render_time(gpu: bool) -> Variant:
	if not measure_render_time:
		return null
	var viewport := get_viewport().get_viewport_rid()
	var value := RenderingServer.viewport_get_measured_render_time_gpu(viewport) if gpu else RenderingServer.viewport_get_measured_render_time_cpu(viewport)
	# Some legacy drivers return an unsigned timer-query underflow. A time larger
	# than the entire maximum capture cannot be a usable viewport frame timing.
	return _available(value) if is_finite(value) and value <= MAX_SECONDS * 1000.0 else null


func _exit_tree() -> void:
	finish()


func buffer_statistics() -> Dictionary:
	return {"recording": recording, "frames": _frames.size(), "sample_rows": _rows.size()}
