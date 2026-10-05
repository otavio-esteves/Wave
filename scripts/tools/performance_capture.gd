extends Node

const MAX_SECONDS := 180.0
var recording := false
var elapsed := 0.0
var _sample_time := 0.0
var _last_frame_usec := 0
var _frames: Array[float] = []
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
		_rows.clear()
		status = "Gravando · F4 para salvar (máximo 180 s)"


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_last_frame_usec = 0


func _process(_delta: float) -> void:
	if not recording:
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
	if _sample_time >= 0.5:
		_rows.append([snappedf(elapsed, 0.01), Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		_sample_time = 0.0
	if elapsed >= MAX_SECONDS:
		finish()


func finish() -> void:
	if not recording:
		return
	recording = false
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
	csv.store_csv_line(PackedStringArray(["elapsed_seconds", "fps", "draw_calls"]))
	for row in _rows:
		csv.store_csv_line(PackedStringArray([str(row[0]), str(row[1]), str(row[2])]))
	csv.close()
	_frames.sort()
	var total_ms := 0.0
	for frame_ms in _frames:
		total_ms += frame_ms
	var world := get_parent()
	var summary := {
		"world": world.get("world_title"), "engine": Engine.get_version_info()["string"],
		"os": OS.get_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window_size": str(get_tree().root.size), "graphics": get_node("/root/WaveSettings").graphics.duplicate(),
		"duration_seconds": elapsed, "frames": _frames.size(),
		"time_source": "monotonic_wall_clock",
		"average_fps": 1000.0 * _frames.size() / total_ms,
		"median_frame_ms": _frames[int(_frames.size() / 2)],
		"p95_frame_ms": _frames[mini(_frames.size() - 1, int(ceil(_frames.size() * 0.95)) - 1)],
		"slowest_frame_ms": _frames.back(),
	}
	var json := FileAccess.open(base + ".json", FileAccess.WRITE)
	if json == null:
		status = "CSV salvo; falha ao salvar resumo"
		push_error(status)
		return
	json.store_string(JSON.stringify(summary, "\t"))
	json.close()
	status = "Medição salva em user://performance"
	print("Performance capture: " + ProjectSettings.globalize_path(base))


func _exit_tree() -> void:
	finish()
