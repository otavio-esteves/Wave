extends RefCounted

# Eighteen connected blocks and exactly three times the original terrain area.
# Connectivity is authored independently of the curving streets and hills.
const COLUMNS := [-300.0, -200.0, -95.0, 10.0, 110.0, 210.0, 300.0]
const ROWS := [-160.0, -55.0, 55.0, 165.0]
const COLUMN_COUNT := 7
const ROW_COUNT := 4
const NODE_COUNT := COLUMN_COUNT * ROW_COUNT
const HALF_WIDTH := 384.0
const HALF_DEPTH := 308.0
const TERRAIN_STEP := 4.0
const ROAD_LIFT := 0.025
const CAR_LIFT := 0.38
const BLOCK_COUNT := 18
const PLANNED_BLOCK_COUNT := 18
const ORIGINAL_AREA_M2 := 448.0 * 352.0
const SQUARE_BLOCK := 14
const WORKSHOP_BLOCK := 11
const OUTER_LOOP := [21, 22, 23, 24, 25, 26, 27, 20, 13, 6, 5, 4, 3, 2, 1, 0, 7, 14, 21]
const CENTRE_LOOP := [15, 16, 17, 18, 11, 10, 9, 8, 15]
const HILL_LOOP := [3, 4, 5, 6, 13, 12, 11, 10, 3]
const BLOCK_NAMES := ["Bosque do Vale", "Casas do Vale", "Praça da Encosta", "Alameda Alta", "Colina", "Largo dos Ipês", "Vila das Flores", "Residencial", "Avenida Central", "Centro", "Jardim da Serra", "Oficina", "Parque do Vale", "Travessa do Lago", "Praça", "Rua das Casas", "Mirante", "Jardim dos Cedros"]


static func warp(u: float, v: float) -> Vector2:
	return Vector2(u + 20.0 * sin(v / 72.0) + 6.0 * sin(u / 140.0) * sin(v / 130.0),
		v + 14.0 * sin(u / 100.0) + 7.0 * sin(v / 120.0) * cos(u / 150.0))


static func _height(x: float, z: float) -> float:
	var hills := 11.0 * exp(-pow((x - 160.0) / 155.0, 2) - pow((z + 110.0) / 165.0, 2))
	hills += 5.0 * exp(-pow((x + 205.0) / 145.0, 2) - pow((z - 40.0) / 155.0, 2))
	var valley := 1.5 * exp(-pow((x + 30.0) / 110.0, 2) - pow((z + 80.0) / 80.0, 2))
	return 2.0 + 0.003 * (x + HALF_WIDTH) + hills - valley + 1.2 * sin(x / 130.0) * sin(z / 115.0)



static func height_at(x: float, z: float) -> float:
	# Match the diagonals of the saved terrain, rather than a different analytic hill.
	var x0 := floorf((x + HALF_WIDTH) / TERRAIN_STEP) * TERRAIN_STEP - HALF_WIDTH
	var z0 := floorf((z + HALF_DEPTH) / TERRAIN_STEP) * TERRAIN_STEP - HALF_DEPTH
	var u := (x - x0) / TERRAIN_STEP
	var v := (z - z0) / TERRAIN_STEP
	var a := _height(x0, z0)
	var b := _height(x0 + TERRAIN_STEP, z0)
	var c := _height(x0, z0 + TERRAIN_STEP)
	var d := _height(x0 + TERRAIN_STEP, z0 + TERRAIN_STEP)
	return a + (b - a) * u + (c - a) * v if u + v <= 1.0 else d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)


static func position(u: float, v: float, lift: float = 0.0) -> Vector3:
	var p := warp(u, v)
	return Vector3(p.x, height_at(p.x, p.y) + lift, p.y)


static func logical_node(id: int) -> Vector2:
	return Vector2(COLUMNS[id % COLUMN_COUNT], ROWS[id / COLUMN_COUNT])


static func node(id: int) -> Vector3:
	var p := logical_node(id)
	return position(p.x, p.y)


static func edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in ROW_COUNT:
		for column in COLUMN_COUNT - 1:
			result.append({"a": row * COLUMN_COUNT + column, "b": row * COLUMN_COUNT + column + 1, "width": 14.0 if row == 1 else 12.0})
	for column in COLUMN_COUNT:
		for row in ROW_COUNT - 1:
			result.append({"a": row * COLUMN_COUNT + column, "b": (row + 1) * COLUMN_COUNT + column, "width": 11.5})
	return result


static func edge_points(a: int, b: int) -> PackedVector3Array:
	var start := logical_node(a)
	var end := logical_node(b)
	var count := ceili(start.distance_to(end) / 2.0)
	var result := PackedVector3Array()
	for index in count + 1:
		var p := street_uv(a, b, float(index) / count)
		result.append(position(p.x, p.y, ROAD_LIFT))
	return result


static func street_uv(a: int, b: int, t: float) -> Vector2:
	# Bow each street independently, retaining shared endpoints and their tangents.
	# This gives the blocks distinct outlines rather than a uniformly warped grid.
	if a > b:
		return street_uv(b, a, 1.0 - t)
	var start := logical_node(a)
	var end := logical_node(b)
	var horizontal := a / COLUMN_COUNT == b / COLUMN_COUNT
	var bend: float = [8.0, -12.0, 10.0, -14.0, 12.0, -8.0][a % COLUMN_COUNT] * [1.0, -0.6, 0.8, -0.8][a / COLUMN_COUNT] if horizontal else [-10.0, 12.0, -13.0, 9.0, -12.0, 13.0, -8.0][a % COLUMN_COUNT] * [1.0, -0.7, 0.9][a / COLUMN_COUNT]

	var forward := (end - start).normalized()
	return start.lerp(end, t) + Vector2(-forward.y, forward.x) * bend * pow(sin(PI * t), 2)


static func route(ids: Array, lane: float = 0.0) -> PackedVector3Array:
	# Driving reference follows rounded turns within the paved junction discs.
	var result := PackedVector3Array()
	for index in ids.size() - 1:
		var points := edge_points(ids[index], ids[index + 1])
		var first := 5 if index > 0 else 0
		var last := points.size() - 6 if index < ids.size() - 2 else points.size() - 1
		for step in range(first, last):
			result.append(_lane_point(points, step, lane))
		if index < ids.size() - 2:
			var following := edge_points(ids[index + 1], ids[index + 2])
			var start := _lane_point(points, last, lane)
			var end := _lane_point(following, 5, lane)
			var corner := node(ids[index + 1])
			for sample in 12:
				var t := float(sample) / 12.0
				var p := start.lerp(corner, t).lerp(corner.lerp(end, t), t)
				p.y = height_at(p.x, p.z) + CAR_LIFT
				result.append(p)
	var end := node(ids.back())
	end.y += CAR_LIFT
	result.append(end)
	return result


static func _lane_point(points: PackedVector3Array, step: int, lane: float) -> Vector3:
	var forward := (points[step + 1] - points[step]).normalized()
	var p := points[step] + forward.cross(Vector3.UP).normalized() * lane
	p.y = height_at(p.x, p.z) + CAR_LIFT
	return p


static func spawn() -> Transform3D:
	var points := route([23, 24], 1.8)
	var forward := points[8] - points[7]
	return Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), points[7])


static func square_access() -> PackedVector3Array:
	return _access(street_uv(23, 24, 0.5), Vector2(-42.5, 110.0))


static func workshop_access() -> PackedVector3Array:
	return _access(street_uv(13, 20, 0.5), Vector2(288.0, 0.0))


static func _access(start: Vector2, end: Vector2) -> PackedVector3Array:
	var points := PackedVector3Array()
	var count := ceili(start.distance_to(end) / 2)
	for index in count + 1:
		var p := start.lerp(end, float(index) / count)
		points.append(position(p.x, p.y, CAR_LIFT))
	return points


static func terrain_faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	for row in int(HALF_DEPTH * 2 / TERRAIN_STEP):
		for column in int(HALF_WIDTH * 2 / TERRAIN_STEP):
			var x := -HALF_WIDTH + column * TERRAIN_STEP
			var z := -HALF_DEPTH + row * TERRAIN_STEP
			var a := Vector3(x, _height(x, z), z)
			var b := Vector3(x + TERRAIN_STEP, _height(x + TERRAIN_STEP, z), z)
			var c := Vector3(x, _height(x, z + TERRAIN_STEP), z + TERRAIN_STEP)
			var d := Vector3(x + TERRAIN_STEP, _height(x + TERRAIN_STEP, z + TERRAIN_STEP), z + TERRAIN_STEP)
			faces.append_array(PackedVector3Array([a, b, c, b, d, c]))
	return faces
