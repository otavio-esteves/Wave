extends RefCounted

const HALF_WIDTH := 4.2
const CONTROL := [Vector3(0,0,170), Vector3(0,0,80), Vector3(-35,0,-15), Vector3(5,0,-100), Vector3(100,0,-130), Vector3(145,0,-215), Vector3(80,0,-290), Vector3(-35,0,-255), Vector3(-145,0,-320), Vector3(-210,0,-245), Vector3(-205,0,-140), Vector3(-275,0,-70), Vector3(-245,0,50), Vector3(-320,0,140), Vector3(-420,0,100)]

static func height_at(x: float, z: float) -> float:
	return 25.0 + 10.0 * sin(x / 110.0) + 7.0 * sin(z / 95.0) + 5.0 * sin((x + z) / 160.0)

static func ground(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)

static func normal_at(x: float, z: float) -> Vector3:
	var dx := (height_at(x + 0.1, z) - height_at(x - 0.1, z)) / 0.2
	var dz := (height_at(x, z + 0.1) - height_at(x, z - 0.1)) / 0.2
	return Vector3(-dx, 1, -dz).normalized()

static func route() -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in CONTROL.size() - 1:
		var a: Vector3 = CONTROL[maxi(0, index - 1)]
		var b: Vector3 = CONTROL[index]
		var c: Vector3 = CONTROL[index + 1]
		var d: Vector3 = CONTROL[mini(CONTROL.size() - 1, index + 2)]
		var steps := ceili(b.distance_to(c) / 2.0)
		for sample in steps:
			var t := float(sample) / steps
			var point := 0.5 * ((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t)
			result.append(ground(point.x, point.z))
	var last: Vector3 = CONTROL[-1]
	result.append(ground(last.x, last.z))
	return result

static func tangent(points: PackedVector3Array, index: int) -> Vector3:
	return (points[mini(index + 1, points.size()-1)] - points[maxi(index - 1, 0)]).normalized()

static func length_m(points: PackedVector3Array) -> float:
	var length := 0.0
	for index in points.size()-1:
		length += points[index].distance_to(points[index+1])
	return length
