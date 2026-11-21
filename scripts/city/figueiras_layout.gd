extends RefCounted

const COLUMNS := [-194.0, -63.0, 64.0, 208.0]
const ROWS := [-176.0, -54.0, 52.0, 194.0]
const COLUMN_HALF_WIDTHS := [3.6, 3.6, 4.2, 3.6]
const AVENUE := 52.0
const AVENUE_LANE := 3.7
const PARKING_WIDTH := 2.5
const ROW_HALF_WIDTHS := [3.6, 3.6, AVENUE_LANE + PARKING_WIDTH, 3.6]
const WALK_WIDTH := 2.25
const AVENUE_WALK := 3.45
const CURB_WIDTH := 0.42
const GROUND_STEP := 6
const TERRAIN := Rect2(-432, -416, 864, 832)
const STREET_BOUNDS := Rect2(-198, -180, 410, 378)
const PLAZA := Rect2(-54, -42, 108, 84.8)
const MARKET := Vector2(-120, 71.5)
const SPAWN := Vector2(-174, AVENUE + AVENUE_LANE * 0.5)


static func walk_width(z: float) -> float:
	return AVENUE_WALK if z == AVENUE else WALK_WIDTH


static func road_distance(point: Vector2) -> float:
	var distance := INF
	for index in COLUMNS.size():
		distance = minf(distance, absf(point.x - COLUMNS[index]) - COLUMN_HALF_WIDTHS[index])
	for index in ROWS.size():
		distance = minf(distance, absf(point.y - ROWS[index]) - ROW_HALF_WIDTHS[index])
	return maxf(distance, _outside_streets(point))


static func road_finish(point: Vector2) -> Color:
	var x := _nearest_street(point.x, COLUMNS)
	var z := _nearest_street(point.y, ROWS)
	var across_x := absf(point.x - COLUMNS[x])
	var across_z := absf(point.y - ROWS[z])
	var dx := across_x - float(COLUMN_HALF_WIDTHS[x])
	var dz := across_z - float(ROW_HALF_WIDTHS[z])
	var edge := maxf(minf(dx, dz), _outside_streets(point))
	var lane := across_x if dx < dz else across_z
	var straight := smoothstep(0.0, 9.0, maxf(dx, dz))
	return Color(clampf(-edge / 3.0, 0.0, 1.0), clampf(lane / 8.0, 0.0, 1.0), straight)


static func ground_kind(point: Vector2) -> String:
	var distance := road_distance(point)
	if distance < 0.0:
		return "asphalt"
	if distance < CURB_WIDTH:
		return "curb"
	if distance < WALK_WIDTH or (absf(point.y - AVENUE) < ROW_HALF_WIDTHS[2] + AVENUE_WALK and _outside_streets(point) < AVENUE_WALK):
		return "sidewalk"
	return "grass"


static func height_at(point: Vector2) -> float:
	var x_index := _nearest_street(point.x, COLUMNS)
	var z_index := _nearest_street(point.y, ROWS)
	var x_offset := absf(point.x - COLUMNS[x_index])
	var z_offset := absf(point.y - ROWS[z_index])
	var dx := x_offset - float(COLUMN_HALF_WIDTHS[x_index])
	var dz := z_offset - float(ROW_HALF_WIDTHS[z_index])
	var x_blend := (1.0 - smoothstep(0.0, 13.0, dx)) * smoothstep(0.0, 12.0, dz)
	var z_blend := (1.0 - smoothstep(0.0, 13.0, dz)) * smoothstep(0.0, 12.0, dx)
	var grade_point := point.lerp(Vector2(COLUMNS[x_index], point.y), x_blend * 0.90)
	grade_point = grade_point.lerp(Vector2(grade_point.x, ROWS[z_index]), z_blend * 0.90)
	var distance := maxf(minf(dx, dz), _outside_streets(point))
	var crown := 0.012 * (maxf(-dx, 0.0) * x_blend + maxf(-dz, 0.0) * z_blend)
	var crossing := 0.035 + 0.105 * smoothstep(3.1, 8.0, maxf(dx, dz))
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
	var northwest := _ridge(point + Vector2(150, 158), Vector2(0.74, -0.67), Vector2(213, 155), 23.0)
	var southeast := _ridge(point - Vector2(148, 172), Vector2(0.80, -0.60), Vector2(174, 123), 15.0)
	var valley := _ridge(point - Vector2(60, 55), Vector2(0.58, 0.81), Vector2(370, 124), -9.0)
	var background := _ridge(point + Vector2(345, 385), Vector2(0.89, 0.46), Vector2(242, 86), 26.0)
	background += _ridge(point - Vector2(348, 380), Vector2(0.91, -0.41), Vector2(205, 90), 25.0)
	background += _ridge(point - Vector2(405, -125), Vector2(0.25, 0.97), Vector2(175, 72), 29.0)
	var shoulder := 1.23 * sin(point.x / 48.0 + point.y / 92.0) + 0.69 * sin(point.y / 34.0 - point.x / 87.0)
	return 26.0 - 0.010 * point.x - 0.025 * point.y + northwest + southeast + valley + shoulder + background


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
