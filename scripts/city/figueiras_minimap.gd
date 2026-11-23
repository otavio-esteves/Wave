extends Control

const Layout = preload("res://scripts/city/figueiras_layout.gd")
var frame := Rect2()
var map := Rect2()
var atlas := false
var preview := -1
var car: PlayerCar
var sprint: Node3D
var _elapsed := 0.0
var _routes: Array[PackedVector2Array] = []
var _urban_routes: Array[PackedVector2Array] = []
var _district_routes: Array[PackedVector2Array] = []
var _lake := PackedVector2Array()
var _creek := PackedVector2Array()
var _stops := PackedVector2Array()
var _gallery := PackedVector2Array()
var _sprint_trail := PackedVector2Array()
var _trail_index := -1
var _contours := PackedVector2Array()
var _projected_contours := PackedVector2Array()
var _backdrop := Control.new()
var _tracking := Control.new()
var _street_view: SubViewport
var _street_texture: TextureRect
var _street_origin := Vector2.ZERO


func _ready() -> void:
	if atlas:
		set_process(false)
		visibility_changed.connect(_prepare_contours)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	if not atlas and DisplayServer.get_name() != "headless":
		_street_view = SubViewport.new()
		_street_view.disable_3d = true
		_street_view.transparent_bg = true
		_street_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_street_view)
		_street_view.add_child(_backdrop)
		_street_texture = TextureRect.new()
		_street_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_street_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_street_texture.texture = _street_view.get_texture()
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		_street_texture.material = material
		add_child(_street_texture)
	else:
		add_child(_backdrop)
	_tracking.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracking.draw.connect(_draw_tracking)
	add_child(_tracking)
	clip_contents = not atlas
	resized.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	frame = Rect2(Vector2.ZERO, size)
	map = frame.grow(-11.0 if not atlas else -22.0)
	_routes.clear()
	_urban_routes.clear()
	_district_routes.clear()
	_stops.clear()
	_lake.clear()
	_creek.clear()
	_gallery.clear()
	_trail_index = -1
	for route in Layout.scenic_routes():
		_routes.append(_project_route(route.points))
		if route.stop_station >= 0.0:
			_stops.append(_project(route.offset_at(route.stop_station, -route.half_width - 4.0)))
	for route in Layout.urban_routes():
		_urban_routes.append(_project_route(route.points))
	for route in Layout.district_routes():
		_district_routes.append(_project_route(route.points))
	for index in 32:
		_lake.append(_project(Layout.LAKE + Layout.lake_outline(TAU * index / 32.0) * 0.93))
	for z in range(242, int(Layout.CREEK_RANGE.y) - 20, 6):
		_creek.append(_project(Vector2(Layout.creek_axis(z), z)))
	var ridge := Layout.scenic_routes()[0]
	for station in range(roundi(Layout.GALLERY_START), roundi(Layout.GALLERY_END) + 1, 6):
		_gallery.append(_project(ridge.point_at(station)))
	_projected_contours.clear()
	for sample in _contours:
		_projected_contours.append(_project(sample))
	if _street_view != null and size.x >= 30.0 and size.y >= 30.0:
		# Only the route and marker move relative to the streets. Rasterize
		# the whole street layer once at the minimap's own pixel scale.
		_street_origin = _project(Layout.MAP_BOUNDS.position).floor() - Vector2.ONE * 8.0
		_street_view.size = Vector2i((_project(Layout.MAP_BOUNDS.end) - _street_origin).ceil()) + Vector2i(8, 8)
		_street_texture.size = Vector2(_street_view.size)
		_street_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_backdrop.queue_redraw()
	queue_redraw()
	refresh_activity()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.10:
		_elapsed = 0.0
		refresh_activity()


func refresh_activity() -> void:
	if _street_texture != null:
		_street_texture.position = _street_origin + _tracking_offset()
	elif not atlas:
		_backdrop.queue_redraw()
	_tracking.queue_redraw()


func _draw() -> void:
	if size.x < 30.0 or size.y < 30.0:
		return
	draw_rect(frame, Color(0.038, 0.067, 0.080, 0.91))
	draw_rect(frame, Color("526162"), false, 1.0)


func _draw_backdrop() -> void:
	if size.x < 30.0 or size.y < 30.0:
		return
	_backdrop.draw_set_transform(-_street_origin if _street_view != null else _tracking_offset())
	if not _projected_contours.is_empty():
		_backdrop.draw_multiline(_projected_contours, Color("253e3a"), 1.2, true)
	var bounds := Layout.STREET_BOUNDS
	_backdrop.draw_polyline(_creek, Color("47687e"), 2.0, true)
	_backdrop.draw_colored_polygon(_lake, Color("47687e"))
	_backdrop.draw_rect(Rect2(_project(Layout.PLAZA.position), _project(Layout.PLAZA.end) - _project(Layout.PLAZA.position)), Color("456c55"))
	for x: float in Layout.COLUMNS:
		var collector := x == Layout.COLLECTOR
		_backdrop.draw_line(_project(Vector2(x, bounds.position.y)), _project(Vector2(x, bounds.end.y)), Color("c2c8bb"), 2.3 if collector else 1.5, true)
	for z: float in Layout.ROWS:
		var avenue := z == Layout.AVENUE
		_backdrop.draw_line(_project(Vector2(bounds.position.x, z)), _project(Vector2(bounds.end.x, z)), Color("e4c47e") if avenue else Color("c2c8bb"), 3.5 if avenue else 1.5, true)
	_backdrop.draw_line(_project(Vector2(Layout.DEPOT_AXIS, -176)), _project(Vector2(Layout.DEPOT_AXIS, -54)), Color("a8a487"), 2.0, true)
	for route in _routes:
		_backdrop.draw_polyline(route, Color("9ac4bc"), 2.15, true)
	for route in _urban_routes:
		_backdrop.draw_polyline(route, Color("c2c8bb"), 1.5, true)
	for index in _district_routes.size():
		var arterial := index == Layout.Baixada.AVENIDA
		_backdrop.draw_polyline(_district_routes[index], Color("d9c29a") if arterial else Color("a8bdb3"), 2.65 if arterial else 1.75, true)
	_backdrop.draw_polyline(_gallery, Color("d6ad7b"), 2.35, true)
	for stop in _stops:
		_backdrop.draw_circle(stop, 2.05, Color("d8c587"), true, -1, true)
	_backdrop.draw_circle(_project(Layout.MARKET), 3.3, Color("e4c47e"), true, -1, true)
	_backdrop.draw_circle(_project(Layout.PLAZA.get_center()), 3.3, Color("a7d99b"), true, -1, true)
	if atlas:
		for index in sprint.events.size():
			_backdrop.draw_circle(_project(sprint.start_of(index)), 3.8, Color("ede0b7"), true, -1, true)
		_landmark(Layout.PLAZA.get_center(), "Praça das Figueiras")
		_landmark(Vector2(Layout.DEPOT_AXIS, -115), "Oficinas")
		var horto := Layout.urban_routes()[Layout.HORTO_ROUTE]
		_landmark(horto.offset_at(horto.stop_station, -18.0), "Horto")
		_landmark(Layout.MARKET + Vector2(5, 18), "Mercado")
		_landmark(Layout.LAKE, "Reservatório")
		var station := Layout.urban_routes()[Layout.ESTACAO_ROUTE]
		_landmark(station.point_at(station.length * 0.40) + Vector2(20.0, 4.0), "Estação")
		var ridge := Layout.scenic_routes()[0]
		_landmark(ridge.point_at(ridge.stop_station), "Mirante")
		var passo := Layout.scenic_routes()[Layout.PASSO_ROUTE]
		_landmark(passo.point_at(passo.stop_station) + Vector2(-32.0, 14.0), "Passo")
		_landmark(Vector2(-252, 462), "Distrito Fabril")
		_landmark(Vector2(113, 499), "Baixada do Arroio")
	_backdrop.draw_set_transform(Vector2.ZERO)


func _draw_tracking() -> void:
	if size.x < 30.0 or size.y < 30.0:
		return
	var event_index: int = preview if atlas else (sprint.selected if sprint != null and sprint.next_gate >= 0 else -1)
	var scroll := _tracking_offset()
	_tracking.draw_set_transform(scroll)
	if event_index >= 0:
		var free: bool = sprint.is_free_route(event_index)
		if _trail_index != event_index:
			_trail_index = event_index
			_sprint_trail.clear()
			for site: Vector2 in sprint.route_for(event_index):
				_sprint_trail.append(_project(site))
		var arriving: bool = not atlas and sprint.next_gate == 0 and sprint.approach.size() > 1
		if free:
			_draw_checkpoints(event_index)
		else:
			_tracking.draw_polyline(_sprint_trail, Color("2e816e") if arriving else Color("58dfbd"), 4.0 if atlas else 2.7, true)
		if arriving:
			var guide := PackedVector2Array()
			for site: Vector2 in sprint.approach:
				guide.append(_project(site))
			_tracking.draw_polyline(guide, Color("17232a"), 5.6, true)
			_tracking.draw_polyline(guide, Color("f6d67e"), 2.8, true)
		if not free:
			var target: Vector2 = sprint.start_of(event_index)
			if not atlas and sprint.next_gate > 0:
				var gate: Vector3 = sprint.gates[sprint.next_gate].origin
				target = Vector2(gate.x, gate.z)
			_tracking.draw_circle(_project(target), 6.0 if atlas else 3.6, Color("b8fff0"), true, -1, true)
	_tracking.draw_set_transform(Vector2.ZERO)
	var point := (_project(_car_site()) + scroll).clamp(Vector2(5, 5), frame.end - Vector2(5, 5))
	var heading := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
	var right := heading.orthogonal()
	_tracking.draw_circle(point, 5.4, Color("182325"), true, -1, true)
	_tracking.draw_colored_polygon(PackedVector2Array([point + heading * 6.6, point - heading * 3.6 + right * 4.0, point - heading * 3.6 - right * 4.0]), Color("fff1c9"))


func _draw_checkpoints(event_index: int) -> void:
	var event: Dictionary = sprint.events[event_index]
	for index in event.fixed.size():
		var boundary: bool = index == 0 or index == event.fixed.size() - 1
		var point := _project(event.fixed[index][0])
		var visited: bool = not atlas and not sprint.checkpoint_pending(index)
		var locked: bool = not atlas and index == event.fixed.size() - 1 and sprint.next_gate < index
		var tint := Color("526e6d") if visited or locked else (Color("f7cf82") if boundary else Color("71f0ca"))
		var radius := 6.5 if atlas else 4.2
		_tracking.draw_circle(point, radius + 1.4, Color("17232a"), true, -1, true)
		_tracking.draw_circle(point, radius, tint, not locked, 1.7 if locked else -1.0, true)
		if atlas and not boundary:
			_tracking.draw_string(ThemeDB.fallback_font, point + Vector2(10.0, 7.0), event.hints[index],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)


func _prepare_contours() -> void:
	if is_visible_in_tree() and _contours.is_empty():
		_sample_contours()
		_rebuild()


func _sample_contours() -> void:
	const STEP := 26.0
	var frame_size := Vector2i((Layout.MAP_BOUNDS.size / STEP).ceil()) + Vector2i.ONE
	var samples := PackedFloat32Array()
	samples.resize(frame_size.x * frame_size.y)
	for y in frame_size.y:
		for x in frame_size.x:
			var site := Layout.MAP_BOUNDS.position + Vector2(x, y) * STEP
			samples[y * frame_size.x + x] = Layout.height_at(site)
	for y in frame_size.y - 1:
		for x in frame_size.x - 1:
			var corner := Layout.MAP_BOUNDS.position + Vector2(x, y) * STEP
			var index := y * frame_size.x + x
			var next := index + frame_size.x
			var corners: Array[Vector2] = [corner, corner + Vector2.RIGHT * STEP, corner + Vector2.ONE * STEP, corner + Vector2.DOWN * STEP]
			var heights: Array[float] = [samples[index], samples[index + 1], samples[next + 1], samples[next]]
			for level in range(20, 91, 10):
				var segments := PackedVector2Array()
				for edge in 4:
					var end := (edge + 1) % 4
					if (heights[edge] < level) != (heights[end] < level):
						var point := corners[edge].lerp(corners[end], inverse_lerp(heights[edge], heights[end], level))
						segments.append(point.clamp(Layout.MAP_BOUNDS.position, Layout.MAP_BOUNDS.end))
				_contours.append_array(segments)


func _landmark(site: Vector2, title: String) -> void:
	var font := ThemeDB.fallback_font
	var point := _project(site) + Vector2(8.0, -7.0)
	_backdrop.draw_string_outline(font, point, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color("14272a"))
	_backdrop.draw_string(font, point, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d5dfcf"))


func _project(point: Vector2) -> Vector2:
	var scale := minf(map.size.x / Layout.MAP_BOUNDS.size.x, map.size.y / Layout.MAP_BOUNDS.size.y) if atlas else minf(map.size.x, map.size.y) / 272.0
	return map.get_center() + (point - Layout.MAP_BOUNDS.get_center()) * scale


func _car_site() -> Vector2:
	return Vector2(car.global_position.x, car.global_position.z)


func _tracking_offset() -> Vector2:
	return Vector2.ZERO if atlas else map.get_center() - _project(_car_site())


func _project_route(points: PackedVector2Array) -> PackedVector2Array:
	var projected := PackedVector2Array()
	for index in range(0, points.size() - 1, 3):
		projected.append(_project(points[index]))
	projected.append(_project(points[-1]))
	return projected
