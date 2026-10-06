extends Node

const MAX_SECONDS := 180.0
const Statistics = preload("res://scripts/tools/frame_statistics.gd")
const SAMPLE_COLUMNS := ["elapsed_seconds", "fps", "draw_calls", "rendered_objects", "rendered_primitives", "process_ms", "physics_ms", "static_memory_bytes", "render_memory_bytes", "viewport_cpu_ms", "viewport_gpu_ms"]
var benchmark_metadata: Dictionary = {}
var measure_render_time := false
var _metadata: Dictionary = {}
var last_summary: Dictionary = {}
var last_capture_path := ""
var recording := false
var elapsed := 0.0
var _sample_time := 0.0
var _last_frame_usec := 0
var _frames: Array[float] = []
var _focused_frames := 0
var _unfocused_frames := 0
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
		recording = true
		elapsed = 0.0
		_sample_time = 0.0
		_last_frame_usec = Time.get_ticks_usec()
		_frames.clear()
		_focused_frames = 0
		_unfocused_frames = 0
		_rows.clear()
		last_summary = {}
		last_capture_path = ""
		_metadata = {
			"schema_version": 2,
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
	if not recording:
		return
	if _metadata.has("window_size") and str(get_tree().root.size) != _metadata["window_size"]:
		# A manual desktop resize must not mix resolutions in the same capture.
		finish()
		return
	var now := Time.get_ticks_usec()
	if _last_frame_usec == 0:
		_last_frame_usec = now
		return
	# Engine delta can be capped by max physics steps, hiding slow GPU frames.
	var delta := float(now - _last_frame_usec) / 1000000.0
	_last_frame_usec = now
	elapsed += delta
	_sample_time += delta
	_frames.append(delta * 1000.0)
	if get_tree().root.has_focus():
		_focused_frames += 1
	else:
		_unfocused_frames += 1
	if _sample_time >= 0.5:
		_rows.append([snappedf(elapsed, 0.01), Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			_available(Performance.get_monitor(Performance.MEMORY_STATIC)),
			_available(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
			_render_time(false), _render_time(true)])
		_sample_time = 0.0
	if elapsed >= MAX_SECONDS:
		finish()


func finish() -> void:
	if not recording:
		return
	recording = false
	if measure_render_time and is_inside_tree():
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	if _frames.is_empty():
		status = "Sem quadros para salvar"
		return
	var folder := "user://performance"
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if error != OK:
		status = "Não foi possível criar a pasta de medições"
		push_error(status)
		return
	var stamp := "%s-%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()]
	var base := folder.path_join(stamp)
	var csv := FileAccess.open(base + ".csv", FileAccess.WRITE)
	if csv == null:
		status = "Não foi possível salvar a medição"
		push_error(status)
		return
	csv.store_csv_line(PackedStringArray(SAMPLE_COLUMNS))
	for row in _rows:
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
	var frame_elapsed := 0.0
	for index in _frames.size():
		frame_elapsed += _frames[index] / 1000.0
		frame_csv.store_csv_line(PackedStringArray([str(index), str(frame_elapsed), str(_frames[index])]))
	frame_csv.close()
	var summary := _metadata.duplicate(true)
	summary.merge(Statistics.summarize(_frames), true)
	summary.merge({"duration_seconds": elapsed, "frames": _frames.size(), "time_source": "monotonic_wall_clock"})
	var monitors: Dictionary = {}
	for column in range(1, SAMPLE_COLUMNS.size()):
		var total := 0.0
		var peak := 0.0
		var minimum := INF
		var count := 0
		for row in _rows:
			if row[column] == null:
				continue
			var value: float = row[column]
			total += value
			peak = maxf(peak, value)
			minimum = minf(minimum, value)
			count += 1
		monitors[SAMPLE_COLUMNS[column]] = {"mean": total / count, "max": peak, "min": minimum, "samples": count} if count > 0 else null
	summary["sampled_monitors"] = monitors
	summary["window_focus"] = {"focused_frames": _focused_frames, "unfocused_frames": _unfocused_frames, "scope": "window input focus; not an occlusion or GPU utilization measurement"}
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
