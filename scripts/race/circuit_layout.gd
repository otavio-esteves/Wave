extends RefCounted

# Closed, clockwise route, measured in meters. The first section is the grid straight.
const CONTROL: Array[Vector3] = [
	Vector3(-120, 0, 150), Vector3(0, 0, 150), Vector3(120, 0, 150),
	Vector3(190, 0, 95), Vector3(190, 0, -30), Vector3(135, 0, -110),
	Vector3(70, 0, -70), Vector3(5, 0, -115), Vector3(-115, 0, -140),
	Vector3(-195, 0, -85), Vector3(-195, 0, 65), Vector3(-165, 0, 130),
]
const HALF_WIDTH := 7.0

static func route() -> PackedVector3Array:
	var points := PackedVector3Array()
	for index in CONTROL.size():
		var a := CONTROL[posmod(index - 1, CONTROL.size())]
		var b := CONTROL[index]
		var c := CONTROL[(index + 1) % CONTROL.size()]
		var d := CONTROL[(index + 2) % CONTROL.size()]
		var steps := ceili(b.distance_to(c) / 4.0)
		for step in steps:
			var t := float(step) / steps
			points.append(0.5 * (2.0 * b + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
	return points

static func tangent(points: PackedVector3Array, index: int) -> Vector3:
	return (points[(index + 1) % points.size()] - points[posmod(index - 1, points.size())]).normalized()

static func length_m(points: PackedVector3Array) -> float:
	var length := 0.0
	for index in points.size():
		length += points[index].distance_to(points[(index + 1) % points.size()])
	return length
