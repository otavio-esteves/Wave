extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const FINISH = preload("res://assets/shaders/jabuticabeiras/pavement.gdshader")
const ASPHALT = preload("res://assets/textures/figueiras/asfalto-alameda.png")
const ASPHALT_NORMAL = preload("res://assets/textures/neighborhood/asphalt-normal.res")
const CONCRETE = preload("res://assets/textures/neighborhood/limestone-albedo.res")
const CONCRETE_NORMAL = preload("res://assets/textures/neighborhood/limestone-normal.res")
const GRASS = preload("res://assets/textures/neighborhood/turf-albedo.res")
const GRASS_NORMAL = preload("res://assets/textures/neighborhood/turf-normal.res")
const PAVERS = preload("res://assets/textures/neighborhood/pavers-albedo.res")
const BASALT = preload("res://assets/textures/jabuticabeiras/basalto-assentado.png")

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
		_finish("Asfalto", ASPHALT, ASPHALT_NORMAL, Color("b9c0c7"), 0.58, 0),
		_finish("Calcada", CONCRETE, CONCRETE_NORMAL, Color("ada295"), 0.61, 1),
		_finish("MeioFio", CONCRETE, CONCRETE_NORMAL, Color("998f80"), 0.70, 2),
		_finish("Terreno", GRASS, GRASS_NORMAL, Color("7d875f"), 0.34, 3),
		_finish("Acessos", PAVERS, CONCRETE_NORMAL, Color("aba194"), 0.36, 4),
		_finish("Basalto", BASALT, CONCRETE_NORMAL, Color("cbc2ac"), 0.63, 5),
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
	return material


func _finish_at(band: int, station: float) -> int:
	if station < 0.0 or station >= Layout.LENGTH:
		return 3
	if band in [7, 10] and (station < 10.0 or station >= 146.0):
		return 5
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
