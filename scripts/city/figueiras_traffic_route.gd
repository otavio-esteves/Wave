extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
var curve := Curve2D.new()
var length: float
var _height_samples := PackedFloat32Array()
var _height_step := 1.0


func _init(junctions: PackedVector2Array, reverse: bool, sampled_road := false) -> void:
	if junctions.is_empty():
		return
	if reverse:
		junctions = junctions.duplicate()
		junctions.reverse()
	var first_entry := Vector2.ZERO
	var first_handle := Vector2.ZERO
	curve.bake_interval = 1.15
	for index in junctions.size():
		var corner := junctions[index]
		var previous := junctions[posmod(index - 1, junctions.size())]
		var following := junctions[(index + 1) % junctions.size()]
		var incoming := (corner - previous).normalized()
		var outgoing := (following - corner).normalized()
		var lane_corner := corner + _shift(corner, incoming) + _shift(corner, outgoing)
		var radius := 5.0 if incoming.cross(outgoing) > 0.0 else 8.0
		if sampled_road:
			var tangent := (incoming + outgoing).normalized()
			lane_corner = corner + Vector2(-tangent.y, tangent.x) * 2.60 / maxf(tangent.dot(incoming), 0.65)
			radius = minf(radius, minf(corner.distance_to(previous), corner.distance_to(following)) * 0.42)
		var entry := lane_corner - incoming * radius
		var exit := lane_corner + outgoing * radius
		var handle := radius * 0.54
		curve.add_point(entry, Vector2.ZERO, incoming * handle)
		curve.add_point(exit, -outgoing * handle)
		if index == 0:
			first_entry = entry
			first_handle = incoming * handle
	curve.add_point(first_entry, Vector2.ZERO, first_handle)
	length = curve.get_baked_length()
	var count := ceili(length / 1.55)
	_height_step = length / count
	_height_samples.resize(count + 1)
	for sample in count + 1:
		_height_samples[sample] = Layout.height_at(point(sample * _height_step))


func baked_data() -> Dictionary:
	return {"curve": curve, "length": length, "heights": _height_samples, "step": _height_step}


static func from_bake(data: Dictionary) -> RefCounted:
	var route := new(PackedVector2Array(), false)
	route.curve = data.curve
	route.length = data.length
	route._height_samples = data.heights
	route._height_step = data.step
	return route


static func baixada_loop() -> PackedVector2Array:
	var avenue := Layout.district_routes()[Layout.Baixada.AVENIDA]
	var vale := Layout.scenic_routes()[2]
	var joins := Layout.Baixada.junctions(vale)
	var points := PackedVector2Array()
	var segments := ceili(avenue.length / 13.0)
	for index in segments:
		points.append(avenue.point_at(avenue.length * index / segments))
	segments = ceili((joins[1] - joins[0]) / 13.0)
	for index in segments:
		points.append(vale.point_at(lerpf(joins[1], joins[0], float(index) / segments)))
	return points


func point(station: float) -> Vector2:
	return curve.sample_baked(fposmod(station, length), true)


func elevation(station: float) -> float:
	var index := fposmod(station, length) / _height_step
	var lower := mini(floori(index), _height_samples.size() - 2)
	return lerpf(_height_samples[lower], _height_samples[lower + 1], index - lower)


func direction(station: float) -> Vector2:
	return (point(station + 1.5) - point(station - 1.5)).normalized()


func _shift(corner: Vector2, direction: Vector2) -> Vector2:
	var offset := 1.80
	if direction.x != 0.0 and corner.y == Layout.AVENUE:
		offset = Layout.AVENUE_MEDIAN_HALF + Layout.AVENUE_LANE * 1.5
	elif direction.y != 0.0 and corner.x == Layout.COLLECTOR:
		offset = 2.85
	return Vector2(-direction.y, direction.x) * offset
