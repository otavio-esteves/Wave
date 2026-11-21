extends RefCounted

const Route = preload("res://scripts/city/figueiras_route.gd")
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
const MAP_BOUNDS := Rect2(-217, -318, 580, 652)
const PLAZA := Rect2(-53, -42, 104, 80.0)
const MARKET := Vector2(-128.5, 75.1)
const RESERVOIR := Vector2(251, 15)
const LAKE := Vector2(275, 123)
const LAKE_RADII := Vector2(36.5, 37.0)
const LAKE_LEVEL := 30.65
const GALLERY_START := 344.0
const GALLERY_END := 392.0
const CREEK_WATER_LEVEL := 13.9
const CREEK_RANGE := Vector2(217.0, 389.0)
const SPAWN := Vector2(-174, AVENUE + AVENUE_LANE * 0.5)
static var _routes: Array[Route] = []
static var _nursery_frame := Transform2D.IDENTITY
static var _nursery_elevation := 0.0


static func scenic_routes() -> Array[Route]:
	if not _routes.is_empty():
		return _routes
	var zero := Vector2.ZERO
	var west := Vector2(COLUMNS[0], -173)
	var north_east := Vector2(COLUMNS[3], -173)
	var east := Vector2(210, AVENUE)
	var south_east := Vector2(210, ROWS[3])
	_routes = [
		Route.new("Estrada do Mirante", 10.8, [
			[west, zero, Vector2(0, -42)],
			[Vector2(-157, -277), Vector2(-37, 0), Vector2(49, 0)],
			[Vector2(-23, -264), Vector2(-46, -10), Vector2(37, 8)],
			[Vector2(117, -296), Vector2(-51, -1), Vector2(51, 1)],
			[Vector2(COLUMNS[3], -228), Vector2(0, -39), Vector2(0, 22)],
			[north_east, Vector2(0, -22), zero],
		], PackedVector2Array([Vector2(0, _grid_height(west)), Vector2(0.21, 67), Vector2(0.43, 73.5),
			Vector2(0.63, 65.4), Vector2(0.81, 53.9), Vector2(1, _grid_height(north_east))]), 0.43, Vector2(LOCAL_HALF, LOCAL_HALF)),
		Route.new("Contorno das Águas", 11.4, [
			[east, zero, Vector2(42, 0)],
			[Vector2(302, 63), Vector2(-33, -8), Vector2(29, 9)],
			[Vector2(340, 125), Vector2(0, -32), Vector2(0, 32)],
			[Vector2(300, 185), Vector2(27, -9), Vector2(-34, 11)],
			[south_east, Vector2(38, 0), zero],
		], PackedVector2Array([Vector2(0, _grid_height(east)), Vector2(0.26, 32.3), Vector2(0.54, 40.5),
			Vector2(0.74, 42.0), Vector2(0.87, 40.0), Vector2(1, _grid_height(south_east))]), 0.54, Vector2(AVENUE_HALF, LOCAL_HALF)),
		Route.new("Estrada do Vale", 10.6, [
			[Vector2(COLUMNS[0], 191), zero, Vector2(0, 36)],
			[Vector2(-174, 273), Vector2(-23, -13), Vector2(38, 22)],
			[Vector2(-82, 301), Vector2(-36, 0), Vector2(40, 0)],
			[Vector2(27, 287), Vector2(-37, 6), Vector2(42, -7)],
			[Vector2(139, 311), Vector2(-34, -8), Vector2(45, 11)],
			[Vector2(COLUMNS[3], 249), Vector2(0, 35), Vector2(0, -31)],
			[Vector2(COLUMNS[3], 191), Vector2(0, 22), zero],
		], PackedVector2Array([Vector2(0, _grid_height(Vector2(COLUMNS[0], 191))),
			Vector2(0.18, 29.4), Vector2(0.43, 18.3), Vector2(0.61, 22.4), Vector2(0.80, 33.5),
			Vector2(1, _grid_height(Vector2(COLUMNS[3], 191)))]), 0.64, Vector2(LOCAL_HALF, LOCAL_HALF)),
	]
	var valley := _routes[2]
	var nursery_station := valley.stop_station + 4.0
	var axis := valley.direction_at(nursery_station)
	_nursery_frame = Transform2D(axis, axis.orthogonal(), valley.offset_at(nursery_station, -24.0))
	_nursery_elevation = valley.height_at(nursery_station) + 0.84
	return _routes


static func scenic_sample(point: Vector2) -> Vector4:
	if point.y > -130.0 and point.y < 173.0 and point.x < 170.0:
		return Vector4(-1, 0, 0, INF)
	var routes := scenic_routes()
	var best := Vector4(-1, 0, 0, INF)
	for index in routes.size():
		var sample := routes[index].project(point)
		if sample.z < best.w:
			best = Vector4(index, sample.x, sample.y, sample.z)
	return best


static func scenic_edge(sample: Vector4) -> float:
	return sample.w - scenic_routes()[int(sample.x)].edge_at(sample.y, sample.z) if sample.x >= 0 else INF


static func walk_width(z: float) -> float:
	return AVENUE_WALK if z == AVENUE else WALK_WIDTH


static func road_distance(point: Vector2) -> float:
	return minf(_grid_distance(point), scenic_edge(scenic_sample(point)))


static func _grid_distance(point: Vector2) -> float:
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
	var route := scenic_sample(point)
	var margin := scenic_edge(route)
	if margin < edge:
		edge = margin
		lane = absf(route.z)
		straight = 1.0
		avenue = 0.0
	return Color(clampf(-edge / 3.0, 0.0, 1.0), clampf(lane / 12.0, 0.0, 1.0), straight, avenue)


static func ground_band(point: Vector2) -> float:
	var distance := road_distance(point)
	if distance <= CURB_WIDTH:
		return distance
	var commercial := 1.0 - smoothstep(AVENUE_HALF + AVENUE_WALK, AVENUE_HALF + AVENUE_WALK + 4.0, absf(point.y - AVENUE))
	return CURB_WIDTH + (distance - CURB_WIDTH) * (WALK_WIDTH - CURB_WIDTH) / (lerpf(WALK_WIDTH, AVENUE_WALK, commercial) - CURB_WIDTH)


static func lake_outline(angle: float) -> Vector2:
	return Vector2.from_angle(angle) * LAKE_RADII * _lake_inlet(angle)


static func lake_distance(point: Vector2) -> float:
	var offset := (point - LAKE) / LAKE_RADII
	var distance := offset.length()
	return distance / _lake_inlet(offset.angle()) if distance < 1.75 else distance


static func _lake_inlet(angle: float) -> float:
	return 1.0 + 0.103 * sin(angle * 3.0 + 0.24) + 0.059 * sin(angle * 5.0 + 0.79)


static func creek_axis(z: float) -> float:
	return -40.0 + sin(z * 0.031) * 9.0 + sin(z * 0.065) * 3.4


static func creek_width(z: float) -> float:
	return 5.3 + sin(z * 0.18) * 1.35 + sin(z * 0.041) * 0.68


static func creek_weight(point: Vector2) -> float:
	if point.y <= CREEK_RANGE.x or point.y >= CREEK_RANGE.y:
		return 0.0
	var opening := smoothstep(CREEK_RANGE.x, CREEK_RANGE.x + 33.0, point.y)
	opening *= 1.0 - smoothstep(CREEK_RANGE.y - 35.0, CREEK_RANGE.y, point.y)
	return opening * (1.0 - smoothstep(4.5, 25.0, absf(point.x - creek_axis(point.y))))


static func gallery_shadow(point: Vector2) -> float:
	if point.y > -235.0 or point.x < 10.0 or point.x > 180.0:
		return 0.0
	var sample := scenic_routes()[0].project(point)
	if sample.z > 7.5:
		return 0.0
	return smoothstep(GALLERY_START - 0.8, GALLERY_START + 4.0, sample.x) * (1.0 - smoothstep(GALLERY_END - 4.0, GALLERY_END + 0.8, sample.x))


static func nursery_frame() -> Transform2D:
	scenic_routes()
	return _nursery_frame


static func nursery_terrace(point: Vector2) -> Vector2:
	if point.x < 68.0 or point.x > 122.0 or point.y < 297.0 or point.y > 349.0:
		return Vector2.ZERO
	var frame := nursery_frame()
	var offset := point - frame.origin
	var spread := 1.0 - smoothstep(6.95, 15.2, absf(offset.dot(frame.x)))
	var depth := offset.dot(frame.y)
	var cut := smoothstep(-14.0, -5.5, depth) * (1.0 - smoothstep(8.5, 11.5, depth))
	return Vector2(_nursery_elevation - depth * 0.047, spread * cut)


static func height_at(point: Vector2) -> float:
	var height := _grid_height(point)
	var creek := creek_weight(point)
	if creek > 0.0:
		var bed := CREEK_WATER_LEVEL - 0.83 + pow(absf(point.x - creek_axis(point.y)) / creek_width(point.y), 1.32)
		height = lerpf(height, bed, creek)
	var sample := scenic_sample(point)
	if sample.x >= 0 and sample.w < 40.0:
		var route := scenic_routes()[int(sample.x)]
		var edge := sample.w - route.edge_at(sample.y, sample.z)
		var run_in := smoothstep(4.0, 36.0, minf(sample.y, route.length - sample.y))
		var slope_margin := lerpf(Route.GRADE_MARGIN, 13.0, creek)
		var fit := (1.0 - smoothstep(2.4, slope_margin, edge)) * run_in
		var gutter := 0.11 * clampf(edge / CURB_WIDTH, 0.0, 1.0)
		var bank := clampf(sample.z, -route.half_width, route.half_width) * route.bank_at(sample.y)
		height = lerpf(height, route.height_at(sample.y) + bank + gutter, fit)
	var basin := lake_distance(point)
	if basin < 1.48:
		var shore := LAKE_LEVEL + (basin - 0.93) * 5.5
		height = lerpf(shore, height, smoothstep(1.06, 1.48, basin))
	var terrace := nursery_terrace(point)
	height = lerpf(height, terrace.x, terrace.y)
	return height


static func _grid_height(point: Vector2) -> float:
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
