extends Node3D

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const TimingGate = preload("res://scripts/vehicle/timing_gate.gd")
const Events = preload("res://scripts/city/figueiras_events.gd")
const Navigation = preload("res://scripts/city/figueiras_navigation.gd")
const Cup = preload("res://scripts/city/figueiras_cup.gd")
const GhostRun = preload("res://scripts/city/figueiras_ghost_run.gd")
const GhostCar = preload("res://scripts/city/figueiras_ghost_car.gd")
const READOUT_INTERVAL := 0.12
const COURSE_OFFROAD_SECONDS := 0.95
const OFFROAD_SURFACES := ["gramado", "calçada", "acostamento"]

var events := Events.catalog()
var cup := Cup.new()
var selected := 0
var wet := false
var score := 0.0
var best_score := -1.0
var best_clean_score := -1.0
var _previous_speed := 0.0
var _radar_speed := 0.0
var next_gate := -1
var elapsed := 0.0
var last_time := 0.0
var best_time := 0.0
var route := PackedVector2Array()
var approach := PackedVector2Array()
var gates: Array[Transform3D] = []
var widths := PackedFloat32Array()
var _previous := Vector3.ZERO
var _previous_pose := Transform3D.IDENTITY
var _gate_visual := Node3D.new()
var _gate_title := Label3D.new()
var _posts: Array[MeshInstance3D] = []
var _gate_finish := StandardMaterial3D.new()
var _gate_paint := ImmediateMesh.new()
var _panel := PanelContainer.new()
var _readout := Label.new()
var _result_seconds := 0.0
var _readout_elapsed := 0.0
var _result_line := ""
var _splits := PackedFloat32Array()
var _best_splits := PackedFloat32Array()
var _split_delta := INF
var _split_visible_until := 0.0
var _navigation: Navigation
var _ghost_record := GhostRun.new()
var _ghost_candidate := GhostRun.new()
var _ghost_car: GhostCar
var _course_signature := 0
var _show_ghost := true
var _fault := ""
var _offroad := 0.0
var _passed_gates := 0
var _shown_gate := -1
@onready var _car: PlayerCar = $"../PlayerCar"


func _ready() -> void:
	process_physics_priority = 5
	_car.car_reset.connect(_reset_attempt)
	_car.impact.connect(_on_impact)
	_previous = _car.global_position
	_make_gate_visual()
	_make_readout()
	select_event(maxi(0, cup_event_index()))


func select_event(index: int, arm := false, ghost := true) -> void:
	selected = clampi(index, 0, events.size() - 1)
	var event := events[selected]
	gates.clear()
	widths.clear()
	route = route_for(selected)
	for gate: Array in event.fixed:
		_add_gate(gate[0], gate[1], gate[2])
	var road = event.curve
	for station: float in event.stations:
		_add_gate(road.point_at(station), road.direction_at(station), road.half_width + 0.25)
	_course_signature = hash([event.id, gates, widths, route]) & 0xffffffff
	_show_ghost = ghost
	_ghost_record.clear()
	if event.type == "Tempo":
		_ghost_record.load_run(event.id, wet, _course_signature, event.limit)
	var config := ConfigFile.new()
	if config.load(Events.BEST_TIME_PATH) != OK:
		config.clear()
	best_score = _stored_score(config, event)
	best_clean_score = _stored_score(config, event, true)
	best_time = maxf(0.0, best_score) if event.type == "Tempo" else 0.0
	_best_splits = _stored_splits(config, event, best_clean_score >= 0.0)
	last_time = 0.0
	_reset_attempt()
	if arm:
		start_attempt()


func route_for(index: int) -> PackedVector2Array:
	var event := events[index]
	if event.has("preview"):
		return PackedVector2Array(event.preview)
	var points := PackedVector2Array()
	for gate: Array in event.fixed:
		points.append(gate[0])
	var road = event.curve
	if road != null:
		var finish: float = event.stations[-1]
		for station in range(roundi(event.curve_entry), roundi(finish), 4):
			points.append(road.point_at(station))
		points.append(road.point_at(finish))
	return points


func start_of(index: int) -> Vector2:
	var event := events[index]
	return event.fixed[0][0] if not event.fixed.is_empty() else event.curve.point_at(event.stations[0])


func is_free_route(index: int) -> bool:
	return events[index].get("free_checkpoints", false)


func checkpoint_pending(index: int) -> bool:
	return (_passed_gates & (1 << index)) == 0


func record_for(index: int, clean := false) -> float:
	var config := ConfigFile.new()
	if config.load(Events.BEST_TIME_PATH) != OK:
		return -1.0
	return _stored_score(config, events[index], clean)


func _stored_score(config: ConfigFile, event: Dictionary, clean := false) -> float:
	var key := Events.record_key(event, wet) + ("_clean" if clean else "")
	var stored: Variant = config.get_value(event.id, key, -1.0)
	if stored is not int and stored is not float:
		return -1.0
	var limit: float = 1000.0 if event.type == "Velocidade" else event.limit
	if (event.type == "Regularidade" and stored == 0.0) or (stored > 0 and stored <= limit):
		return float(stored)
	return -1.0


func _stored_splits(config: ConfigFile, event: Dictionary, clean: bool) -> PackedFloat32Array:
	var reference := best_clean_score if clean else best_time
	if event.type != "Tempo" or reference <= 0.0:
		return PackedFloat32Array()
	var key := Events.record_key(event, wet) + ("_clean" if clean else "")
	var splits: Variant = config.get_value(event.id, key + "_splits", PackedFloat32Array())
	if splits is not PackedFloat32Array or splits.size() != gates.size() - 1:
		return PackedFloat32Array()
	var previous := 0.0
	for split: float in splits:
		if not is_finite(split) or split <= previous:
			return PackedFloat32Array()
		previous = split
	return splits if is_equal_approx(previous, reference) else PackedFloat32Array()


func set_wet(value: bool) -> void:
	if wet != value and (not cup.active or cup.wet == value):
		wet = value
		select_event(cup_event_index() if cup.active else selected)


func can_stage(index: int) -> bool:
	return not cup.active or events[index].id == cup.event_id()


func cup_available() -> bool:
	for id: String in Cup.STAGES:
		if _index_of(id) < 0:
			return false
	return true


func start_cup(ghost := true) -> void:
	if cup.active or not cup_available():
		return
	cup.start(wet)
	select_event(cup_event_index(), true, ghost)


func abort_cup() -> void:
	cup.abort()
	_reset_attempt()


func cup_event_index() -> int:
	return _index_of(cup.event_id()) if cup.active else -1


func _index_of(id: String) -> int:
	for index in events.size():
		if events[index].id == id:
			return index
	return -1


func start_attempt() -> void:
	if not can_stage(selected):
		var round := cup_event_index()
		if round >= 0:
			select_event(round, true, _show_ghost)
		return
	elapsed = 0.0
	score = 0.0
	_radar_speed = 0.0
	next_gate = 0
	_result_seconds = 0.0
	_readout_elapsed = 0.0
	_result_line = ""
	_previous = _car.global_position
	_previous_pose = _car.global_transform
	_previous_speed = _car.get_speed_kmh()
	_fault = ""
	_offroad = 0.0
	_passed_gates = 0
	_ghost_candidate.clear()
	_ghost_record.rewind()
	_hide_ghost()
	_reset_splits()
	_update_approach()
	_refresh_display()


func retry_from_start(index: int, ghost: bool) -> bool:
	if index != selected or last_time <= 0.0 or not can_stage(index):
		return false
	var event := events[index]
	var gate := gates[0]
	var road = event.curve
	var site := Vector2(gate.origin.x, gate.origin.z)
	var forward := Vector2(-gate.basis.z.x, -gate.basis.z.z)
	var start := site - forward * 8.0
	if road != null and event.fixed.is_empty():
		var station: float = maxf(1.0, float(event.stations[0]) - 8.0)
		forward = road.direction_at(station)
		start = road.offset_at(station, -road.half_width * 0.38)
	if Layout.road_distance(start) > -0.25:
		return false
	var home := _car.spawn_transform
	_car.spawn_transform = Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.y)), Layout.surface_point(start, 0.42))
	_car.reset_car()
	_car.spawn_transform = home
	select_event(index, true, ghost)
	return true


func _add_gate(site: Vector2, direction: Vector2, half_width: float) -> void:
	var forward := Vector3(direction.x, 0.0, direction.y)
	var basis := Basis(forward.cross(Vector3.UP), Vector3.UP, -forward)
	gates.append(Transform3D(basis, Layout.surface_point(site)))
	widths.append(half_width)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("city_activity") and not event.is_echo():
		if next_gate < 0:
			start_attempt()
		else:
			_reset_attempt()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var current := _car.global_position
	var pose := _car.global_transform
	var preceding_pose := _previous_pose
	_previous_pose = pose
	if next_gate < 0:
		_previous = current
		if _result_seconds > 0.0:
			_result_seconds = maxf(0.0, _result_seconds - delta)
			if _result_seconds == 0.0:
				_refresh_display()
		return
	var travelled := current.distance_to(_previous)
	if elapsed > float(events[selected].limit):
		_reset_attempt()
		_result_line = "Tempo esgotado"
		_result_seconds = 3.5
		_refresh_display()
		return
	if travelled > maxf(_car.forward_speed, _car.velocity.length()) * delta + 1.5:
		_reset_attempt()
		return
	if next_gate > 0:
		elapsed += delta
		_check_course_surface(delta)
	var free_route := is_free_route(selected)
	var crossing := _crossed_gate(current, free_route)
	var fraction := crossing.y
	var current_speed := _car.get_speed_kmh()
	_previous = current
	if is_finite(fraction):
		var crossing_pose := preceding_pose.interpolate_with(pose, fraction)
		if next_gate > 0 and events[selected].type == "Velocidade":
			_radar_speed = lerpf(_previous_speed, current_speed, fraction)
			score += _radar_speed
		elif next_gate > 0 and events[selected].type == "Tempo":
			_capture_split(elapsed - (1.0 - fraction) * delta)
		_passed_gates |= 1 << int(crossing.x)
		next_gate += 1
		if next_gate == 1:
			approach.clear()
			elapsed = (1.0 - fraction) * delta
			if events[selected].type == "Tempo":
				_ghost_candidate.add_pose(0.0, crossing_pose)
		elif next_gate == gates.size():
			var final_time := elapsed - (1.0 - fraction) * delta
			if events[selected].type == "Tempo" and _fault.is_empty():
				_ghost_candidate.add_pose(final_time, crossing_pose)
			_finish_attempt(final_time)
			return
		_move_gate_visual()
		_refresh_display()
	_previous_speed = current_speed
	if next_gate > 0 and events[selected].type == "Tempo":
		_record_pose(pose)
		_draw_ghost(current)
	_readout_elapsed += delta
	if _readout_elapsed >= READOUT_INTERVAL:
		_readout_elapsed = 0.0
		if next_gate == 0:
			_update_approach()
		_refresh_display()


func _on_impact(strength: float) -> void:
	if next_gate > 0 and strength >= 0.32 and _fault.is_empty():
		_fault = "Colisão forte"


func _crossed_gate(current: Vector3, free_route: bool) -> Vector2:
	var boundary := next_gate == 0 or next_gate == gates.size() - 1
	if not free_route or boundary:
		return Vector2(next_gate, TimingGate.crossing_fraction(gates[next_gate], _previous, current, widths[next_gate], 2.8))
	for index in range(1, gates.size() - 1):
		if not checkpoint_pending(index):
			continue
		var fraction := TimingGate.crossing_fraction(gates[index], _previous, current, widths[index], 2.8)
		if is_finite(fraction):
			return Vector2(index, fraction)
		var reverse := TimingGate.crossing_fraction(gates[index], current, _previous, widths[index], 2.8)
		if is_finite(reverse):
			return Vector2(index, 1.0 - reverse)
	return Vector2(-1, INF)


func _check_course_surface(delta: float) -> void:
	if not _fault.is_empty():
		return
	var left_course := _car.is_on_floor() and _car.surface_name in OFFROAD_SURFACES
	_offroad = _offroad + delta if left_course else 0.0
	if _offroad >= COURSE_OFFROAD_SECONDS:
		_fault = "Fora do piso da prova"


func _record_pose(pose: Transform3D) -> void:
	if _fault.is_empty() and elapsed - _ghost_candidate.duration() >= GhostRun.SAMPLE_INTERVAL - 0.0002:
		_ghost_candidate.add_pose(elapsed, pose)


func _draw_ghost(player: Vector3) -> void:
	if not _show_ghost or DisplayServer.get_name() == "headless" or _ghost_record.duration() <= elapsed:
		_hide_ghost()
		return
	if _ghost_car == null:
		_ghost_car = GhostCar.new()
		_ghost_car.name = "GhostCar"
		add_child(_ghost_car)
	_ghost_car.present(_ghost_record.pose_at(elapsed), player)


func _hide_ghost() -> void:
	if _ghost_car != null:
		_ghost_car.hide()


func _update_approach() -> void:
	var site := Vector2(_car.global_position.x, _car.global_position.z)
	if approach.size() > 1:
		var remaining := Navigation.advance(approach, site)
		if remaining.size() > 1:
			approach = remaining
			return
	if _navigation == null:
		_navigation = Navigation.new()
	var gate := gates[0]
	var heading := Vector2(-_car.global_basis.z.x, -_car.global_basis.z.z).normalized()
	approach = _navigation.route_to_start(site, heading, Vector2(gate.origin.x, gate.origin.z),
		Vector2(-gate.basis.z.x, -gate.basis.z.z))


func _finish_attempt(seconds: float) -> void:
	next_gate = -1
	last_time = seconds
	_result_seconds = 8.0
	_hide_ghost()
	var event := events[selected]
	if event.type == "Tempo":
		score = seconds
	elif event.type == "Regularidade":
		score = absf(seconds - float(event.target))
	var higher_is_better: bool = event.type == "Velocidade"
	if higher_is_better:
		score = roundi(score * 100.0) / 100.0
	var personal_best := best_score < 0.0 or (score > best_score if higher_is_better else score < best_score)
	var clean_best := _fault.is_empty() and (best_clean_score < 0.0 or (score > best_clean_score if higher_is_better else score < best_clean_score))
	if personal_best:
		best_score = score
		if event.type == "Tempo":
			best_time = seconds
	if clean_best:
		best_clean_score = score
	if event.type == "Tempo" and (clean_best or (personal_best and best_clean_score < 0.0)):
		_best_splits = _splits.duplicate()
	if personal_best or clean_best:
		var config := ConfigFile.new()
		var loaded := config.load(Events.BEST_TIME_PATH)
		if loaded in [OK, ERR_FILE_NOT_FOUND]:
			if personal_best:
				_store_record(config, event, false)
			if clean_best:
				_store_record(config, event, true)
			var temporary := "%s.tmp-%d" % [Events.BEST_TIME_PATH, OS.get_process_id()]
			var result := config.save(temporary)
			if result == OK:
				result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(Events.BEST_TIME_PATH))
			if result != OK:
				push_warning("Unable to save Figueiras activity record: %s" % error_string(result))
	var medal := Events.medal(event, score, wet)
	var result_details := Events.medal_name(medal) if _fault.is_empty() else _fault + " · volta sem medalha"
	if event.type == "Tempo" and _fault.is_empty() and _ghost_candidate.samples.size() >= GhostRun.STRIDE * 2:
		if _ghost_record.duration() <= 0.0 or seconds < _ghost_record.duration():
			var result := _ghost_candidate.save_run(event.id, wet, _course_signature, event.limit)
			if result == OK:
				_ghost_record.load_run(event.id, wet, _course_signature, event.limit)
				result_details += " · Novo fantasma"
			elif result != ERR_INVALID_DATA:
				push_warning("Não foi possível salvar o fantasma (%s)" % error_string(result))
	if cup.active and event.id == cup.event_id():
		if _fault.is_empty():
			cup.complete_round(medal)
			if cup.active:
				result_details += "\nCopa · %d pts · Próxima etapa %s" % [cup.points(), events[cup_event_index()].title]
			else:
				result_details += "\nCopa da Vila · %s · %d pontos" % [Cup.trophy(cup.points()), cup.points()]
		else:
			result_details += "\nA etapa da Copa precisa de uma passagem limpa"
	var record := best_clean_score if best_clean_score >= 0.0 else best_score
	_result_line = "%s · %s\n%s\n%s  %s" % [event.title, Events.format_score(event, score),
		result_details, "Recorde limpo" if best_clean_score >= 0.0 else "Melhor", Events.format_score(event, record)]
	_refresh_display()


func _store_record(config: ConfigFile, event: Dictionary, clean: bool) -> void:
	var key := Events.record_key(event, wet) + ("_clean" if clean else "")
	config.set_value(event.id, key, score)
	if event.type == "Tempo":
		config.set_value(event.id, key + "_splits", _splits)


func _reset_attempt() -> void:
	next_gate = -1
	_passed_gates = 0
	_shown_gate = -1
	elapsed = 0.0
	_result_seconds = 0.0
	_readout_elapsed = 0.0
	_result_line = ""
	approach.clear()
	_reset_splits()
	_previous = _car.global_position
	_previous_pose = _car.global_transform
	_ghost_candidate.clear()
	_hide_ghost()
	_refresh_display()


func _reset_splits() -> void:
	_splits.clear()
	_split_delta = INF
	_split_visible_until = 0.0


func _capture_split(seconds: float) -> void:
	var index := _splits.size()
	_splits.append(seconds)
	if not is_free_route(selected) and index < _best_splits.size():
		_split_delta = seconds - _best_splits[index]
		_split_visible_until = seconds + 4.0


func _make_gate_visual() -> void:
	_gate_visual.name = "NextGate"
	add_child(_gate_visual)
	_gate_finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gate_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	var paint := MeshInstance3D.new()
	paint.mesh = _gate_paint
	paint.material_override = _gate_finish
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gate_visual.add_child(paint)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.10, 2.12, 0.10)
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color("283b3c")
	frame.roughness = 0.73
	var signal_mesh := BoxMesh.new()
	signal_mesh.size = Vector3(0.34, 0.55, 0.08)
	for index in 2:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = frame
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gate_visual.add_child(post)
		_posts.append(post)
		var signal_face := MeshInstance3D.new()
		signal_face.mesh = signal_mesh
		signal_face.material_override = _gate_finish
		signal_face.position = Vector3(-0.09 if index == 0 else 0.09, 0.74, 0.0)
		signal_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		post.add_child(signal_face)
	_gate_title.position.y = 2.48
	_gate_title.pixel_size = 0.011
	_gate_title.outline_modulate = Color("172e30")
	_gate_title.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_gate_visual.add_child(_gate_title)


func _move_gate_visual() -> void:
	var index := _guide_gate()
	if index < 0:
		return
	var free_checkpoint := is_free_route(selected) and index > 0 and index < gates.size() - 1
	var pose := gates[index]
	# The arrows agree with the driver's approach to bidirectional gates.
	if free_checkpoint and (-pose.basis.z).dot(_car.global_position - pose.origin) > 0.0:
		pose.basis = pose.basis.rotated(Vector3.UP, PI)
	_gate_visual.transform = pose
	_gate_title.text = events[selected].labels[index]
	var boundary := index == 0 or index == gates.size() - 1
	var tint := Color("f4cf88") if boundary else Color("6edac4")
	_gate_finish.albedo_color = tint
	_gate_title.modulate = tint.lightened(0.40)
	for post_index in _posts.size():
		var side := -1.0 if post_index == 0 else 1.0
		var edge := _gate_visual.to_global(Vector3(side * (widths[index] + 0.14), 0.0, 0.0))
		_posts[post_index].global_position = Layout.surface_point(Vector2(edge.x, edge.z), 1.07)
	_draw_gate_paint(widths[index], boundary)
	_shown_gate = index


func _guide_gate() -> int:
	if next_gate <= 0 or next_gate >= gates.size() - 1 or not is_free_route(selected):
		return next_gate
	var best := INF
	var nearest := -1
	for index in range(1, gates.size() - 1):
		if not checkpoint_pending(index):
			continue
		var distance := _car.global_position.distance_to(gates[index].origin)
		if index == _shown_gate:
			distance -= 14.0
		if distance < best:
			best = distance
			nearest = index
	return nearest


func _draw_gate_paint(half_width: float, boundary: bool) -> void:
	_gate_paint.clear_surfaces()
	_gate_paint.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var dashes := clampi(roundi(half_width * 3.1), 4, 21)
	var spacing := 2.0 * half_width / dashes
	for index in dashes:
		var a := -half_width + spacing * (index + 0.12)
		var b := a + spacing * 0.72
		var depth := 0.18 if boundary else 0.12
		_gate_triangle(Vector2(a, -depth), Vector2(b, -depth), Vector2(a, depth))
		_gate_triangle(Vector2(b, -depth), Vector2(b, depth), Vector2(a, depth))
	# Two forward chevrons let approaching drivers read the gate's direction before the text is legible.
	var arrow := minf(0.60, half_width * 0.30)
	for side in [-1.0, 1.0]:
		var center: float = side * half_width * 0.53
		for wing in [-1.0, 1.0]:
			var edge: float = center + wing * arrow
			_gate_triangle(Vector2(center, 0.42), Vector2(edge, 1.08), Vector2(center, 0.67))
			_gate_triangle(Vector2(edge, 1.08), Vector2(edge, 1.33), Vector2(center, 0.67))
	_gate_paint.surface_end()


func _gate_triangle(a: Vector2, b: Vector2, c: Vector2) -> void:
	for point in [a, b, c]:
		var world := _gate_visual.to_global(Vector3(point.x, 0.0, point.y))
		_gate_paint.surface_add_vertex(_gate_visual.to_local(Layout.surface_point(Vector2(world.x, world.z), 0.066)))


func _make_readout() -> void:
	_panel.name = "AlamedaTiming"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.030, 0.066, 0.071, 0.89)
	background.set_corner_radius_all(6)
	background.content_margin_left = 16
	background.content_margin_right = 16
	background.content_margin_top = 8
	background.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", background)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.add_theme_font_size_override("font_size", 16)
	_panel.add_child(_readout)
	get_parent().get_node("HUD/Overlay").add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -150.0
	_panel.offset_right = 150.0
	_panel.offset_top = 20.0


func _refresh_display() -> void:
	var current_mark := _gate_visual.visible
	_gate_visual.visible = next_gate >= 0
	_panel.visible = next_gate >= 0 or _result_seconds > 0.0
	if next_gate >= 0 and (not current_mark or _guide_gate() != _shown_gate):
		_move_gate_visual()
	var event := events[selected]
	if next_gate == 0:
		var meters := Navigation.distance(approach) if approach.size() > 1 else _car.global_position.distance_to(gates[0].origin)
		var turn := Navigation.instruction(approach)
		var title: String = event.title
		if cup.active:
			title = "Etapa %d/%d · %s" % [cup.rounds.size() + 1, Cup.STAGES.size(), title]
		_readout.text = "%s   ·   %d m até a largada\n%s" % [title, roundi(meters), turn if not turn.is_empty() else event.hints[next_gate]]
	elif next_gate > 0:
		var status := _format_time(elapsed)
		if event.type == "Velocidade" and _radar_speed > 0.0:
			status = "%d km/h   ·   Soma %d" % [roundi(_radar_speed), roundi(score)]
		elif event.type == "Regularidade":
			status += " / " + _format_time(float(event.target)).left(5)
		elif is_finite(_split_delta) and elapsed < _split_visible_until:
			var comparison := "à frente" if _split_delta < 0.0 else "atrás"
			status += "   ·   %.2f s %s" % [absf(_split_delta), comparison] if absf(_split_delta) >= 0.005 else "   ·   Mesmo ritmo"
		if not _fault.is_empty():
			status += "   ·   " + _fault
		var position := _car.global_position
		var note := Events.pace_note(event, Vector2(position.x, position.z), _car.get_speed_kmh() / 3.6)
		if is_free_route(selected) and next_gate < gates.size() - 1:
			var remaining: Array[String] = []
			for index in range(1, gates.size() - 1):
				if checkpoint_pending(index):
					remaining.append(event.hints[index])
			_readout.text = "%s   ·   %d/%d\nFaltam %s" % [status, next_gate - 1, gates.size() - 2, " · ".join(remaining)]
			return
		_readout.text = "%s   ·   %d/%d\n%s" % [status, next_gate - 1, gates.size() - 1,
			event.hints[next_gate] if note.is_empty() else note]
	elif _result_seconds > 0.0:
		_readout.text = _result_line


func _format_time(seconds: float) -> String:
	var ms := roundi(seconds * 1000.0)
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
