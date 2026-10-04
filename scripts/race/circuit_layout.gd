extends RefCounted

# Closed, clockwise route, measured in meters. The first section is the grid straight.
const FINISH := Vector3(-280, 0, 390)
const CONTROL: Array[Vector3] = [
	Vector3(-360, 0, 390), Vector3(0, 0, 390), Vector3(360, 0, 390),
	Vector3(440, 0, 350), Vector3(490, 0, 190), Vector3(490, 0, -110),
	Vector3(280, 0, -340), Vector3(100, 0, -190), Vector3(-90, 0, -340),
	Vector3(-350, 0, -350), Vector3(-500, 0, -120), Vector3(-500, 0, 140),
	Vector3(-450, 0, 320), Vector3(-430, 0, 390),
]
const HALF_WIDTH := 8.5

static func route() -> PackedVector3Array:
	var dense := PackedVector3Array()
	for index in CONTROL.size():
		var a := CONTROL[posmod(index - 1, CONTROL.size())]
		var b := CONTROL[index]
		var c := CONTROL[(index + 1) % CONTROL.size()]
		var d := CONTROL[(index + 2) % CONTROL.size()]
		var steps := ceili((b.distance_to(c) + a.distance_to(b) + c.distance_to(d)) / 1.5)
		for step in steps:
			var t := float(step) / steps
			dense.append(0.5 * (2.0 * b + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
	# Resample by arc length: short control spans beside long straights otherwise
	# leave large gaps, including across the last/first pair.
	var points := PackedVector3Array()
	var until_next := 0.0
	for index in dense.size():
		var a := dense[index]
		var segment := dense[(index + 1) % dense.size()] - a
		var distance := segment.length()
		while until_next < distance:
			points.append(a + segment * (until_next / distance))
			until_next += 5.0
		until_next -= distance
	if points[-1].distance_to(points[0]) < 0.2:
		points.remove_at(points.size() - 1)
	return points

static func tangent(points: PackedVector3Array, index: int) -> Vector3:
	return (points[(index + 1) % points.size()] - points[posmod(index - 1, points.size())]).normalized()

static func length_m(points: PackedVector3Array) -> float:
	var length := 0.0
	for index in points.size():
		length += points[index].distance_to(points[(index + 1) % points.size()])
	return length
