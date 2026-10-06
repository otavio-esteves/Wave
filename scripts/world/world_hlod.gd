class_name WorldHLOD
extends Node3D

@export var detail_enter_distance := 180.0
@export var detail_exit_distance := 200.0
var enabled := true
var _streamer: WorldStreamer
var _target: Node3D
var _detailed: Dictionary = {}
var transitions := 0
var events: Array[Dictionary] = []


func _ready() -> void:
	process_priority = 10 # After streaming attaches/releases this frame.
	_streamer = get_node("../WorldStreamer")
	_target = get_node("../PlayerCar")
	assert(detail_enter_distance > 0 and detail_exit_distance > detail_enter_distance)
	update_representation()


func _process(_delta: float) -> void:
	update_representation()


func update_representation() -> void:
	for record in _streamer.records:
		var proxy := get_node_or_null(NodePath(record.id)) as Node3D
		if proxy == null:
			continue
		var distance := _streamer._distance(_target.global_position, record.bounds)
		var was_detail: bool = _detailed.get(record.id, false)
		var detail: bool = record.node != null and (not enabled or distance <= (detail_exit_distance if was_detail else detail_enter_distance))
		if was_detail != detail:
			transitions += 1
			if events.size() >= 256:
				events.pop_front()
			events.append({"cell": record.id, "detailed": detail, "process_frame": Engine.get_process_frames(), "clock_usec": Time.get_ticks_usec(), "target_z": _target.global_position.z})
		_detailed[record.id] = detail
		proxy.visible = enabled and not detail
		if record.node != null:
			# Visibility changes rendering only: resident collision support stays live.
			record.node.visible = detail


func snapshot() -> Dictionary:
	var proxies: Array[String] = []
	for child: Node3D in get_children():
		if child.visible:
			proxies.append(child.name)
	return {"enabled": enabled, "detail_enter_m": detail_enter_distance, "detail_exit_m": detail_exit_distance, "detailed": _detailed.duplicate(), "visible_proxies": proxies, "transitions": transitions, "events": events.duplicate(true), "scope": "player distance to cell bounds; three resident offline proxies, visual switching only"}
