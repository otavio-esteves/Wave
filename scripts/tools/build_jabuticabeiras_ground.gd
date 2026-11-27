extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const RoadSurface = preload("res://scripts/tools/build_jabuticabeiras_road_surface.gd")
const FINISH = preload("res://assets/shaders/jabuticabeiras/pavement.gdshader")
const ASPHALT = preload("res://assets/textures/jabuticabeiras/asfalto-brita.png")
const CONCRETE = preload("res://assets/textures/neighborhood/limestone-albedo.res")
const CONCRETE_NORMAL = preload("res://assets/textures/neighborhood/limestone-normal.res")
const GRASS = preload("res://assets/textures/jabuticabeiras/grama-do-largo.png")
const PAVERS = preload("res://assets/textures/neighborhood/pavers-albedo.res")
const BASALT = preload("res://assets/textures/jabuticabeiras/basalto-assentado.png")
const SKY = preload("res://assets/textures/jabuticabeiras/ceu-apos-garoa.png")

# Each pair is the station and half-width of a driveway apron. The crossing
# has lowered curbs on both sides in the same physical and rendered mesh.
const LEFT_APRONS: Array[Vector2] = [Vector2(17.7, 1.36), Vector2(24.4, 1.68), Vector2(32.2, 1.55),
	Vector2(44.2, 1.52), Vector2(56.3, 1.31), Vector2(70.3, 1.62), Vector2(90.9, 1.76),
	Vector2(102.3, 1.44), Vector2(114.0, 1.76), Vector2(130.6, 1.56), Vector2(143.2, 1.76)]
const RIGHT_APRONS: Array[Vector2] = [Vector2(21.7, 1.70), Vector2(32.2, 1.55), Vector2(40.25, 1.57),
	Vector2(54.7, 1.62), Vector2(76.4, 1.49), Vector2(87.4, 1.48), Vector2(103.1, 1.53),
	Vector2(126.4, 1.58), Vector2(141.2, 1.58)]
const BANDS := [3, 3, 3, 4, 1, 2, 2, 0, 0, 0, 0, 2, 2, 1, 4, 3, 3, 3]
const SECTOR_LENGTH := 32.0
const ROW_STEP := 1.0

var _surfaces: Dictionary[int, SurfaceTool] = {}
var _finishes: Array[ShaderMaterial] = []
var _support := PackedVector3Array()


func build(parent: Node3D) -> void:
	_finishes.assign([
		_finish("Asfalto", ASPHALT, RoadSurface.relief_for(ASPHALT, 2.04), Color("c4cbce"), 0.56, 0),
		_finish("Calcada", CONCRETE, CONCRETE_NORMAL, Color("a99f8e"), 0.61, 1),
		_finish("MeioFio", CONCRETE, CONCRETE_NORMAL, Color("948d80"), 0.70, 2),
		_finish("Terreno", GRASS, RoadSurface.relief_for(GRASS, 1.05, 512), Color("c0c4aa"), 0.54, 3),
		_finish("Acessos", PAVERS, CONCRETE_NORMAL, Color("aba194"), 0.36, 4),
		_finish("Basalto", BASALT, CONCRETE_NORMAL, Color("cbc2ac"), 0.63, 5),
		_finish("PedraPortuguesa", BASALT, CONCRETE_NORMAL, Color("c6c0ad"), 0.72, 6),
	])
	var station := -24.0
	var row := _section(station)
	while station < Layout.LENGTH + 24.0:
		var next := station + ROW_STEP
		var next_row := _section(next)
		for band in BANDS.size():
			var kind := _finish_at(band, station)
			_quad(_surface(kind), station, row[band], row[band + 1], next, next_row[band], next_row[band + 1])
		row = next_row
		station = next
		if is_zero_approx(fposmod(station, SECTOR_LENGTH)):
			_commit(parent, int(station))
	_commit(parent, int(station))
	_curb_stones(parent)
	var body := StaticBody3D.new()
	body.name = "StreetSupport"
	body.set_meta("surface", "asfalto")
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_support)
	var collision := CollisionShape3D.new()
	collision.name = "PavementCollision"
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func set_surface_bake(mask: Texture2D, bounds: Rect2) -> void:
	for finish in _finishes:
		finish.set_shader_parameter("surface_bake", mask)
		finish.set_shader_parameter("bake_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))


func _finish(label: String, albedo: Texture2D, normal: Texture2D, tint: Color, scale: float, kind: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = label
	material.shader = FINISH
	material.set_shader_parameter("albedo_map", albedo)
	material.set_shader_parameter("normal_texture", normal)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("texture_scale", scale)
	material.set_shader_parameter("surface_kind", kind)
	if kind == 0:
		material.set_shader_parameter("street_sky", SKY)
		var bounds := RoadSurface.BOUNDS
		material.set_shader_parameter("road_condition_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
		material.set_shader_parameter("road_condition", RoadSurface.new().bake())
		material.set_shader_parameter("has_road_condition", true)
	return material


func _finish_at(band: int, station: float) -> int:
	if station < 0.0 or station >= Layout.LENGTH:
		return 3
	if band in [7, 10] and (station < 10.0 or station >= 146.0):
		return 5
	if band in [4, 13] and ((station >= 10.0 and station < 38.0) or station >= 143.0):
		return 6
	if band == 3 and (station < 9.0 or (station >= 50.0 and station < 63.0)):
		return 5
	if band == 14 and ((station >= 11.0 and station < 21.0) or (station >= 88.0 and station < 100.0)
			or station >= 146.0):
		return 5
	return BANDS[band]


static func surface_lift(station: float, offset: float) -> float:
	var section := _section(station)
	for index in range(1, section.size()):
		var near := section[index - 1]
		var far := section[index]
		if offset <= far.x:
			return lerpf(near.y, far.y, clampf(inverse_lerp(near.x, far.x, offset), 0.0, 1.0))
	return section[-1].y


static func _section(station: float) -> PackedVector2Array:
	var w := Layout.half_width(station)
	var walk := w + Layout.SIDEWALK_WIDTH
	var aprons := Layout.paving_edge(station)
	var left := _curb_rise(station, LEFT_APRONS)
	var right := _curb_rise(station, RIGHT_APRONS)
	var fade := smoothstep(-6.0, 0.0, station) * (1.0 - smoothstep(Layout.LENGTH, Layout.LENGTH + 6.0, station))
	var verge := 0.34 + 0.28 * sin(station * 0.13)
	var west_hill := 2.2 + 1.43 * sin(station * 0.054 - 0.8)
	var east_hill := 2.0 + 1.23 * cos(station * 0.057 + 1.2)
	return PackedVector2Array([
		Vector2(-49.0, west_hill + 2.3), Vector2(-25.5, west_hill), Vector2(-13.0, verge),
		Vector2(-aprons, 0.18 * fade), Vector2(-walk, 0.16 * fade),
		Vector2(-w - Layout.CURB_WIDTH, left * fade), Vector2(-w - 0.036, left * 0.32 * fade), Vector2(-w, 0.0),
		Vector2(-w + 0.29, -0.014 * fade), Vector2(0.0, 0.0), Vector2(w - 0.29, -0.014 * fade),
		Vector2(w, 0.0), Vector2(w + 0.036, right * 0.32 * fade), Vector2(w + Layout.CURB_WIDTH, right * fade),
		Vector2(walk, 0.16 * fade), Vector2(aprons, 0.18 * fade),
		Vector2(13.0, verge + 0.10), Vector2(25.5, east_hill), Vector2(49.0, east_hill + 3.6),
	])


static func _curb_rise(station: float, ramps: Array[Vector2]) -> float:
	var dip := 0.0
	for ramp in ramps:
		dip = maxf(dip, 1.0 - smoothstep(ramp.y, ramp.y + 0.82, absf(station - ramp.x)))
	return lerpf(Layout.CURB_RISE, 0.028, dip)


func _surface(kind: int) -> SurfaceTool:
	if not _surfaces.has(kind):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(_finishes[kind])
		_surfaces[kind] = tool
	return _surfaces[kind]


func _quad(tool: SurfaceTool, station: float, left: Vector2, right: Vector2,
		next: float, next_left: Vector2, next_right: Vector2) -> void:
	var stations := [station, next, next, station]
	var profile := [left, next_left, next_right, right]
	var points: Array[Vector3] = []
	for corner in 4:
		points.append(Layout.position_at(stations[corner], profile[corner].x, profile[corner].y))
	for triangle: Vector3i in [Vector3i(0, 1, 2), Vector3i(0, 2, 3)]:
		var normal := (points[triangle.z] - points[triangle.x]).cross(points[triangle.y] - points[triangle.x]).normalized()
		for index: int in [triangle.x, triangle.y, triangle.z]:
			tool.set_uv(Vector2(profile[index].x, stations[index]))
			tool.set_uv2(Vector2(Layout.half_width(stations[index]), 0.0))
			tool.set_normal(normal)
			tool.add_vertex(points[index])
			_support.append(points[index])


func _curb_stones(parent: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 93794
	for sector in ceili(Layout.LENGTH / SECTOR_LENGTH):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(_finishes[2])
		for side: float in [-1.0, 1.0]:
			var station := sector * SECTOR_LENGTH
			var limit := minf(station + SECTOR_LENGTH, Layout.LENGTH)
			while station + 0.18 < limit:
				var length := minf(random.randf_range(0.60, 1.21), limit - station)
				var far := station + length
				var change := random.randf_range(-0.010, 0.013)
				var first := _curb_piece_row(station + 0.010, side, change, 0.42)
				var bevel := _curb_piece_row(station + 0.029, side, change, 1.0)
				var end_bevel := _curb_piece_row(far - 0.029, side, change, 1.0)
				var last := _curb_piece_row(far - 0.010, side, change, 0.42)
				var color := Color("afa89b").lerp(Color("f3ede0"), random.randf_range(0.41, 0.82))
				_curb_span(surface, first, bevel, color.darkened(0.19))
				_curb_span(surface, bevel, end_bevel, color)
				_curb_span(surface, end_bevel, last, color.darkened(0.19))
				station = far
		surface.generate_tangents()
		surface.index()
		var curb := MeshInstance3D.new()
		curb.name = "Pavement_Stones_%d" % sector
		curb.mesh = surface.commit()
		curb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		curb.visibility_range_end = 55.0
		parent.add_child(curb)


func _curb_piece_row(station: float, side: float, variation: float, height: float) -> PackedVector3Array:
	var row := PackedVector3Array()
	var width := Layout.half_width(station)
	var profile := [Vector2(0.020, 0.007), Vector2(0.062, 0.015), Vector2(0.146, 0.034),
		Vector2(0.177, 0.026), Vector2(0.221, 0.010)]
	for sample: Vector2 in profile:
		var offset := (width + sample.x + variation) * side
		row.append(Vector3(offset, station, surface_lift(station, offset) + sample.y * height + 0.003))
	if side < 0.0:
		row.reverse()
	return row


func _curb_span(surface: SurfaceTool, front: PackedVector3Array, back: PackedVector3Array, color: Color) -> void:
	for point in front.size() - 1:
		var shade := color.darkened(0.13 if point in [0, 3] else 0.0).srgb_to_linear()
		var samples := [front[point], back[point], back[point + 1], front[point + 1]]
		var points: Array[Vector3] = []
		for sample: Vector3 in samples:
			points.append(Layout.position_at(sample.y, sample.x, sample.z))
		var normal := (points[2] - points[0]).cross(points[1] - points[0]).normalized()
		for index: int in [0, 1, 2, 0, 2, 3]:
			var uv: Vector3 = samples[index]
			surface.set_normal(normal)
			surface.set_uv(Vector2(uv.x, uv.y))
			surface.set_uv2(Vector2(Layout.half_width(uv.y), 0.0))
			surface.set_color(shade)
			surface.add_vertex(points[index])


func _commit(parent: Node3D, end: int) -> void:
	for kind: int in _surfaces:
		var tool := _surfaces[kind]
		tool.generate_tangents()
		tool.index()
		var node := MeshInstance3D.new()
		node.name = "Pavement_%s_%s" % [kind, end]
		node.mesh = tool.commit()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
	_surfaces.clear()
