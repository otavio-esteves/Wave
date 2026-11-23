extends RefCounted

const BALCONY := [
	Vector2(-0.50, -0.50), Vector2(0.50, -0.50), Vector2(0.50, 0.14), Vector2(0.42, 0.34),
	Vector2(0.23, 0.47), Vector2(0.0, 0.50), Vector2(-0.23, 0.47), Vector2(-0.42, 0.34), Vector2(-0.50, 0.14),
]


static func install(meshes: Dictionary) -> void:
	meshes["tiled_hip"] = _roof(true)
	meshes["tiled_gable"] = _roof(false)
	meshes["rolled_ridge"] = _ridge()
	meshes["bowed_slab"] = _slab()
	meshes["bowed_railing"] = _balcony_rail()
	meshes["canvas"] = _awnings(false)
	meshes["striped_canvas"] = _awnings(true)
	meshes["street_mast"] = _street_mast()
	meshes["lantern_cap"] = _profile("lantern_cap", [Vector2(0.50, -0.50), Vector2(0.47, -0.17), Vector2(0.31, 0.08), Vector2(0.18, 0.50), Vector2(0.0, 0.50)], 8)
	meshes["lamp_lens"] = _profile("lamp_lens", [Vector2(0.0, -0.50), Vector2(0.39, -0.50), Vector2(0.50, 0.50)], 6)
	meshes["bench_frame"] = _bench_frame()
	meshes["bench_slats"] = _bench_slats()
	meshes["sagging_wire"] = _cable()
	meshes["guard_sheet"] = _guardrail()
	meshes["seamed_roof"] = _seamed_roof()
	meshes["planter"] = _profile("planter", [
		Vector2(0.57, -0.50), Vector2(0.61, -0.46), Vector2(0.87, 0.29), Vector2(1.0, 0.33),
		Vector2(1.0, 0.47), Vector2(0.95, 0.5), Vector2(0.82, 0.5), Vector2(0.80, 0.37), Vector2(0.0, 0.37)], 12)
	meshes["fountain_basin"] = _profile("fountain_basin", [
		Vector2(0.42, -0.50), Vector2(0.48, -0.35), Vector2(0.48, 0.22), Vector2(0.50, 0.30),
		Vector2(0.50, 0.40), Vector2(0.48, 0.50), Vector2(0.43, 0.50), Vector2(0.42, 0.12), Vector2(0.0, 0.12)], 32)
	meshes["fountain_water"] = _profile("fountain_water", [Vector2(0.427, 0.0), Vector2(0.0, 0.0)], 32)
	meshes["fountain_urn"] = _profile("fountain_urn", [
		Vector2(0.38, -0.50), Vector2(0.48, -0.43), Vector2(0.24, -0.25), Vector2(0.22, -0.03),
		Vector2(0.34, 0.24), Vector2(0.50, 0.31), Vector2(0.50, 0.43), Vector2(0.46, 0.50), Vector2(0.0, 0.50)], 14)


static func fountain_collision(size: Vector3) -> ConvexPolygonShape3D:
	var points := PackedVector3Array()
	for index in 24:
		var edge := Vector2.from_angle(TAU * index / 24.0)
		for y: float in [-0.50, 0.50]:
			points.append(Vector3(edge.x * 0.48, y, edge.y * 0.48) * size)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


static func _roof(hipped: bool) -> ArrayMesh:
	var surface := _surface()
	var heights := [-0.50, -0.40, 0.085, 0.50]
	var runs := [0.5, 0.422, 0.205, 0.0]
	for side: float in [-1.0, 1.0]:
		for row in runs.size() - 1:
			var a := Vector3(-(_hip_width(heights[row]) if hipped else 0.5), heights[row], runs[row] * side)
			var b := Vector3(-(_hip_width(heights[row + 1]) if hipped else 0.5), heights[row + 1], runs[row + 1] * side)
			var c := Vector3(-b.x, b.y, b.z)
			var d := Vector3(-a.x, a.y, a.z)
			_quad(surface, a, b, c, d, Vector3.UP, Color("e7ded0") if row == 0 else Color.WHITE)
			for end: float in [-1.0, 1.0]:
				var eave := Vector3(d.x * end, d.y, d.z)
				var ridge := Vector3(c.x * end, c.y, c.z)
				_quad(surface, eave, ridge, Vector3(ridge.x, ridge.y, 0), Vector3(eave.x, eave.y, 0), Vector3.RIGHT * end)
		# The folded eave drains with the roof and shares its draw batch.
		var eave := Vector3(0.0, -0.50, side * 0.50)
		var lip := Vector3(0.0, -0.52, side * 0.511)
		var channel := Vector3(0.0, -0.56, side * 0.501)
		var left := Vector3.LEFT * 0.5
		var right := -left
		_quad(surface, eave + left, lip + left, lip + right, eave + right, Vector3.UP, Color("b9aea1"))
		_quad(surface, lip + left, channel + left, channel + right, lip + right, Vector3.BACK * side, Color("776c61"))
	# A thin return at the eave hides daylight along the fascia.
	_quad(surface, Vector3(-0.5, -0.50, -0.50), Vector3(0.5, -0.50, -0.50),
		Vector3(0.5, -0.50, 0.50), Vector3(-0.5, -0.50, 0.50), Vector3.DOWN)
	return _commit(surface, "tile_roof", true)


static func _hip_width(height: float) -> float:
	return lerpf(0.5, 0.265, height + 0.5)


static func _ridge() -> ArrayMesh:
	var surface := _surface()
	_pipe(surface, [Vector3.LEFT * 0.50, Vector3.RIGHT * 0.50], [0.50], Vector3.UP, 6, Color.WHITE)
	return _commit(surface, "rolled_ridge", true)


static func _slab() -> ArrayMesh:
	var surface := _surface()
	for edge in BALCONY.size():
		var a: Vector2 = BALCONY[edge]
		var b: Vector2 = BALCONY[(edge + 1) % BALCONY.size()]
		_quad(surface, _plan(a * 0.95, -0.5), _plan(a, -0.24), _plan(b, -0.24), _plan(b * 0.95, -0.5),
			_plan((a + b).normalized(), 0), Color("c4bfb4"))
		_quad(surface, _plan(a, -0.24), _plan(a, 0.26), _plan(b, 0.26), _plan(b, -0.24), _plan((a + b).normalized(), 0))
		_quad(surface, _plan(a, 0.26), _plan(a * 0.96, 0.5), _plan(b * 0.96, 0.5), _plan(b, 0.26), Vector3.UP)
		_triangle(surface, Vector3.UP * 0.5, _plan(a * 0.96, 0.5), _plan(b * 0.96, 0.5), Vector3.UP)
		_triangle(surface, Vector3.DOWN * 0.5, _plan(a * 0.95, -0.5), _plan(b * 0.95, -0.5), Vector3.DOWN, Color("aea99f"))
	return _commit(surface, "bowed_slab")


static func _balcony_rail() -> ArrayMesh:
	var surface := _surface()
	var outline := BALCONY.slice(1)
	outline.append(BALCONY[0])
	var iron := Color("484b44")
	for y: float in [0.19, 0.91]:
		var rail := PackedVector3Array()
		for point: Vector2 in outline:
			rail.append(_plan(point * 0.91, y))
		_pipe(surface, rail, [0.008], Vector3.UP, 3, iron)
	for edge in outline.size() - 1:
		var start: Vector2 = outline[edge] * 0.91
		var end: Vector2 = outline[edge + 1] * 0.91
		var span := (end - start).normalized() * 0.005
		for bar in 2:
			var bottom := start.lerp(end, 0.32 + bar * 0.35)
			var bow := bottom + bottom.normalized() * 0.045
			var normal := _plan(span.orthogonal().normalized(), 0)
			for side: float in [-1.0, 1.0]:
				_quad(surface, _plan(bottom - span, 0.13), _plan(bow - span, 0.46),
					_plan(bow + span, 0.46), _plan(bottom + span, 0.13), normal * side, iron)
				_quad(surface, _plan(bow - span, 0.46), _plan(bottom - span, 0.92),
					_plan(bottom + span, 0.92), _plan(bow + span, 0.46), normal * side, iron)
	return _commit(surface, "bowed_railing")


static func _awnings(striped: bool) -> ArrayMesh:
	var surface := _surface()
	var panels := 14 if striped else 4
	var profile := [Vector2(-0.50, 0.37), Vector2(-0.20, 0.31), Vector2(0.15, 0.12), Vector2(0.43, -0.23), Vector2(0.50, -0.45)]
	for panel in panels:
		var left := float(panel) / panels - 0.5
		var right := float(panel + 1) / panels - 0.5
		var dye := Color("d9cfb5") if striped and panel % 2 == 0 else Color("9a7867" if striped else "f2e9d8")
		for row in profile.size() - 1:
			var a: Vector2 = profile[row]
			var b: Vector2 = profile[row + 1]
			var v0 := Vector3(left, a.y, a.x)
			var v1 := Vector3(right, a.y, a.x)
			var v2 := Vector3(right, b.y, b.x)
			var v3 := Vector3(left, b.y, b.x)
			_quad(surface, v0, v1, v2, v3, Vector3.UP, dye)
			_quad(surface, v0, v1, v2, v3, Vector3.DOWN, dye.darkened(0.27))
		var a := Vector3(left, -0.445, 0.50)
		var b := Vector3(right, -0.445, 0.50)
		var center := (a + b) * 0.5 + Vector3.DOWN * (0.20 if panel % 2 == 0 else 0.135)
		for normal: Vector3 in [Vector3.BACK, Vector3.FORWARD]:
			_quad(surface, a, b, b + Vector3.DOWN * 0.11, a + Vector3.DOWN * 0.11, normal, dye)
			_triangle(surface, a + Vector3.DOWN * 0.11, b + Vector3.DOWN * 0.11, center, normal, dye)
	return _commit(surface, "awning")


static func _street_mast() -> ArrayMesh:
	var surface := _surface()
	var mast := [Vector3(0, 0, 0), Vector3(0, 0.23, 0), Vector3(0, 5.73, 0.015),
		Vector3(0, 6.13, 0.12), Vector3(0, 6.38, 0.40),
		Vector3(0, 6.50, 0.76), Vector3(0, 6.52, 1.37)]
	_pipe(surface, mast, [0.15, 0.092, 0.059, 0.053, 0.047, 0.044, 0.039], Vector3.RIGHT, 6, Color("9a9e96"))
	_pipe(surface, [Vector3(0, 6.53, 1.25), Vector3(0, 6.53, 1.42), Vector3(0, 6.55, 1.63), Vector3(0, 6.55, 1.87)],
		[0.055, 0.129, 0.176, 0.034], Vector3.RIGHT, 6, Color("b6b7ad"), Vector2(0.38, 1.0))
	return _commit(surface, "street_mast")


static func _bench_frame() -> ArrayMesh:
	var surface := _surface()
	for side: float in [-0.74, 0.74]:
		_pipe(surface, [Vector3(side, 0.03, 0.23), Vector3(side, 0.19, 0.17), Vector3(side, 0.41, 0.18),
			Vector3(side, 0.43, -0.17), Vector3(side, 0.74, -0.29), Vector3(side, 0.86, -0.35)],
			[0.045, 0.038, 0.033, 0.040, 0.030, 0.027], Vector3.RIGHT, 4, Color("666c61"))
		_pipe(surface, [Vector3(side, 0.03, -0.24), Vector3(side, 0.19, -0.22), Vector3(side, 0.42, -0.17)],
			[0.043, 0.036, 0.033], Vector3.RIGHT, 4, Color("666c61"))
		_pipe(surface, [Vector3(side, 0.59, -0.25), Vector3(side, 0.59, 0.15),
			Vector3(side, 0.55, 0.24), Vector3(side, 0.42, 0.23)], [0.028], Vector3.RIGHT, 4, Color("707668"))
	return _commit(surface, "bench_frame")


static func _bench_slats() -> ArrayMesh:
	var surface := _surface()
	for row in 7:
		var back := row > 3
		var y := 0.45 + (0.10 * (row - 3) if back else 0.010 * absf(row - 1.5))
		var z := -0.205 - ((row - 3) * 0.037 if back else -row * 0.118)
		_pipe(surface, [Vector3(-0.99, y, z), Vector3(0.99, y, z)],
			[0.055], Vector3.UP, 6, Color("fff4e3"), Vector2(0.46, 1.0) if back else Vector2(1.0, 0.46))
	return _commit(surface, "bench_slats")


static func _cable() -> ArrayMesh:
	var surface := _surface()
	for segment in 7:
		var a := float(segment) / 7.0
		var b := float(segment + 1) / 7.0
		var start := Vector3(0.0, -4.0 * a * (1.0 - a), a - 0.5)
		var end := Vector3(0.0, -4.0 * b * (1.0 - b), b - 0.5)
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP]:
			var rim := axis * 0.011
			_quad(surface, start - rim, start + rim, end + rim, end - rim, axis.cross(Vector3.BACK))
			_quad(surface, start - rim, start + rim, end + rim, end - rim, -axis.cross(Vector3.BACK))
	return _commit(surface, "sagging_wire")


static func _guardrail() -> ArrayMesh:
	var surface := _surface()
	var shape := [
		Vector2(-0.30, -0.50), Vector2(0.49, -0.30), Vector2(0.49, -0.15),
		Vector2(-0.03, 0.0), Vector2(0.49, 0.15), Vector2(0.49, 0.30), Vector2(-0.30, 0.50),
	]
	for row in shape.size() - 1:
		var a: Vector2 = shape[row]
		var b: Vector2 = shape[row + 1]
		var color := Color("94968d").lerp(Color("dfdcd1"), (row % 4) / 3.0)
		for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
			_quad(surface, Vector3(a.x, a.y, -0.5), Vector3(b.x, b.y, -0.5), Vector3(b.x, b.y, 0.5),
				Vector3(a.x, a.y, 0.5), normal, color)
	return _commit(surface, "guard_sheet")


static func _seamed_roof() -> ArrayMesh:
	var surface := _surface()
	for sheet in 26:
		var start := float(sheet) / 26.0 - 0.50
		var end := float(sheet + 1) / 26.0 - 0.50
		var seam := start + 0.0028
		var tint := Color("bbb9ad").lerp(Color("e4e1d6"), 0.5 + 0.5 * sin(sheet * 1.73))
		for face: float in [-1.0, 1.0]:
			_quad(surface, Vector3(-0.5, 0, seam), Vector3(0.5, 0, seam),
				Vector3(0.5, 0, end), Vector3(-0.5, 0, end), Vector3.UP * face, tint)
			_quad(surface, Vector3(-0.5, 0.31, start), Vector3(0.5, 0.31, start),
				Vector3(0.5, 0, seam), Vector3(-0.5, 0, seam), Vector3.UP * face, tint.darkened(0.23))
	return _commit(surface, "seamed_roof")


static func _profile(name: String, rings: Array, sides: int) -> ArrayMesh:
	var surface := _surface()
	for edge in sides:
		var a := Vector2.from_angle(TAU * edge / sides)
		var b := Vector2.from_angle(TAU * (edge + 1) / sides)
		for row in rings.size() - 1:
			var lower: Vector2 = rings[row]
			var upper: Vector2 = rings[row + 1]
			var normal := _plan((a + b) * (upper.y - lower.y), (lower.x - upper.x) * 2.0)
			_quad(surface, _plan(a * lower.x, lower.y), _plan(a * upper.x, upper.y),
				_plan(b * upper.x, upper.y), _plan(b * lower.x, lower.y), normal)
	return _commit(surface, name)


static func _pipe(surface: SurfaceTool, path: PackedVector3Array, radii: Array, reference: Vector3, sides: int, tint: Color, profile := Vector2.ONE) -> void:
	var rings: Array[PackedVector3Array] = []
	for index in path.size():
		var axis := (path[mini(index + 1, path.size() - 1)] - path[maxi(0, index - 1)]).normalized()
		var across := axis.cross(reference).normalized()
		var up := across.cross(axis).normalized()
		var radius: float = radii[mini(index, radii.size() - 1)]
		var ring := PackedVector3Array()
		for side in sides:
			var angle := TAU * side / sides
			var rim := (across * (cos(angle) * profile.x) + up * (sin(angle) * profile.y)) * radius
			ring.append(path[index] + rim)
		rings.append(ring)
	for index in rings.size() - 1:
		for side in sides:
			var next := (side + 1) % sides
			var a := rings[index][side]
			var b := rings[index + 1][side]
			var c := rings[index + 1][next]
			var d := rings[index][next]
			_quad(surface, a, b, c, d, a + b + c + d - (path[index] + path[index + 1]) * 2.0, tint)


static func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


static func _commit(surface: SurfaceTool, name: String, tangents := false) -> ArrayMesh:
	surface.index()
	if tangents:
		surface.generate_tangents()
	var mesh := surface.commit()
	mesh.resource_name = "figueiras_kit_" + name
	return mesh


static func _plan(point: Vector2, y: float) -> Vector3:
	return Vector3(point.x, y, point.y)


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, tint := Color.WHITE) -> void:
	_triangle(surface, a, b, c, outward, tint)
	_triangle(surface, a, c, d, outward, tint)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, tint := Color.WHITE) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < 0.00000000001:
		return
	var vertices := [a, b, c]
	if normal.dot(outward) < 0.0:
		normal = -normal
		vertices = [a, c, b]
	normal = normal.normalized()
	surface.set_normal(normal)
	surface.set_color(tint)
	for point: Vector3 in vertices:
		var uv := Vector2(point.z if absf(normal.x) > 0.69 else point.x, point.z if absf(normal.y) > 0.43 else -point.y)
		# A steep roof hip can face almost equally upward and sideways.
		if absf(normal.x) > 0.69 and absf(normal.y) > 0.43:
			uv = Vector2(point.z, point.x)
		surface.set_uv(uv + Vector2(0.5, 0.5))
		surface.add_vertex(point)
