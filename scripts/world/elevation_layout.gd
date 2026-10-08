extends RefCounted

# Isolated height proof, not a general terrain manifest contract.
const CELL_LENGTH := 200.0
const HALF_WIDTH := 40.0
const STEP := 1.0
const CELL_COUNT := 4
const ROAD_HALF_WIDTH := 6.0
const SHOULDER_WIDTH := 2.0
const LOOKOUT_Z := -315.0
const PARK_LANE_MIN := 17.0
const PARK_LANE_MAX := 23.0
const PARK_Z_MIN := -324.0
const PARK_Z_MAX := -306.0


static func lookout_open(z: float) -> bool:
	return z < -260.0 and z > -360.0


static func lookout_edge(z: float) -> float:
	if not lookout_open(z):
		return 8.0
	var ramp := clampf(minf((-z - 260.0) / 25.0, (360.0 + z) / 25.0), 0, 1)
	return lerpf(8, 26, ramp * ramp * (3 - 2 * ramp))


static func height(z: float) -> float:
	if z >= -100.0 or z <= -500.0:
		return 0.0
	return 9.0 * (1.0 - cos(TAU * (-z - 100.0) / 400.0))


static func center_x(z: float) -> float:
	if z >= -80.0 or z <= -640.0:
		return 0.0
	var wave := sin(TAU * (-z - 80.0) / 560.0)
	return 12.0 * wave * wave * wave


static func point(z: float, lane_offset: float = 3.5) -> Vector3:
	return Vector3(center_x(z) + lane_offset, height(z) + 0.36, z)


static func heading(z: float, returning: bool = false) -> float:
	var direction := point(z + (1.0 if returning else -1.0)) - point(z)
	return atan2(-direction.x, -direction.z)


static func road_faces(origin_z: float, left: float, right: float, lift: float = 0.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in int(CELL_LENGTH / STEP):
		var z0 := -index * STEP
		var z1 := z0 - STEP
		var x0 := center_x(origin_z + z0)
		var x1 := center_x(origin_z + z1)
		var a := Vector3(x0 + left, height(origin_z + z0) + lift, z0)
		var b := Vector3(x0 + right, a.y, z0)
		var c := Vector3(x1 + left, height(origin_z + z1) + lift, z1)
		var d := Vector3(x1 + right, c.y, z1)
		result.append_array(PackedVector3Array([a, c, b, b, c, d]))
	return result


static func faces(origin_z: float, half_width: float = HALF_WIDTH, lift: float = 0.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in int(CELL_LENGTH / STEP):
		var z0 := -index * STEP
		var z1 := z0 - STEP
		var a := Vector3(-half_width, height(origin_z + z0) + lift, z0)
		var b := Vector3(half_width, a.y, z0)
		var c := Vector3(-half_width, height(origin_z + z1) + lift, z1)
		var d := Vector3(half_width, c.y, z1)
		# Godot's front face is clockwise when viewed from above.
		result.append_array(PackedVector3Array([a, c, b, b, c, d]))
	return result
