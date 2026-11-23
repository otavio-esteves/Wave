extends RefCounted

const CELL := 32.0
const PROJECTION_CELL := CELL * 0.5
const TWICE_PROJECTION_RADIUS := PROJECTION_CELL * sqrt(2.0)
const GRADE_MARGIN := 29.0

var title: String
var half_width: float
var stop_station: float
var curve := Curve2D.new()
var length: float
var points: PackedVector2Array
var _heights: PackedVector2Array
var _height_handles := PackedFloat64Array()
var _junction_widths: Vector2
var _stations := PackedFloat32Array()
var _segment_vectors := PackedVector2Array()
var _inverse_squared_lengths := PackedFloat64Array()
var _cells: Dictionary[Vector2i, PackedInt32Array] = {}


func _init(road_title: String, width: float, knots: Array, heights: PackedVector2Array, turnout: float, junctions: Vector2) -> void:
	title = road_title
	half_width = width * 0.5
	set_elevations(heights)
	_junction_widths = junctions
	curve.bake_interval = 2.5
	for knot: Array in knots:
		curve.add_point(knot[0], knot[1], knot[2])
	points = curve.get_baked_points()
	length = curve.get_baked_length()
	stop_station = length * turnout
	_stations.append(0.0)
	var coarse_cells: Dictionary[Vector2i, PackedInt32Array] = {}
	for index in points.size() - 1:
		var a := points[index]
		var b := points[index + 1]
		var segment := b - a
		var length_squared := segment.length_squared()
		_segment_vectors.append(segment)
		_inverse_squared_lengths.append(1.0 / length_squared if length_squared > 0.0 else 0.0)
		_stations.append(_stations[index] + segment.length())
		if length_squared <= 0.0:
			continue
		var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(half_width + GRADE_MARGIN + 5.0)
		var first := Vector2i((bounds.position / CELL).floor())
		var last := Vector2i((bounds.end / CELL).floor())
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var key := Vector2i(x, y)
				if not coarse_cells.has(key):
					coarse_cells[key] = PackedInt32Array()
				coarse_cells[key].append(index)
	_index_projections(coarse_cells)


func _index_projections(coarse_cells: Dictionary[Vector2i, PackedInt32Array]) -> void:
	var distances := PackedFloat64Array()
	for coarse in coarse_cells:
		var indices := coarse_cells[coarse]
		distances.resize(indices.size())
		for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			var cell: Vector2i = coarse * 2 + offset
			var center := (Vector2(cell) + Vector2(0.5, 0.5)) * PROJECTION_CELL
			var nearest := INF
			for slot in indices.size():
				var index := indices[slot]
				var a := points[index]
				var segment := _segment_vectors[index]
				var t := clampf((center - a).dot(segment) * _inverse_squared_lengths[index], 0.0, 1.0)
				var distance := center.distance_squared_to(a + segment * t)
				distances[slot] = distance
				nearest = minf(nearest, distance)
			# A segment's distance can change by at most the cell radius.
			# Preserve every possible winner, in original order for ties.
			var limit := sqrt(nearest) + TWICE_PROJECTION_RADIUS + 0.001
			var limit_squared := limit * limit
			var selected := PackedInt32Array()
			for slot in indices.size():
				if distances[slot] <= limit_squared:
					selected.append(indices[slot])
			_cells[cell] = selected


func project(position: Vector2) -> Vector3:
	# Station, signed lateral offset and exact distance to the baked polyline.
	var key := Vector2i((position / PROJECTION_CELL).floor())
	if not _cells.has(key):
		return Vector3(0.0, 0.0, INF)
	var best_distance := INF
	var best_index := -1
	var best_fraction := 0.0
	var best_lateral := Vector2.ZERO
	for index: int in _cells[key]:
		var a := points[index]
		var edge := _segment_vectors[index]
		var t := clampf((position - a).dot(edge) * _inverse_squared_lengths[index], 0.0, 1.0)
		var lateral := position - (a + edge * t)
		var distance := lateral.length_squared()
		if distance < best_distance:
			best_distance = distance
			best_index = index
			best_fraction = t
			best_lateral = lateral
	if best_index < 0:
		return Vector3(0.0, 0.0, INF)
	var station := lerpf(_stations[best_index], _stations[best_index + 1], best_fraction)
	var signed_offset := best_lateral.dot(_segment_vectors[best_index].orthogonal().normalized())
	return Vector3(station, signed_offset, sqrt(best_distance))


func point_at(station: float) -> Vector2:
	return curve.sample_baked(clampf(station, 0.0, length), true)


func direction_at(station: float) -> Vector2:
	return (point_at(station + 1.7) - point_at(station - 1.7)).normalized()


func offset_at(station: float, offset: float) -> Vector2:
	return point_at(station) + direction_at(station).orthogonal() * offset


func edge_at(station: float, lateral: float) -> float:
	var turnout := (1.0 - smoothstep(14.0, 32.0, absf(station - stop_station))) * 6.2 if stop_station >= 0.0 else 0.0
	var width := lerpf(_junction_widths.x, half_width, smoothstep(19.0, 58.0, station))
	width = lerpf(_junction_widths.y, width, smoothstep(16.0, 45.0, length - station))
	return width + turnout if lateral < 0.0 else width


func height_at(station: float) -> float:
	var fraction := clampf(station / length, 0.0, 1.0)
	for index in range(1, _heights.size()):
		if fraction > _heights[index].x and index < _heights.size() - 1:
			continue
		var a := _heights[index - 1]
		var b := _heights[index]
		var t := inverse_lerp(a.x, b.x, fraction)
		var handle := (index - 1) * 2
		return cubic_interpolate(a.y, b.y, _height_handles[handle], _height_handles[handle + 1], t)
	return _heights[-1].y


func set_elevations(heights: PackedVector2Array) -> void:
	_heights = heights
	var spans := maxi(0, heights.size() - 1)
	_height_handles.resize(spans * 2)
	for index in spans:
		var a := heights[index]
		var b := heights[index + 1]
		var width := b.x - a.x
		var m0 := _gradient(index) * width
		var m1 := _gradient(index + 1) * width
		_height_handles[index * 2] = b.y - 2.0 * m0
		_height_handles[index * 2 + 1] = a.y + 2.0 * m1


func _gradient(index: int) -> float:
	var previous := _heights[maxi(0, index - 1)]
	var next := _heights[mini(_heights.size() - 1, index + 1)]
	return (next.y - previous.y) / (next.x - previous.x)


func bank_at(station: float) -> float:
	var enter := direction_at(station - 7.0)
	var exit := direction_at(station + 7.0)
	return clampf(enter.angle_to(exit) * 0.21, -0.052, 0.052)
