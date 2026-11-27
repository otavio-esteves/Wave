extends RefCounted

const LENGTH := 156.0
const HALF_WIDTH := 3.35
const SIDEWALK_WIDTH := 1.92
const PAVED_SETBACK := 1.55
const CURB_WIDTH := 0.16
const CURB_RISE := 0.135
const SPAWN_STATION := 13.0
const SPAWN_OFFSET := 1.62
const SUN_DIRECTION := Vector3(-0.69, 0.24, -0.68)


static func half_width(station: float) -> float:
	# The two ends widen into paved turning areas.
	return HALF_WIDTH + 2.75 * (1.0 - smoothstep(6.0, 16.0, station) + smoothstep(136.0, 147.0, station))


static func grade(station: float) -> float:
	return 0.25 + station * 0.025 + sin(station * 0.042) * 0.37 + smoothstep(55.0, 97.0, station) * 0.21


static func paving_edge(station: float) -> float:
	var corner_setback := 0.93 * (1.0 - smoothstep(12.0, 22.0, station) + smoothstep(136.0, 145.0, station))
	return half_width(station) + SIDEWALK_WIDTH + PAVED_SETBACK + corner_setback


static func right(station: float) -> Vector2:
	return Vector2(1.0, 0.037 + 0.1976 * cos((station - 22.0) * 0.052)).normalized()


static func center(station: float) -> Vector2:
	return Vector2(0.037 * (station - 48.0) + 3.8 * sin((station - 22.0) * 0.052), -station)


static func position_at(station: float, offset: float, lift := 0.0) -> Vector3:
	var point := center(station) + right(station) * offset
	var crown := minf(absf(offset), half_width(station)) * 0.014
	return Vector3(point.x, grade(station) - crown + lift, point.y)


static func coordinates(point: Vector2) -> Vector2:
	var station := -point.y
	for iteration in 2:
		var across := right(station)
		station += (point - center(station)).dot(Vector2(across.y, -across.x)) * across.x
	return Vector2((point - center(station)).dot(right(station)), station)


static func spawn() -> Transform3D:
	var yaw := -atan2(right(SPAWN_STATION).y, right(SPAWN_STATION).x)
	return Transform3D(Basis(Vector3.UP, yaw), position_at(SPAWN_STATION, SPAWN_OFFSET, 0.39))
