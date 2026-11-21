extends RefCounted

const CELL := 32.0
const GRADE_MARGIN := 29.0

var title: String
var half_width: float
var stop_station: float
var curve := Curve2D.new()
var length: float
var points: PackedVector2Array
var _heights: PackedVector2Array
var _junction_widths: Vector2
var _stations := PackedFloat32Array()
var _cells: Dictionary[Vector2i, PackedInt32Array] = {}


func _init(road_title: String, width: float, knots: Array, heights: PackedVector2Array, turnout: float, junctions: Vector2) -> void:
	title = road_title
	half_width = width * 0.5
	_heights = heights
	_junction_widths = junctions
	curve.bake_interval = 2.5
	for knot: Array in knots:
		curve.add_point(knot[0], knot[1], knot[2])
	points = curve.get_baked_points()
	length = curve.get_baked_length()
	stop_station = length * turnout
	_stations.append(0.0)
	for index in points.size() - 1:
		var a := points[index]
		var b := points[index + 1]
		_stations.append(_stations[index] + a.distance_to(b))
		var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(half_width + GRADE_MARGIN + 5.0)
		var first := _cell(bounds.position)
		var last := _cell(bounds.end)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var key := Vector2i(x, y)
				if not _cells.has(key):
					_cells[key] = PackedInt32Array()
				_cells[key].append(index)


func _cell(position: Vector2) -> Vector2i:
	return Vector2i((position / CELL).floor())


func project(position: Vector2) -> Vector3:
	# Station, signed lateral offset and exact distance to the baked polyline.
	var key := _cell(position)
	if not _cells.has(key):
		return Vector3(0.0, 0.0, INF)
	var best := INF
	var result := Vector3.ZERO
	for index: int in _cells[key]:
		var a := points[index]
		var edge := points[index + 1] - a
		var t := clampf((position - a).dot(edge) / edge.length_squared(), 0.0, 1.0)
		var lateral := position - (a + edge * t)
		var distance := lateral.length_squared()
		if distance < best:
			best = distance
			result.x = lerpf(_stations[index], _stations[index + 1], t)
			result.y = lateral.dot(edge.orthogonal().normalized())
	result.z = sqrt(best)
	return result


func point_at(station: float) -> Vector2:
	return curve.sample_baked(clampf(station, 0.0, length), true)


func direction_at(station: float) -> Vector2:
	return (point_at(station + 1.7) - point_at(station - 1.7)).normalized()


func offset_at(station: float, offset: float) -> Vector2:
	return point_at(station) + direction_at(station).orthogonal() * offset


func edge_at(station: float, lateral: float) -> float:
	var turnout := (1.0 - smoothstep(14.0, 32.0, absf(station - stop_station))) * 6.2
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
		var width := b.x - a.x
		var m0 := _gradient(index - 1) * width
		var m1 := _gradient(index) * width
		return cubic_interpolate(a.y, b.y, b.y - 2.0 * m0, a.y + 2.0 * m1, t)
	return _heights[-1].y


func _gradient(index: int) -> float:
	var previous := _heights[maxi(0, index - 1)]
	var next := _heights[mini(_heights.size() - 1, index + 1)]
	return (next.y - previous.y) / (next.x - previous.x)


func bank_at(station: float) -> float:
	var enter := direction_at(station - 7.0)
	var exit := direction_at(station + 7.0)
	return clampf(enter.angle_to(exit) * 0.21, -0.052, 0.052)
