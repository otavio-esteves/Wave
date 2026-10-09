extends RefCounted

# Six connected blocks are the first increment of the planned fifteen-block city.
# The logical coordinates describe connectivity; the warp authors the actual streets.
const COLUMNS := [-155.0, -60.0, 45.0, 145.0]
const ROWS := [-100.0, 0.0, 105.0]
const HALF_WIDTH := 224.0
const HALF_DEPTH := 176.0
const TERRAIN_STEP := 4.0
const ROAD_LIFT := 0.025
const CAR_LIFT := 0.38
const BLOCK_COUNT := 6
const PLANNED_BLOCK_COUNT := 15
const OUTER_LOOP := [8, 9, 10, 11, 7, 3, 2, 1, 0, 4, 8]
const CENTRE_LOOP := [8, 9, 5, 6, 10, 9, 8]
const HILL_LOOP := [5, 1, 2, 3, 7, 6, 5]
const BLOCK_NAMES := ["Casas do Vale", "Rua das Casas", "Encosta", "Praça", "Centro", "Oficina"]


static func warp(u: float, v: float) -> Vector2:
	return Vector2(u + 14.0 * sin(v / 60.0) + 6.0 * sin(u / 120.0) * sin(v / 100.0),
		v + 10.0 * sin(u / 65.0) + 9.0 * sin(v / 100.0) * cos(u / 100.0))


static func _height(x: float, z: float) -> float:
	return 2.0 + 0.006 * (x + HALF_WIDTH) + 12.0 * exp(-pow((x - 110.0) / 125.0, 2) - pow((z + 80.0) / 140.0, 2))


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
	return Vector2(COLUMNS[id % 4], ROWS[id / 4])


static func node(id: int) -> Vector3:
	var p := logical_node(id)
	return position(p.x, p.y)


static func edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in 3:
		for column in 3:
			result.append({"a": row * 4 + column, "b": row * 4 + column + 1, "width": 10.0 if row == 1 else 9.0})
	for column in 4:
		for row in 2:
			result.append({"a": row * 4 + column, "b": (row + 1) * 4 + column, "width": 8.0})
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
	var horizontal := a / 4 == b / 4
	var bend: float = [8.0, -16.0, 13.0][a % 4] * (1.0 if a / 4 == 0 else -0.65 if a / 4 == 1 else 1.2) if horizontal else [-14.0, 16.0, -18.0, 12.0][a % 4] * (1.0 if a / 4 == 0 else -0.75)
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
	var points := route([8, 9], 1.8)
	var forward := points[8] - points[7]
	return Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), points[7])


static func square_access() -> PackedVector3Array:
	return _access(street_uv(8, 9, 0.5), Vector2(-107.5, 52.5))


static func workshop_access() -> PackedVector3Array:
	return _access(street_uv(7, 11, 0.5), Vector2(128.0, 52.5))


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
