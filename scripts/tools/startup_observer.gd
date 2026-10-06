extends Node

# Wall-clock frame intervals during scene entry. No GPU timestamp queries.
var rows: Array[Dictionary] = []
var phases: Array[Dictionary] = []
var draws: Array[Dictionary] = []
var _draw_started := 0
var _started := 0
var _last := 0
var _previous_state := "before_scene"
var completed := false


func _ready() -> void:
	process_priority = -1000
	_started = Time.get_ticks_usec()
	_last = _started
	get_tree().scene_changed.connect(_scene_attached)
	RenderingServer.frame_pre_draw.connect(_before_draw)
	RenderingServer.frame_post_draw.connect(_after_draw)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var scene := get_tree().current_scene
	var streamer: WorldStreamer = scene.get_node_or_null("WorldStreamer") if scene != null else null
	var state := "scene_loading"
	if streamer != null and not streamer.records.is_empty():
		state = streamer.records[0].state
	rows.append({"frame": Engine.get_process_frames(), "elapsed_ms": (now - _started) / 1000.0, "interval_ms": (now - _last) / 1000.0, "previous_state": _previous_state, "state_now": state})
	_last = now
	_previous_state = state
	if streamer != null and not streamer.blocked:
		completed = true
		mark("motion_supported")
		set_process(false)
		RenderingServer.frame_pre_draw.disconnect(_before_draw)
		RenderingServer.frame_post_draw.disconnect(_after_draw)


func snapshot() -> Dictionary:
	return {"completed": completed, "scene_entry_ms": (_last - _started) / 1000.0, "scope": "observer creation before scene change to first supported motion; frame intervals include main-thread/driver/presentation work, not exclusive GPU time or whole process launch", "frames": rows.duplicate(true), "phases": phases.duplicate(true), "draw_intervals": draws.duplicate(true), "draw_scope": "frame_pre_draw to frame_post_draw wall time; includes renderer submission/driver stalls, not exclusive GPU time"}


func mark(phase: String) -> void:
	phases.append({"phase": phase, "elapsed_ms": (Time.get_ticks_usec() - _started) / 1000.0, "process_frame": Engine.get_process_frames()})


func _scene_attached() -> void:
	if not completed:
		mark("scene_attached")


func _before_draw() -> void:
	if not completed:
		_draw_started = Time.get_ticks_usec()


func _after_draw() -> void:
	if _draw_started == 0:
		return
	var now := Time.get_ticks_usec()
	draws.append({"frame": Engine.get_process_frames(), "elapsed_ms": (now - _started) / 1000.0, "duration_ms": (now - _draw_started) / 1000.0})
	_draw_started = 0
