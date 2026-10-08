extends Node

# Identical minimal observer in both A/B arms. No disk IO or GPU queries while driving.
const Statistics = preload("res://scripts/tools/frame_statistics.gd")
var car: PlayerCar
var streamer: WorldStreamer
var active := false
var last_usec := 0
var rows: Array[Array] = []
var legs: Array[Dictionary] = []
var leg := ""
var first_row := 0
var anchor := 0.0


func _ready() -> void:
	process_priority = 100


func begin(name: String) -> void:
	leg = name
	first_row = rows.size()
	last_usec = Time.get_ticks_usec()
	anchor = Time.get_unix_time_from_system()
	active = true


func _process(_delta: float) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec()
	rows.append([leg, Engine.get_process_frames(), (now - last_usec) / 1000.0,
		car.position.z, streamer.current_cell, get_tree().root.has_focus()])
	last_usec = now


func end() -> void:
	active = false
	var frames: Array[float] = []
	var unfocused := 0
	for index in range(first_row, rows.size()):
		frames.append(float(rows[index][2]))
		if not rows[index][5]:
			unfocused += 1
	var report := Statistics.summarize(frames)
	report.merge({"leg": leg, "first_row": first_row, "frames": frames.size(),
		"capture_started_unix_seconds": anchor, "unfocused_frames": unfocused})
	legs.append(report)


func save(capture_enabled: bool) -> void:
	var file := FileAccess.open("user://pacing-frames.csv", FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["leg", "process_frame", "frame_ms", "target_z", "cell", "focused"]))
	for row in rows:
		var values := PackedStringArray()
		for value in row:
			values.append(str(value))
		file.store_csv_line(values)
	file.close()
	var settings := get_node("/root/WaveSettings")
	file = FileAccess.open("user://pacing.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"capture_enabled": capture_enabled, "legs": legs,
		"hlod": get_parent().get_node("Distant").snapshot(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"window_size": str(get_tree().root.size), "graphics": settings.graphics,
		"fps_limit": Engine.max_fps, "vsync_mode": DisplayServer.window_get_vsync_mode(),
		"scope": "minimal observer present in both arms; buffered IO after driving; process frame associates streaming events, not GPU causality"}, "\t"))
	file.close()
