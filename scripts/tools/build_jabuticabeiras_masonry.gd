extends RefCounted

# All opaque construction within a sector shares one atlas and draw.
# UV2.x selects the finish and UV2.y carries the occlusion at the joint.
enum Finish { PLASTER, BRICK, STONE, TILE, WOOD, CERAMIC, METAL, GLASS, LIGHT }

const SHADER = preload("res://assets/shaders/jabuticabeiras/masonry.gdshader")
const CLOUDS = preload("res://assets/textures/jabuticabeiras/ceu-apos-garoa.png")
const TEXTURES := "res://assets/textures/neighborhood/"
const TILE = preload("res://assets/textures/jabuticabeiras/ladrilho-hidraulico.png")
const WALL = preload("res://assets/textures/jabuticabeiras/reboco-mineral.png")
const BRICK = preload("res://assets/textures/jabuticabeiras/tijolo-aparente.png")
const ROOF = preload("res://assets/textures/jabuticabeiras/telha-colonial.png")
const TEXTURE_SIZE := 384
const PADDING := 12
const SECTOR_LENGTH := 26.0
const REPEATS := [0.64, 0.76, 0.68, 0.51, 0.86, 1.25, 1.1, 1.0, 1.0]

var _surface: SurfaceTool
var _frame := Transform3D.IDENTITY
var _sectors: Dictionary[Vector2i, SurfaceTool] = {}
var _material := ShaderMaterial.new()


func _init() -> void:
	_material.resource_name = "AlvenariaDasJabuticabeiras"
	_material.shader = SHADER
	_material.set_shader_parameter("atlas_tile", Vector2(TEXTURE_SIZE, PADDING))
	_material.set_shader_parameter("street_sky", CLOUDS)
	_material.set_shader_parameter("finishes", _atlas_of([
		WALL, BRICK,
		preload("res://assets/textures/jabuticabeiras/basalto-assentado.png"),
		ROOF, load(TEXTURES + "timber-albedo.res"), TILE,
	]))
	_material.set_shader_parameter("relief", _atlas_of([
		WALL, BRICK,
		load(TEXTURES + "limestone-normal.res"), ROOF,
		load(TEXTURES + "timber-normal.res"), load(TEXTURES + "limestone-normal.res"),
	], {0: 1.44, 1: 2.25, 3: 1.90}))
	_material.set_shader_parameter("weathering", _weather_map())
	_material.set_shader_parameter("has_weathering", true)


func begin(frame: Transform3D) -> void:
	_frame = frame
	var side := -1 if frame.basis.z.x > 0.0 else 1
	var key := Vector2i(side, floori(frame.origin.z / SECTOR_LENGTH))
	if not _sectors.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(_material)
		_sectors[key] = surface
	_surface = _sectors[key]


func box(center: Vector3, size: Vector3, finish: Finish, color: Color, occlusion := 1.0) -> void:
	var low := center - size * 0.5
	var high := center + size * 0.5
	var a := Vector3(low.x, low.y, high.z)
	var b := Vector3(high.x, low.y, high.z)
	var c := Vector3(high.x, high.y, high.z)
	var d := Vector3(low.x, high.y, high.z)
	var e := Vector3(low.x, low.y, low.z)
	var f := Vector3(high.x, low.y, low.z)
	var g := Vector3(high.x, high.y, low.z)
	var h := Vector3(low.x, high.y, low.z)
	quad(a, b, c, d, finish, color, occlusion)
	quad(f, e, h, g, finish, color, occlusion)
	quad(b, f, g, c, finish, color, occlusion)
	quad(e, a, d, h, finish, color, occlusion)
	quad(d, c, g, h, finish, color, occlusion)
	quad(e, f, b, a, finish, color, occlusion * 0.75)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, finish: Finish, color: Color, occlusion := 1.0) -> void:
	_face([a, c, b, a, d, c], (b - a).normalized(), d - a, finish, color, occlusion)


func triangle(a: Vector3, b: Vector3, c: Vector3, finish: Finish, color: Color, occlusion := 1.0) -> void:
	_face([a, c, b], (b - a).normalized(), c - a, finish, color, occlusion)


func _face(points: Array[Vector3], along: Vector3, rise: Vector3, finish: Finish, color: Color, occlusion: float) -> void:
	var normal := along.cross(rise).normalized()
	if normal.is_zero_approx():
		return
	var up := normal.cross(along)
	var repeats: float = REPEATS[finish]
	for point: Vector3 in points:
		var uv := Vector2(point.dot(along), -point.dot(up)) * repeats
		var foundation := lerpf(0.78, 1.0, smoothstep(0.0, 1.05, point.y))
		_surface.set_uv(uv)
		_surface.set_uv2(Vector2(float(finish), occlusion * foundation))
		_surface.set_color(Color(color.r, color.g, color.b, clampf((point.y + 0.4) / 8.0, 0.0, 1.0)))
		_surface.set_normal(_frame.basis * normal)
		_surface.add_vertex(_frame * point)


func finish(parent: Node3D) -> void:
	for key in _sectors:
		var sector := _sectors[key]
		sector.generate_tangents()
		sector.index()
		var node := MeshInstance3D.new()
		node.name = "Alvenaria_%d_%d" % [key.x + 1, -key.y]
		node.mesh = sector.commit()
		parent.add_child(node)


func _atlas_of(textures: Array[Texture2D], bump_strengths: Dictionary[int, float] = {}) -> ImageTexture:
	var stride := TEXTURE_SIZE + PADDING * 2
	var atlas := Image.create_empty(stride * 3, stride * 2, false, Image.FORMAT_RGBA8)
	var starts := [TEXTURE_SIZE - PADDING, 0, 0]
	var offsets := [0, PADDING, TEXTURE_SIZE + PADDING]
	var lengths := [PADDING, TEXTURE_SIZE, PADDING]
	for index in textures.size():
		var image := textures[index].get_image()
		if image.is_compressed():
			image.decompress()
		image.clear_mipmaps()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
		if bump_strengths.has(index):
			image.bump_map_to_normal_map(bump_strengths[index])
			image.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i((index % 3) * stride, (index / 3) * stride)
		for row in 3:
			for column in 3:
				var part := Rect2i(starts[column], starts[row], lengths[column], lengths[row])
				atlas.blit_rect(image, part, cell + Vector2i(offsets[column], offsets[row]))
	atlas.generate_mipmaps()
	return ImageTexture.create_from_image(atlas)


func _weather_map() -> ImageTexture:
	const RESOLUTION := 384
	var drips := FastNoiseLite.new()
	drips.seed = 12631
	drips.frequency = 1.0
	drips.fractal_octaves = 3
	var deposits := FastNoiseLite.new()
	deposits.seed = 51308
	deposits.frequency = 1.0
	deposits.fractal_octaves = 4
	var channels := PackedByteArray()
	channels.resize(RESOLUTION * RESOLUTION * 4)
	for row in RESOLUTION:
		for column in RESOLUTION:
			var uv := Vector2(column, row) / RESOLUTION
			var rain := _weather_sample(drips, uv, Vector2(36.0, 2.0))
			var broad := _weather_sample(deposits, uv, Vector2(7.0, 8.0))
			var pigment := _weather_sample(deposits, uv + Vector2(0.31, 0.14), Vector2(24.0, 21.0))
			var patina := _weather_sample(drips, uv + Vector2(0.12, 0.41), Vector2(70.0, 59.0))
			var byte := (row * RESOLUTION + column) * 4
			channels[byte] = roundi(smoothstep(-0.03, 0.43, rain + broad * 0.31) * 255.0)
			channels[byte + 1] = roundi(smoothstep(-0.12, 0.52, broad + pigment * 0.49) * 255.0)
			channels[byte + 2] = roundi(smoothstep(0.016, 0.44, pigment * 0.53 + broad * 0.57) * 255.0)
			channels[byte + 3] = roundi(smoothstep(0.22, 0.52, patina + broad * 0.23) * 255.0)
	var image := Image.create_from_data(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8, channels)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _weather_sample(noise: FastNoiseLite, uv: Vector2, frequency: Vector2) -> float:
	var sample := uv.posmodv(Vector2.ONE)
	var point := sample * frequency
	var first := lerpf(noise.get_noise_2dv(point), noise.get_noise_2dv(point - Vector2(frequency.x, 0.0)), sample.x)
	var last := lerpf(noise.get_noise_2dv(point - Vector2(0.0, frequency.y)), noise.get_noise_2dv(point - frequency), sample.x)
	return lerpf(first, last, sample.y)
