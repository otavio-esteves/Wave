extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const SAMPLE_SPACING := 6.0
const REROUTE_DISTANCE := 14.0

var _graph := AStar2D.new()
var _ids: Dictionary[Vector2, int] = {}
var _segments := PackedVector2Array()
var _segment_ids := PackedInt32Array()


func _init() -> void:
	var roads := Layout.urban_routes().duplicate()
	var scenic := Layout.scenic_routes()
	roads.append_array(scenic)
	roads.append_array(Layout.district_routes())
	var mouths := PackedVector2Array()
	for road in roads:
		mouths.append(road.points[0])
		mouths.append(road.points[-1])
		var line := PackedVector2Array([road.points[0]])
		var steps := ceili(road.length / SAMPLE_SPACING)
		var branches := Layout.Baixada.junctions(road).duplicate()
		if road == roads[Layout.HORTO_ROUTE]:
			branches.append(Layout.PASSO_HORTO_STATION)
		elif road == scenic[0]:
			branches.append(Layout.PASSO_MIRANTE_STATION)
		branches.sort()
		var branch := 0
		for index in range(1, steps):
			var station: float = road.length * index / steps
			while branch < branches.size() and branches[branch] <= station:
				line.append(road.point_at(branches[branch]))
				branch += 1
			line.append(road.point_at(station))
		while branch < branches.size():
			line.append(road.point_at(branches[branch]))
			branch += 1
		line.append(road.points[-1])
		_add_line(line)
	var workshops := PackedVector2Array([Vector2(Layout.DEPOT_AXIS, Layout.ROWS[0]),
		Vector2(Layout.DEPOT_AXIS, Layout.ROWS[1])])
	mouths.append_array(workshops)
	_add_line(workshops)
	for column: float in Layout.COLUMNS:
		var line := PackedVector2Array()
		for row: float in Layout.ROWS:
			line.append(Vector2(column, row))
		for mouth in mouths:
			if is_equal_approx(mouth.x, column) and not line.has(mouth):
				line.append(mouth)
		line.sort()
		_add_line(line)
	for row: float in Layout.ROWS:
		var line := PackedVector2Array()
		for column: float in Layout.COLUMNS:
			line.append(Vector2(column, row))
		for mouth in mouths:
			if is_equal_approx(mouth.y, row) and not line.has(mouth):
				line.append(mouth)
		line.sort()
		_add_line(line)


func route_to_start(site: Vector2, heading: Vector2, gate: Vector2, gate_forward: Vector2) -> PackedVector2Array:
	var origin := _nearest_segment(site, heading)
	var destination := _nearest_segment(gate, gate_forward)
	var source_point := _project_to_segment(site, origin)
	var finish := _project_to_segment(gate, destination)
	var travel_forward := (_segments[destination + 1] - _segments[destination]).dot(gate_forward) > 0.0
	var arrival := _segment_ids[destination if travel_forward else destination + 1]
	var beyond := _segment_ids[destination + 1 if travel_forward else destination]
	var best := PackedVector2Array()
	var best_cost := INF
	if origin == destination and (finish - source_point).dot(gate_forward) >= 0.0:
		best = PackedVector2Array([source_point, finish])
		best_cost = _entry_cost(best, heading) + source_point.distance_to(finish)
	# A path terminating on the far side of the gate would require reversing
	# on the final road. Enter the last segment from its approach side.
	_graph.disconnect_points(beyond, arrival, false)
	for endpoint in range(origin, origin + 2):
		if origin == destination and _segment_ids[endpoint] == arrival and (finish - source_point).dot(gate_forward) < 0.0:
			continue
		var candidate := _graph.get_point_path(_segment_ids[endpoint], arrival)
		if candidate.is_empty():
			continue
		if not source_point.is_equal_approx(candidate[0]):
			candidate.insert(0, source_point)
		if not finish.is_equal_approx(candidate[-1]):
			candidate.append(finish)
		var cost := distance(candidate) + _entry_cost(candidate, heading)
		if cost < best_cost:
			best = candidate
			best_cost = cost
	_graph.connect_points(beyond, arrival, false)
	return best


static func advance(path: PackedVector2Array, site: Vector2) -> PackedVector2Array:
	# Compare a limited distance along the route, so crossing an upcoming
	# leg of a loop cannot move the instruction across the next junction.
	var nearest := REROUTE_DISTANCE * REROUTE_DISTANCE
	var point := site
	var segment := -1
	var checked := 0.0
	for index in path.size() - 1:
		var projected := Geometry2D.get_closest_point_to_segment(site, path[index], path[index + 1])
		var separation := site.distance_squared_to(projected)
		if separation < nearest:
			nearest = separation
			point = projected
			segment = index
		checked += path[index].distance_to(path[index + 1])
		if checked > 45.0:
			break
	if segment < 0:
		return PackedVector2Array()
	var remaining := path.slice(segment + 1)
	if not point.is_equal_approx(remaining[0]):
		remaining.insert(0, point)
	return remaining


static func distance(path: PackedVector2Array) -> float:
	var length := 0.0
	for index in path.size() - 1:
		length += path[index].distance_to(path[index + 1])
	return length


static func instruction(path: PackedVector2Array) -> String:
	var travelled := 0.0
	for index in range(1, path.size() - 1):
		var incoming := (path[index] - path[index - 1]).normalized()
		var outgoing := (path[index + 1] - path[index]).normalized()
		travelled += path[index - 1].distance_to(path[index])
		if travelled > 45.0:
			break
		var angle := incoming.angle_to(outgoing)
		if absf(angle) > deg_to_rad(39.0):
			var turn := "direita" if angle > 0.0 else "esquerda"
			return "Vire à %s em %d m" % [turn, roundi(travelled)]
	return ""


func _nearest_segment(site: Vector2, direction: Vector2) -> int:
	var best := INF
	var nearest := 0
	for index in range(0, _segments.size(), 2):
		var first := _segments[index]
		var second := _segments[index + 1]
		var projected := Geometry2D.get_closest_point_to_segment(site, first, second)
		var agreement := absf(direction.dot(first.direction_to(second)))
		var distance_squared := site.distance_squared_to(projected) + 9.0 * (1.0 - agreement)
		if distance_squared < best:
			best = distance_squared
			nearest = index
	return nearest


func _project_to_segment(site: Vector2, index: int) -> Vector2:
	return Geometry2D.get_closest_point_to_segment(site, _segments[index], _segments[index + 1])


func _add_line(points: PackedVector2Array) -> void:
	for index in points.size() - 1:
		var a := _add_point(points[index])
		var b := _add_point(points[index + 1])
		if a == b or _graph.are_points_connected(a, b):
			continue
		_graph.connect_points(a, b)
		_segments.append(_graph.get_point_position(a))
		_segments.append(_graph.get_point_position(b))
		_segment_ids.append(a)
		_segment_ids.append(b)


func _add_point(point: Vector2) -> int:
	# Branch endpoints and sampled parent stations can round differently.
	var key := point.snapped(Vector2.ONE * 0.002)
	if _ids.has(key):
		return _ids[key]
	var index := _ids.size()
	_ids[key] = index
	_graph.add_point(index, point)
	return index


static func _entry_cost(points: PackedVector2Array, heading: Vector2) -> float:
	if points.size() < 2:
		return 0.0
	return 12.0 * (1.0 - heading.dot(points[0].direction_to(points[1])))
