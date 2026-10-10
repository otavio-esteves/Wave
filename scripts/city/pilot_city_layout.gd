extends RefCounted

# Seventy-two connected blocks: four times the previous eighteen-block terrain.
const COLUMNS := [-600.0, -506.0, -396.0, -296.0, -174.0, -72.0, 24.0, 138.0, 226.0, 344.0, 442.0, 542.0, 640.0]
const ROWS := [-338.0, -230.0, -100.0, 8.0, 134.0, 232.0, 342.0]
const COLUMN_COUNT := 13
const ROW_COUNT := 7
const NODE_COUNT := COLUMN_COUNT * ROW_COUNT
const HALF_WIDTH := 768.0
const HALF_DEPTH := 616.0
const TERRAIN_STEP := 4.0
const ROAD_LIFT := 0.025
const CAR_LIFT := 0.38
const BLOCK_COUNT := 72
const PLANNED_BLOCK_COUNT := 72
const ORIGINAL_AREA_M2 := 448.0 * 352.0
const PREVIOUS_AREA_M2 := 768.0 * 616.0
const SQUARE_BLOCK := 53
const WORKSHOP_BLOCK := 35
const PARK_BLOCKS := [0, 17, 29, 44, SQUARE_BLOCK, 66]
const OUTER_LOOP := [78,79,80,81,82,83,84,85,86,87,88,89,90,77,64,51,38,25,12,11,10,9,8,7,6,5,4,3,2,1,0,13,26,39,52,65,78]
const CENTRE_LOOP := [43,44,45,46,47,34,33,32,31,30,43]
const HILL_LOOP := [7,8,9,10,23,36,35,34,33,20,7]
const BLOCK_NAMES := ["Bosque", "Ipês", "Cedros", "Largo", "Jardim", "Colina", "Alameda", "Residencial", "Vila", "Mirante", "Travessa", "Encosta"]


static func block_name(id: int) -> String:
	return "%s %s" % [BLOCK_NAMES[(id * 7 + id / 12) % BLOCK_NAMES.size()], ["do Vale", "das Flores", "da Serra", "do Sol", "dos Lagos", "dos Jardins"][id / 12]]


static func district(id: int) -> int:
	var row := id / (COLUMN_COUNT - 1)
	var column := id % (COLUMN_COUNT - 1)
	return 2 if column in [5, 6, 7] and row in [2, 3] else (1 if column >= 8 else 0)


static func warp(u: float, v: float) -> Vector2:
	return Vector2(u + 26.0 * sin(v / 170.0) + 14.0 * sin(u / 240.0) * sin(v / 190.0),
		v + 23.0 * sin(u / 210.0) + 12.0 * sin(v / 180.0) * cos(u / 260.0))


static func _height(x: float, z: float) -> float:
	var hills := 19.0 * exp(-pow((x - 360.0) / 245.0, 2) - pow((z + 180.0) / 250.0, 2))
	hills += 9.0 * exp(-pow((x + 390.0) / 210.0, 2) - pow((z - 180.0) / 230.0, 2))
	hills += 5.0 * exp(-pow((x - 100.0) / 180.0, 2) - pow((z - 350.0) / 180.0, 2))
	var valley := 3.5 * exp(-pow((x + 80.0) / 220.0, 2) - pow((z + 70.0) / 160.0, 2))
	return 3.0 + 0.002 * (x + HALF_WIDTH) + hills - valley + 1.4 * sin(x / 200.0) * sin(z / 175.0)



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
	var bend := (7.0 + 8.0 * sin(a * 1.73 + b * 0.47)) * (1.0 if horizontal else -1.0)


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
	var points := route([70, 71], 1.8)
	var forward := points[8] - points[7]
	return Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), points[7])


static func block_uv(id: int) -> Vector2:
	var column := id % (COLUMN_COUNT - 1)
	var row := id / (COLUMN_COUNT - 1)
	return Vector2((COLUMNS[column] + COLUMNS[column + 1]) / 2, (ROWS[row] + ROWS[row + 1]) / 2)


static func square_access() -> PackedVector3Array:
	return _access(street_uv(70, 71, 0.5), block_uv(SQUARE_BLOCK))


static func workshop_access() -> PackedVector3Array:
	return _access(street_uv(38, 51, 0.5), block_uv(WORKSHOP_BLOCK) + Vector2(38, 0))


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
