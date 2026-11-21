extends RefCounted

const COLUMNS := [-194.0, -63.0, 64.0, 208.0]
const ROWS := [-176.0, -54.0, 52.0, 194.0]
const LOCAL_HALF := 4.2
const COLLECTOR_HALF := 5.6
const COLLECTOR := 64.0
const COLUMN_HALF_WIDTHS := [LOCAL_HALF, LOCAL_HALF, COLLECTOR_HALF, LOCAL_HALF]
const AVENUE := 52.0
const AVENUE_LANE := 3.6
const AVENUE_TRAVEL_HALF := AVENUE_LANE * 2.0
const PARKING_WIDTH := 2.4
const AVENUE_HALF := AVENUE_TRAVEL_HALF + PARKING_WIDTH
const ROW_HALF_WIDTHS := [LOCAL_HALF, LOCAL_HALF, AVENUE_HALF, LOCAL_HALF]
const WALK_WIDTH := 2.50
const AVENUE_WALK := 4.25
const CURB_WIDTH := 0.40
const GROUND_STEP := 6
const TERRAIN := Rect2(-432, -416, 864, 832)
const STREET_BOUNDS := Rect2(-214, -190, 442, 399)
const PLAZA := Rect2(-53, -42, 104, 80.0)
const MARKET := Vector2(-128.5, 75.1)
const RESERVOIR := Vector2(251, 15)
const SPAWN := Vector2(-174, AVENUE + AVENUE_LANE * 0.5)


static func walk_width(z: float) -> float:
	return AVENUE_WALK if z == AVENUE else WALK_WIDTH


static func road_distance(point: Vector2) -> float:
	var x := _nearest_street(point.x, COLUMNS)
	var z := _nearest_street(point.y, ROWS)
	var dx := absf(point.x - COLUMNS[x]) - float(COLUMN_HALF_WIDTHS[x])
	var dz := absf(point.y - ROWS[z]) - float(ROW_HALF_WIDTHS[z])
	return maxf(_corner_distance(dx, dz, junction_radius(x, z)), _outside_streets(point))


static func junction_radius(column: int, row: int) -> float:
	if ROWS[row] == AVENUE:
		return 8.5 if COLUMNS[column] == COLLECTOR else 6.4
	return 5.1 if COLUMNS[column] == COLLECTOR else 3.7


static func _corner_distance(dx: float, dz: float, radius: float) -> float:
	# A quarter circle rounds the inside of each parcel where two roads meet.
	if dx >= radius or dz >= radius:
		return minf(dx, dz)
	return radius - Vector2(radius - dx, radius - dz).length()


static func road_finish(point: Vector2) -> Color:
	var x := _nearest_street(point.x, COLUMNS)
	var z := _nearest_street(point.y, ROWS)
	var across_x := absf(point.x - COLUMNS[x])
	var across_z := absf(point.y - ROWS[z])
	var dx := across_x - float(COLUMN_HALF_WIDTHS[x])
	var dz := across_z - float(ROW_HALF_WIDTHS[z])
	var edge := maxf(_corner_distance(dx, dz, junction_radius(x, z)), _outside_streets(point))
	var lane := across_x if dx < dz else across_z
	var straight := smoothstep(1.0, 11.0, maxf(dx, dz))
	var avenue := 1.0 if dx >= dz and ROWS[z] == AVENUE else 0.0
	return Color(clampf(-edge / 3.0, 0.0, 1.0), clampf(lane / 12.0, 0.0, 1.0), straight, avenue)


static func ground_band(point: Vector2) -> float:
	var distance := road_distance(point)
	if distance <= CURB_WIDTH:
		return distance / CURB_WIDTH
	var commercial := 1.0 - smoothstep(AVENUE_HALF + AVENUE_WALK, AVENUE_HALF + AVENUE_WALK + 4.0, absf(point.y - AVENUE))
	return 1.0 + (distance - CURB_WIDTH) / (lerpf(WALK_WIDTH, AVENUE_WALK, commercial) - CURB_WIDTH)


static func height_at(point: Vector2) -> float:
	var x_index := _nearest_street(point.x, COLUMNS)
	var z_index := _nearest_street(point.y, ROWS)
	var x_offset := absf(point.x - COLUMNS[x_index])
	var z_offset := absf(point.y - ROWS[z_index])
	var dx := x_offset - float(COLUMN_HALF_WIDTHS[x_index])
	var dz := z_offset - float(ROW_HALF_WIDTHS[z_index])
	var radius := junction_radius(x_index, z_index)
	var outside := _outside_streets(point)
	var limit := 1.0 - smoothstep(0.0, 21.0, outside)
	var x_blend := (1.0 - smoothstep(0.0, 17.0, dx)) * smoothstep(0.0, radius + 8.0, dz) * limit
	var z_blend := (1.0 - smoothstep(0.0, 17.0, dz)) * smoothstep(0.0, radius + 8.0, dx) * limit
	var grade_point := point.lerp(Vector2(COLUMNS[x_index], point.y), x_blend * 0.79)
	grade_point = grade_point.lerp(Vector2(grade_point.x, ROWS[z_index]), z_blend * 0.88)
	var distance := maxf(_corner_distance(dx, dz, radius), outside)
	var crown := 0.013 * (maxf(-dx, 0.0) * x_blend + maxf(-dz, 0.0) * z_blend)
	var crossing := lerpf(0.036, 0.145, smoothstep(radius + 2.5, radius + 6.1, maxf(dx, dz)))
	var curb := clampf(distance / CURB_WIDTH, 0.0, 1.0) * crossing
	return _landscape_height(grade_point) + curb + crown


static func _nearest_street(coordinate: float, streets: Array) -> int:
	var nearest := 0
	for index in range(1, streets.size()):
		if absf(coordinate - streets[index]) < absf(coordinate - streets[nearest]):
			nearest = index
	return nearest


static func _outside_streets(point: Vector2) -> float:
	var outside := (point - STREET_BOUNDS.get_center()).abs() - STREET_BOUNDS.size * 0.5
	return maxf(outside.x, outside.y)


static func _landscape_height(point: Vector2) -> float:
	# The avenue's vertical alignment controls the valley floor. The hills rise
	# from it with a vertical curve, so the streets have no abrupt grade changes.
	var valley := 23.0 - 0.016 * point.x + 5.4 * exp(-pow((point.x + 163.0) / 84.0, 2))
	valley += -3.5 * exp(-pow((point.x - 30.0) / 93.0, 2)) + 8.3 * exp(-pow((point.x - 219.0) / 80.0, 2))
	var north := maxf(0.0, AVENUE - point.y)
	var south := maxf(0.0, point.y - AVENUE)
	var west := 1.0 - smoothstep(-208.0, 98.0, point.x)
	var east := smoothstep(-154.0, 216.0, point.x)
	var west_slope := (sqrt(north * north + 28.0 * 28.0) - 28.0) * lerpf(0.069, 0.133, west)
	var east_slope := (sqrt(south * south + 31.0 * 31.0) - 31.0) * lerpf(0.027, 0.076, east)
	var shoulder := 1.22 * sin(point.x / 51.0 + point.y / 54.0) * smoothstep(12.0, 92.0, absf(point.y - AVENUE))
	var background := _ridge(point + Vector2(337, 331), Vector2(0.89, 0.46), Vector2(244, 86), 44.0)
	background += _ridge(point - Vector2(337, 344), Vector2(0.91, -0.41), Vector2(216, 103), 39.0)
	background += _ridge(point - Vector2(378, -53), Vector2(0.25, 0.97), Vector2(189, 87), 49.0)
	return valley + west_slope + east_slope + shoulder + background * smoothstep(6.0, 130.0, _outside_streets(point))


static func _ridge(offset: Vector2, axis: Vector2, radii: Vector2, height: float) -> float:
	var shape := Vector2(offset.dot(axis), offset.dot(axis.orthogonal())) / radii
	return height * exp(-shape.length_squared())


static func surface_point(point: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(point.x, height_at(point) + lift, point.y)


static func spawn() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), surface_point(SPAWN, 0.39))


static func block(column: int, row: int) -> Rect2:
	var left: float = COLUMNS[column] + COLUMN_HALF_WIDTHS[column] + WALK_WIDTH
	var top: float = ROWS[row] + ROW_HALF_WIDTHS[row] + walk_width(ROWS[row])
	var right: float = COLUMNS[column + 1] - COLUMN_HALF_WIDTHS[column + 1] - WALK_WIDTH
	var bottom: float = ROWS[row + 1] - ROW_HALF_WIDTHS[row + 1] - walk_width(ROWS[row + 1])
	return Rect2(left, top, right - left, bottom - top)
