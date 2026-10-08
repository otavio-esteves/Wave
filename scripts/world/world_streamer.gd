class_name WorldStreamer
extends Node3D

@export_file("*.json") var manifest_file: String
@export var target_path := NodePath("../PlayerCar")
@export var preload_distance := 210.0
@export var retain_distance := 330.0
@export var max_resident_cells := 3
# Fault injection for contract tests; no player-facing setting.
var request_delay_frames := 0
var records: Array[Dictionary] = []
var events: Array[Dictionary] = []
var current_cell := ""
var blocking_events := 0
var blocked := false
var failure_count := 0
var peak_resident_cells := 0
var released_cells := 0
var _target: CharacterBody3D
var _started_usec: int
var _held_transform: Transform3D
var _blocked_since := 0
var _blocked_usec := 0
var _last_mutation_frame := -1


# Godot has no threaded-load cancel API. On destruction, drain outstanding
# results without retaining the world or calling a method on a freed streamer.
class LoadDrain extends Node:
	var paths: Array[String] = []

	func _ready() -> void:
		add_to_group("world_load_drain")

	func _process(_delta: float) -> void:
		for path in paths.duplicate():
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				ResourceLoader.load_threaded_get(path)
				paths.erase(path)
			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				# Terminal failure also owns a loader task; consume its null result.
				ResourceLoader.load_threaded_get(path)
				paths.erase(path)
			elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				paths.erase(path)
		if paths.is_empty():
			queue_free()


func _ready() -> void:
	_started_usec = Time.get_ticks_usec()
	process_physics_priority = -20
	_target = get_node(target_path) as CharacterBody3D
	if _target == null:
		push_error("WorldStreamer requires a CharacterBody3D target")
		set_process(false)
		set_physics_process(false)
		return
	_set_blocked(true)
	if _target.has_signal("car_reset"):
		_target.connect("car_reset", _on_reset)
	_read_manifest()


func _read_manifest() -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(manifest_file))
	if not document is Dictionary or document.get("version") != 1 or not document.get("cells") is Array:
		_fail({}, "Invalid world manifest")
		return
	var ids: Dictionary = {}
	for entry in document.cells:
		if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or ids.has(entry.id) or not entry.get("scene") is String or not _numbers(entry.get("origin"), 3) or not _numbers(entry.get("bounds"), 6):
			_fail({}, "Invalid/duplicate cell entry")
			records.clear()
			return
		var b: Array = entry.bounds
		if b[3] <= 0 or b[4] <= 0 or b[5] <= 0 or not entry.get("neighbors") is Array:
			_fail({}, "Invalid cell bounds/neighbors")
			records.clear()
			return
		ids[entry.id] = true
		records.append({"id": entry.id, "path": entry.scene, "origin": Vector3(entry.origin[0], entry.origin[1], entry.origin[2]), "bounds": AABB(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5])), "neighbors": entry.neighbors, "state": "unloaded", "node": null, "resource": null, "wanted": false})
	for record in records:
		for neighbor in record.neighbors:
			if not ids.has(neighbor):
				_fail({}, "Unknown neighboring cell")
				records.clear()
				return
	if records.is_empty() or max_resident_cells < 2 or retain_distance <= preload_distance + 65:
		_fail({}, "Empty world or invalid residency/hysteresis settings")
		records.clear()


func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)):
			return false
	return true


func _physics_process(delta: float) -> void:
	if blocked:
		_target.global_transform = _held_transform
		if Input.is_action_just_pressed("reset_car") and _target.has_method("reset_car"):
			_target.reset_car()
	_select()
	_guard(delta)


func _select() -> void:
	current_cell = ""
	var point := _target.global_position
	var radius := preload_distance + minf(_target.velocity.length(), 65.0)
	for record in records:
		var distance := _distance(point, record.bounds)
		record.wanted = distance <= radius
		if distance == 0:
			current_cell = record.id
		if record.state in ["active", "retained"]:
			record.state = "active" if record.wanted else "retained"


func _process(_delta: float) -> void:
	# Inherit pause. Polling never blocks on load_threaded_get before LOADED.
	_select()
	_poll()
	if _last_mutation_frame != Engine.get_process_frames():
		if not _release_far():
			_activate_one()
	_request_one()


func _request_one() -> void:
	for record in records:
		if record.state in ["requested", "ready"]:
			return
	var chosen: Dictionary = {}
	var nearest := INF
	for record in records:
		if record.wanted and record.state == "unloaded":
			var distance := _distance(_target.global_position, record.bounds)
			if distance < nearest:
				nearest = distance
				chosen = record
	if chosen.is_empty():
		return
	chosen.request_usec = Time.get_ticks_usec()
	chosen.available_frame = Engine.get_process_frames() + request_delay_frames
	var error := ResourceLoader.load_threaded_request(chosen.path, "PackedScene", false, ResourceLoader.CACHE_MODE_IGNORE)
	if error != OK:
		_fail(chosen, "Threaded request failed: %s" % error_string(error))
		return
	chosen.state = "requested"
	_event(chosen.id, "request", (Time.get_ticks_usec() - chosen.request_usec) / 1000.0)


func _poll() -> void:
	for record in records:
		if record.state != "requested" or Engine.get_process_frames() < record.available_frame:
			continue
		var status := ResourceLoader.load_threaded_get_status(record.path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(record.path) as PackedScene
			_event(record.id, "request_to_ready", (Time.get_ticks_usec() - record.request_usec) / 1000.0)
			if resource == null:
				_fail(record, "Loaded resource is not a PackedScene")
			elif not record.wanted:
				record.state = "unloaded"
				_event(record.id, "obsolete_result", 0.0)
			else:
				record.resource = resource
				record.state = "ready"
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(record.path)
			_fail(record, "Threaded load failed")
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_fail(record, "Threaded load failed")


func _activate_one() -> void:
	var chosen: Dictionary = {}
	var nearest := INF
	for record in records:
		if record.state == "ready":
			if not record.wanted:
				record.resource = null
				record.state = "unloaded"
				continue
			var distance := _distance(_target.global_position, record.bounds)
			if distance < nearest:
				nearest = distance
				chosen = record
	if chosen.is_empty():
		return
	if resident_count() >= max_resident_cells:
		return
	var started := Time.get_ticks_usec()
	var instance: Node = chosen.resource.instantiate()
	_event(chosen.id, "instantiate", (Time.get_ticks_usec() - started) / 1000.0)
	chosen.resource = null
	if not instance is Node3D:
		if instance != null:
			instance.free()
		_fail(chosen, "Cell root must be Node3D")
		return
	instance.position = chosen.origin
	if not _valid_floor(instance, chosen):
		instance.free()
		_fail(chosen, "Cell lacks the declared collision support")
		return
	started = Time.get_ticks_usec()
	add_child(instance)
	_event(chosen.id, "attach", (Time.get_ticks_usec() - started) / 1000.0)
	chosen.node = instance
	chosen.state = "active"
	# Allow physics to register the newly attached static bodies before motion.
	chosen.support_tick = Engine.get_physics_frames() + 2
	_last_mutation_frame = Engine.get_process_frames()
	peak_resident_cells = maxi(peak_resident_cells, resident_count())


func _valid_floor(instance: Node3D, record: Dictionary) -> bool:
	# This first manifest contract is a continuous, flat corridor. Do not infer
	# safe support from arbitrary geometry or from metadata alone.
	var floor := instance.get_node_or_null("Colliders/Floor") as CollisionShape3D
	if floor == null or floor.disabled or not floor.shape is BoxShape3D:
		return false
	var body := floor.get_parent() as StaticBody3D
	if body == null or (body.collision_layer & 1) == 0 or body.transform != Transform3D.IDENTITY or floor.basis != Basis.IDENTITY or instance.basis != Basis.IDENTITY:
		return false
	var size: Vector3 = floor.shape.size
	var center: Vector3 = record.origin + floor.position
	var bounds: AABB = record.bounds
	return absf(size.x - bounds.size.x) < 0.001 and absf(size.z - bounds.size.z) < 0.001 and absf(center.x - size.x / 2 - bounds.position.x) < 0.001 and absf(center.z - size.z / 2 - bounds.position.z) < 0.001 and absf(center.y + size.y / 2) < 0.001


func _release_far() -> bool:
	for record in records:
		if record.node != null and _distance(_target.global_position, record.bounds) > retain_distance:
			var started := Time.get_ticks_usec()
			record.node.free()
			record.node = null
			record.resource = null
			record.state = "unloaded"
			released_cells += 1
			_last_mutation_frame = Engine.get_process_frames()
			_event(record.id, "release_cpu", (Time.get_ticks_usec() - started) / 1000.0)
			return true
	return false


func _guard(delta: float) -> void:
	var predicted := _target.global_position + _target.velocity * delta
	var safe := true
	for x in [-1.3, 1.3]:
		for z in [-2.8, 2.8]:
			if not has_support(predicted + _target.global_basis * Vector3(x, 0, z)):
				safe = false
	_set_blocked(not safe)


func has_support(point: Vector3) -> bool:
	for record in records:
		if record.node != null and Engine.get_physics_frames() >= record.support_tick and _distance(point, record.bounds) == 0:
			return true
	return false


func _set_blocked(value: bool) -> void:
	if value == blocked:
		return
	blocked = value
	_target.set_physics_process(not value)
	if value:
		_held_transform = _target.global_transform
		_blocked_since = Time.get_ticks_usec()
		blocking_events += 1
		_event(current_cell, "motion_held", 0.0)
	else:
		_blocked_usec += Time.get_ticks_usec() - _blocked_since
		_event(current_cell, "motion_released", (Time.get_ticks_usec() - _blocked_since) / 1000.0)


func teleport_to(destination: Transform3D) -> void:
	# Caller resets vehicle state before requesting a jump. No movement until
	# every footprint corner has resident support, including at cell boundaries.
	_target.global_transform = destination
	_target.velocity = Vector3.ZERO
	if blocked:
		_held_transform = destination
	else:
		_set_blocked(true)
	_select()


func _on_reset() -> void:
	if blocked:
		_held_transform = _target.global_transform
	_select()
	_guard(0.0)


func _distance(point: Vector3, bounds: AABB) -> float:
	var end := bounds.end
	return Vector2(maxf(bounds.position.x - point.x, maxf(0, point.x - end.x)), maxf(bounds.position.z - point.z, maxf(0, point.z - end.z))).length()


func resident_count() -> int:
	var count := 0
	for record in records:
		if record.node != null:
			count += 1
	return count


func snapshot() -> Dictionary:
	var states: Dictionary = {}
	for record in records:
		states[record.id] = record.state
	return {"manifest": manifest_file, "elapsed_ms": (Time.get_ticks_usec() - _started_usec) / 1000.0, "current_cell": current_cell, "states": states, "resident_cells": resident_count(), "peak_resident_cells": peak_resident_cells, "released_cells": released_cells, "blocking_events": blocking_events, "blocked": blocked, "blocked_ms": (_blocked_usec + Time.get_ticks_usec() - _blocked_since if blocked else _blocked_usec) / 1000.0, "failures": failure_count, "events": events.duplicate(true)}


func mark(phase: String) -> void:
	_event(current_cell, phase, 0.0)


func _event(id: String, phase: String, duration: float) -> void:
	if events.size() >= 1024:
		events.pop_front()
	events.append({"cell": id, "phase": phase, "duration_ms": duration, "elapsed_ms": (Time.get_ticks_usec() - _started_usec) / 1000.0, "process_frame": Engine.get_process_frames(), "physics_tick": Engine.get_physics_frames(), "target_z": _target.global_position.z if is_instance_valid(_target) else null})


func _fail(record: Dictionary, message: String) -> void:
	failure_count += 1
	if not record.is_empty():
		record.state = "failed"
		record.resource = null
	_event(str(record.get("id", "manifest")), "failure", 0.0)
	push_warning("Streaming: " + message)


func _exit_tree() -> void:
	var pending: Array[String] = []
	for record in records:
		if record.state == "requested":
			pending.append(record.path)
		record.resource = null
		record.node = null
	records.clear()
	if not pending.is_empty() and not get_tree().root.is_queued_for_deletion():
		var drain := LoadDrain.new()
		drain.paths = pending
		drain.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(drain)
