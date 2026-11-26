extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const BOUNDS := Rect2(-30.0, -181.0, 70.0, 207.0)
const PIXELS_PER_METER := 6
const SIZE := Vector2i(420, 1242)
const CONTACT_RANGE := 1.08

var _sunlight := PackedByteArray()
var _contact := PackedByteArray()
var _grain := FastNoiseLite.new()


func bake(solids: StaticBody3D, trees: Array[Vector4]) -> ImageTexture:
	_sunlight.resize(SIZE.x * SIZE.y)
	_contact.resize(SIZE.x * SIZE.y)
	_grain.seed = 39352
	_grain.frequency = 0.84
	_grain.fractal_octaves = 3
	for collider: CollisionShape3D in solids.get_children():
		var box := collider.shape as BoxShape3D
		var half := box.size * 0.5
		_footprint(collider.transform, half)
		_box_shadow(collider.transform, half)
	for tree in trees:
		_crown(Vector3(tree.x, tree.y, tree.z), tree.w)
	var pixels := PackedByteArray()
	pixels.resize(SIZE.x * SIZE.y * 3)
	for y in SIZE.y:
		for x in SIZE.x:
			var index := y * SIZE.x + x
			var soft := _sunlight[index] * 4 + _sunlight[y * SIZE.x + maxi(x - 1, 0)] + _sunlight[y * SIZE.x + mini(x + 1, SIZE.x - 1)]
			soft += _sunlight[maxi(y - 1, 0) * SIZE.x + x] + _sunlight[mini(y + 1, SIZE.y - 1) * SIZE.x + x]
			var mottling := _grain.get_noise_2d(float(x) / PIXELS_PER_METER, float(y) / (2.6 * PIXELS_PER_METER))
			pixels[index * 3] = soft >> 3
			pixels[index * 3 + 1] = _contact[index]
			pixels[index * 3 + 2] = roundi(clampf(mottling * 0.84 + 0.5, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8, pixels)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _pixel(point: Vector3) -> Vector2:
	return (Vector2(point.x, point.z) - BOUNDS.position) * PIXELS_PER_METER


func _project(point: Vector3) -> Vector2:
	var sun := Layout.SUN_DIRECTION
	var projection := point
	for iteration in 2:
		var road := Layout.coordinates(Vector2(projection.x, projection.z))
		var grade := Layout.position_at(road.y, road.x).y
		projection = point - sun * ((point.y - grade) / sun.y)
	return _pixel(projection)


func _footprint(frame: Transform3D, half: Vector3) -> void:
	var pixel := _pixel(frame.origin)
	var extent := (Vector2(half.x, half.z).length() + CONTACT_RANGE) * PIXELS_PER_METER
	var bounds := _clip(Rect2(pixel - Vector2.ONE * extent, Vector2.ONE * extent * 2.0))
	var inverse := frame.basis.inverse()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var offset := (Vector2(x + 0.5, y + 0.5) - pixel) / PIXELS_PER_METER
			var local := inverse * Vector3(offset.x, 0.0, offset.y)
			var distance := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.z) - half.z, 0.0)).length()
			var contact := 1.0 - smoothstep(0.025, CONTACT_RANGE, distance)
			var index := y * SIZE.x + x
			_contact[index] = maxi(_contact[index], roundi(contact * 248.0))


func _box_shadow(frame: Transform3D, half: Vector3) -> void:
	var corners := PackedVector2Array()
	for x: float in [-half.x, half.x]:
		for y: float in [-half.y, half.y]:
			for z: float in [-half.z, half.z]:
				corners.append(_project(frame * Vector3(x, y, z)))
	var hull := Geometry2D.convex_hull(corners)
	var rect := Rect2(hull[0], Vector2.ZERO)
	for point in hull:
		rect = rect.expand(point)
	var bounds := _clip(rect)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var point := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(point, hull):
				_sunlight[y * SIZE.x + x] = 248


func _crown(site: Vector3, height: float) -> void:
	for cluster in 15:
		var angle := cluster * 2.399963
		var span := 0.09 + 0.12 * (1.0 - cluster / 15.0)
		var branch := Vector3(cos(angle) * span, 0.62 + 0.19 * cluster / 15.0, sin(angle) * span) * height
		var center := _project(site + branch)
		var radius := height * (0.095 + 0.028 * sin(angle)) * PIXELS_PER_METER
		var spread := Vector2(radius * 1.28, radius)
		var bounds := _clip(Rect2(center - spread, spread * 2.0))
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var point := Vector2(x + 0.5, y + 0.5) - center
				var distance := (point / spread).length()
				var gaps := 0.56 + 0.44 * smoothstep(-0.48, 0.34, _grain.get_noise_2d(x * 0.37, y * 0.37))
				var opacity := (1.0 - smoothstep(0.15, 1.0, distance)) * gaps * 237.0
				var index := y * SIZE.x + x
				_sunlight[index] = maxi(_sunlight[index], roundi(opacity))


func _clip(rect: Rect2) -> Rect2i:
	var first := Vector2i(rect.position.floor()).clamp(Vector2i.ZERO, SIZE)
	var last := Vector2i(rect.end.ceil()).clamp(Vector2i.ZERO, SIZE)
	return Rect2i(first, last - first)
