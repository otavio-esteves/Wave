extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const BOUNDS := Rect2(-6.35, 0.0, 12.70, Layout.LENGTH)
const SIZE := Vector2i(224, 2400)

# Station, crossfall offset, length and width. The main lane drains into the
# crown gutters while the two turning areas retain larger shallow pools.
const POOLS := [
	Vector4(4.65, -2.45, 3.9, 1.12), Vector4(9.38, 3.76, 2.7, 0.98),
	Vector4(16.55, 2.88, 4.9, 0.54), Vector4(18.6, -2.83, 2.55, 0.64),
	Vector4(25.75, -1.62, 2.52, 0.61), Vector4(27.8, -3.10, 4.87, 0.41),
	Vector4(35.18, 2.92, 5.4, 0.49), Vector4(44.55, -2.74, 3.2, 0.68),
	Vector4(49.6, 2.83, 2.25, 0.39), Vector4(53.0, 3.14, 5.8, 0.34),
	Vector4(60.05, 0.18, 2.08, 0.61), Vector4(67.42, -2.94, 3.9, 0.53),
	Vector4(73.5, 2.94, 2.16, 0.38), Vector4(82.78, 2.89, 4.46, 0.42),
	Vector4(93.97, 2.70, 3.10, 0.66), Vector4(97.43, -2.91, 4.51, 0.43),
	Vector4(107.4, 0.32, 3.24, 0.74), Vector4(115.21, -2.93, 5.40, 0.44),
	Vector4(121.67, 2.68, 2.10, 0.59), Vector4(133.7, 2.87, 3.8, 0.46),
	Vector4(141.67, -3.65, 3.7, 0.92), Vector4(146.8, 4.24, 3.35, 0.92),
	Vector4(152.2, -2.48, 3.91, 1.38), Vector4(153.2, 3.10, 3.26, 0.83),
]
const REPAIRS := [
	Rect2(-3.16, 12.5, 0.56, 11.0), Rect2(1.83, 24.7, 1.26, 2.9),
	Rect2(-1.59, 42.0, 2.65, 1.19), Rect2(-2.24, 47.1, 0.51, 18.68),
	Rect2(0.19, 76.22, 2.82, 5.23), Rect2(-2.96, 94.82, 1.29, 3.26),
	Rect2(1.82, 106.14, 0.51, 14.03), Rect2(-0.67, 123.29, 2.85, 1.11),
	Rect2(-3.11, 135.8, 1.28, 4.90), Rect2(1.47, 148.08, 2.68, 1.52),
]

var _coarse := FastNoiseLite.new()
var _fine := FastNoiseLite.new()


func bake() -> ImageTexture:
	_coarse.seed = 96305
	_coarse.frequency = 0.68
	_coarse.fractal_octaves = 4
	_fine.seed = 739155
	_fine.frequency = 2.48
	_fine.fractal_octaves = 2
	var data := PackedByteArray()
	data.resize(SIZE.x * SIZE.y * 4)
	for row in SIZE.y:
		var station := (row + 0.5) / SIZE.y * Layout.LENGTH
		var width := Layout.half_width(station)
		var active_pools: Array[Vector4] = []
		var active_repairs: Array[Rect2] = []
		for pool: Vector4 in POOLS:
			if absf(station - pool.x) < pool.z + 0.8:
				active_pools.append(pool)
		for patch: Rect2 in REPAIRS:
			if station >= patch.position.y - 0.25 and station <= patch.end.y + 0.25:
				active_repairs.append(patch)
		var gutter_width := 0.32 + 0.09 * sin(station * 1.21) + 0.06 * cos(station * 2.69)
		for column in SIZE.x:
			var across := BOUNDS.position.x + (column + 0.5) / SIZE.x * BOUNDS.size.x
			var coarse := _coarse.get_noise_2d(across * 1.53, station * 0.44)
			var fine := _fine.get_noise_2d(across * 1.72, station)
			var curb := maxf(width - absf(across), 0.0)
			var gutter := (1.0 - smoothstep(0.085, gutter_width + 0.10, curb)) * (0.45 + coarse * 0.45)
			var wheel := _wheel_track(across - sin(station * 0.092) * 0.18, station)
			var water := 0.29 + 0.37 * coarse + 0.078 * fine + gutter * 0.42 - wheel * 0.19
			for site in active_pools:
				var meander := 0.11 * sin(station * 1.7 + site.x) + 0.086 * coarse
				var ellipse := Vector2((across - site.y - meander) / site.w, (station - site.x) / site.z)
				var edge := ellipse.length() + coarse * 0.31 + fine * 0.14
				var pool := 1.0 - smoothstep(0.42, 1.0, edge)
				water = maxf(water, pool * 0.86 + water * 0.23)
			var paint := 0.0
			var tar := 0.0
			for patch in active_repairs:
				var outside := Vector2(maxf(patch.position.x - across, across - patch.end.x),
					maxf(patch.position.y - station, station - patch.end.y))
				var distance := maxf(outside.x, outside.y) + fine * 0.063 + coarse * 0.061
				paint = maxf(paint, (1.0 - smoothstep(-0.09, 0.053, distance)) * (0.74 + coarse * 0.19))
				tar = maxf(tar, (1.0 - smoothstep(0.016, 0.052, absf(distance))) * (0.48 + fine * 0.42))
			var separation := absf(fposmod(station - across * 0.82 + coarse * 2.04, 21.6) - 3.89)
			var crack := (1.0 - smoothstep(0.016, 0.052, separation)) * smoothstep(0.08, 0.51, coarse + fine * 0.30)
			var dirt := gutter * (0.67 - 0.35 * fine) + wheel * 0.28 + 0.23 * smoothstep(0.0, 0.42, coarse)
			var i := (row * SIZE.x + column) * 4
			data[i] = _byte(water)
			data[i + 1] = _byte(paint)
			data[i + 2] = _byte(maxf(tar, crack))
			data[i + 3] = _byte(dirt)
	var image := Image.create_from_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8, data)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _wheel_track(across: float, station: float) -> float:
	var center := 1.67 * signf(across)
	var tire := absf(absf(across - center) - 0.82)
	var track := 1.0 - smoothstep(0.07, 0.40 + 0.05 * cos(station * 0.32), tire)
	return track * smoothstep(6.0, 17.0, station) * (1.0 - smoothstep(138.0, 151.0, station))


func _byte(value: float) -> int:
	return roundi(clampf(value, 0.0, 1.0) * 255.0)


static func relief_for(source: Texture2D, strength: float, width_limit := 1024) -> ImageTexture:
	var image := source.get_image()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	if image.get_width() > width_limit:
		var height := roundi(float(image.get_height()) * width_limit / image.get_width())
		image.resize(width_limit, height, Image.INTERPOLATE_LANCZOS)
	image.bump_map_to_normal_map(strength)
	image.generate_mipmaps(true)
	return ImageTexture.create_from_image(image)
