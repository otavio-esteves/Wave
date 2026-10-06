extends Node

# Wall-clock frame intervals during scene entry. No GPU timestamp queries.
var rows: Array[Dictionary] = []
var _started := 0
var _last := 0
var _previous_state := "before_scene"
var completed := false


func _ready() -> void:
	process_priority = -1000
	_started = Time.get_ticks_usec()
	_last = _started


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
		set_process(false)


func snapshot() -> Dictionary:
	return {"completed": completed, "scene_entry_ms": (_last - _started) / 1000.0, "scope": "observer creation before scene change to first supported motion; frame intervals include main-thread/driver/presentation work, not exclusive GPU time or whole process launch", "frames": rows.duplicate(true)}
