extends Node

const Layout = preload("res://scripts/race/circuit_layout.gd")
signal lap_finished(seconds: float)
var completed_laps := 0
var elapsed := 0.0
var last_lap := 0.0
var best_lap := 0.0
var active := false
var valid_lap := true
var next_checkpoint := 0
var checkpoints: Array[Transform3D] = []
var route: PackedVector3Array
var _previous := Vector3.ZERO
var _car: PlayerCar
var _readout: Label

func _ready() -> void:
	process_physics_priority = 5
	_car = get_parent().get_node("PlayerCar")
	route = get_parent().get_node("RaceMap").get_meta("route")
	var start_index := 0
	var distance := INF
	for index in route.size():
		var candidate := route[index].distance_squared_to(Vector3(-80, 0, 150))
		if candidate < distance:
			distance = candidate
			start_index = index
	for checkpoint in 16:
		var index := (start_index + checkpoint * route.size() / 16) % route.size()
		var forward := Layout.tangent(route, index)
		checkpoints.append(Transform3D(Basis(forward.cross(Vector3.UP), Vector3.UP, -forward), route[index]))
	_previous = _car.global_position
	_car.car_reset.connect(_reset_run)
	_readout = Label.new()
	_readout.name = "RaceTiming"
	_readout.position = Vector2(20, 165)
	_readout.add_theme_font_size_override("font_size", 20)
	_readout.add_theme_color_override("font_shadow_color", Color.BLACK)
	_readout.add_theme_constant_override("shadow_offset_x", 2)
	_readout.add_theme_constant_override("shadow_offset_y", 2)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().get_node("HUD/Overlay").add_child(_readout)
	_update_readout()

func _physics_process(delta: float) -> void:
	var current := _car.global_position
	if active:
		elapsed += delta
		if _distance_to_road(current) > Layout.HALF_WIDTH + 2.0:
			valid_lap = false
	# Reset/teleport cannot masquerade as a checkpoint crossing.
	if current.distance_to(_previous) > maxf(_car.forward_speed, _car.reverse_speed) * delta + 2.0:
		active = false
		next_checkpoint = 0
		elapsed = 0.0
	else:
		if _crossed(checkpoints[0], _previous, current):
			if active and next_checkpoint == 0 and valid_lap:
				last_lap = elapsed
				best_lap = elapsed if best_lap == 0.0 else minf(best_lap, elapsed)
				completed_laps += 1
				lap_finished.emit(elapsed)
			active = true
			valid_lap = true
			elapsed = 0.0
			next_checkpoint = 1
		elif active and next_checkpoint > 0 and _crossed(checkpoints[next_checkpoint], _previous, current):
			next_checkpoint = (next_checkpoint + 1) % checkpoints.size()
	_previous = current
	_update_readout()

func _crossed(gate: Transform3D, from: Vector3, to: Vector3) -> bool:
	var normal := -gate.basis.z
	var before := (from - gate.origin).dot(normal)
	var after := (to - gate.origin).dot(normal)
	if before > 0.0 or after <= 0.0:
		return false
	var crossing := from.lerp(to, -before / (after - before)) - gate.origin
	return absf(crossing.dot(gate.basis.x)) <= Layout.HALF_WIDTH + 1.5 and absf(crossing.y) < 3.0

func _distance_to_road(position: Vector3) -> float:
	var point := Vector3(position.x, 0, position.z)
	var best := INF
	for index in route.size():
		var a := route[index]
		var segment := route[(index + 1) % route.size()] - a
		var closest := a + segment * clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
		best = minf(best, point.distance_squared_to(closest))
	return sqrt(best)

func _reset_run() -> void:
	active = false
	valid_lap = true
	next_checkpoint = 0
	elapsed = 0.0
	_previous = _car.global_position
	_update_readout()

func _update_readout() -> void:
	if _readout == null:
		return
	var state := "Cruze a linha para iniciar"
	if active:
		state = "Volta %d  ·  %s" % [completed_laps + 1, _format_time(elapsed)]
		state += "\nCheckpoints: %d/16" % (15 if next_checkpoint == 0 else next_checkpoint - 1)
		if not valid_lap:
			state += "  ·  Volta inválida: saiu da pista"
	_readout.text = "CIRCUITO · 1,22 km\n" + state + "\nÚltima: " + _format_time(last_lap) + "   Melhor: " + _format_time(best_lap)

func _format_time(seconds: float) -> String:
	if seconds == 0.0:
		return "--:--.---"
	var milliseconds := roundi(seconds * 1000.0)
	return "%02d:%02d.%03d" % [milliseconds / 60000, (milliseconds / 1000) % 60, milliseconds % 1000]
