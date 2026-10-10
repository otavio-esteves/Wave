extends RefCounted

# Three districts in one connected map; four times the preceding 72-block area.
const COLUMNS := [-1370.0, -1220.0, -1070.0, -914.0, -754.0, -594.0, -424.0, -254.0, -84.0, 76.0, 236.0, 396.0, 556.0, 676.0, 766.0, 856.0, 946.0, 1046.0, 1146.0, 1256.0, 1370.0]
const ROWS := [-1050.0, -840.0, -610.0, -390.0, -170.0, 20.0, 200.0, 390.0, 590.0, 820.0, 1040.0]
const COLUMN_COUNT := 21
const ROW_COUNT := 11
const NODE_COUNT := COLUMN_COUNT * ROW_COUNT
const HALF_WIDTH := 1536.0
const HALF_DEPTH := 1232.0
# Smooth hills need no extra terrain triangles; roads retain their 2 m sampling.
const TERRAIN_STEP := 8.0
const ROAD_LIFT := 0.025
const CAR_LIFT := 0.38
const BLOCK_COUNT := 200
const PLANNED_BLOCK_COUNT := BLOCK_COUNT
const ORIGINAL_AREA_M2 := 448.0 * 352.0
const PREVIOUS_AREA_M2 := 1536.0 * 1232.0
const SQUARE_BLOCK := 145
const WORKSHOP_BLOCK := 65
const PARK_BLOCKS := [0, 23, 46, 62, 86, 103, 124, SQUARE_BLOCK, 163, 186, 76, 77, 96, 97, 116, 117, 136, 137]
# Representative tours: all three districts, downtown and the residential hills.
const OUTER_LOOP := [110,111,112,113,114,115,116,117,118,119,120,141,140,139,138,137,136,135,134,133,132,131,110]
const CENTRE_LOOP := [119,120,121,122,143,142,141,140,119]
const HILL_LOOP := [87,88,89,90,111,110,109,108,87]
const DISTRICT_NAMES := ["Jardins do Vale", "Vila Aurora", "Centro Horizonte"]
const BLOCK_NAMES := ["Bosque", "Ipês", "Cedros", "Largo", "Jardim", "Colina", "Alameda", "Residencial", "Vila", "Mirante", "Travessa", "Encosta"]


static func block_name(id: int) -> String:
	return "%s — %s %d" % [DISTRICT_NAMES[district(id)], BLOCK_NAMES[(id * 7 + id / 20) % BLOCK_NAMES.size()], id + 1]


static func district(id: int) -> int:
	var column := id % (COLUMN_COUNT - 1)
	return 0 if column < 6 else (1 if column < 13 else 2)


static func district_at(x: float) -> String:
	return DISTRICT_NAMES[0 if x < -424 else (1 if x < 676 else 2)]


static func warp(u: float, v: float) -> Vector2:
	# Curving garden streets gradually settle into the downtown avenue grid.
	var organic := 1.0 - 0.88 * smoothstep(440.0, 800.0, u)
	return Vector2(u + organic * (26.0 * sin(v / 240.0) + 14.0 * sin(u / 310.0) * sin(v / 270.0)),
		v + organic * (23.0 * sin(u / 290.0) + 12.0 * sin(v / 240.0) * cos(u / 360.0)))


static func _height(x: float, z: float) -> float:
	var hills := 19.0 * exp(-pow((x + 870.0) / 390.0, 2) - pow((z + 370.0) / 370.0, 2))
	hills += 10.0 * exp(-pow((x + 1000.0) / 320.0, 2) - pow((z - 600.0) / 330.0, 2))
	hills += 7.0 * exp(-pow((x + 60.0) / 330.0, 2) - pow((z - 650.0) / 300.0, 2))
	var valley := 3.5 * exp(-pow((x + 230.0) / 420.0, 2) - pow((z + 140.0) / 350.0, 2))
	return 3.0 + 0.0015 * (x + HALF_WIDTH) + hills - valley + 0.8 * sin(x / 310.0) * sin(z / 275.0)


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
			result.append({"a": row * COLUMN_COUNT + column, "b": row * COLUMN_COUNT + column + 1, "width": 22.0 if row in [4, 5, 8] else (16.0 if column >= 13 else 12.0)})
	for column in COLUMN_COUNT:
		for row in ROW_COUNT - 1:
			result.append({"a": row * COLUMN_COUNT + column, "b": (row + 1) * COLUMN_COUNT + column, "width": 24.0 if column in [6, 13, 16, 19] else (16.0 if column >= 13 else 11.5)})
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
	var organic := 1.0 - 0.92 * smoothstep(440.0, 800.0, (start.x + end.x) / 2)
	var bend := organic * (7.0 + 8.0 * sin(a * 1.73 + b * 0.47)) * (1.0 if horizontal else -1.0)


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
	var points := route([150, 151], 1.8)
	var forward := points[8] - points[7]
	return Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), points[7])


static func block_uv(id: int) -> Vector2:
	var column := id % (COLUMN_COUNT - 1)
	var row := id / (COLUMN_COUNT - 1)
	return Vector2((COLUMNS[column] + COLUMNS[column + 1]) / 2, (ROWS[row] + ROWS[row + 1]) / 2)


static func square_access() -> PackedVector3Array:
	return _access(street_uv(173, 174, 0.5), block_uv(SQUARE_BLOCK))


static func workshop_access() -> PackedVector3Array:
	return _access(street_uv(69, 90, 0.5), block_uv(WORKSHOP_BLOCK) + Vector2(38, 0))


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
