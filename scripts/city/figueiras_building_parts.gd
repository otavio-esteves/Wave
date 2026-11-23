extends RefCounted


static func floor_range(ground: RefCounted, site: Vector2, width: float, depth: float, yaw: float) -> Vector2:
	var frame := Basis(Vector3.UP, yaw)
	var lowest := INF
	var highest := -INF
	for x: float in [-0.5, 0.0, 0.5]:
		for z: float in [-0.5, 0.0, 0.5]:
			var offset := frame * Vector3(width * x, 0.0, depth * z)
			var height: float = ground.surface_point(site + Vector2(offset.x, offset.z)).y
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	return Vector2(lowest, highest)


static func masonry_mass(city: RefCounted, ground: RefCounted, site: Vector2, size: Vector3, yaw: float, wall: String) -> Vector3:
	var heights := floor_range(ground, site, size.x, size.z, yaw)
	var origin := Vector3(site.x, heights.y + 0.12, site.y)
	var depth := origin.y - heights.x + 0.38
	city.add_part(origin, Vector3(0, -depth * 0.5, 0), Vector3(size.x, depth, size.z), "stone", yaw, true)
	city.add_part(origin, Vector3(0, size.y * 0.5, 0), size, wall, yaw, true)
	return origin


static func beam(city: RefCounted, a: Vector3, b: Vector3, width: float, depth: float, finish: String, solid := false) -> void:
	var axis := (b - a).normalized()
	var up := Vector3.FORWARD if absf(axis.y) > 0.94 else Vector3.UP
	city._add_tilted_box((a + b) * 0.5, Basis.looking_at(axis, up), Vector3(width, depth, a.distance_to(b) + 0.04), finish, solid)


static func ramp(city: RefCounted, a: Vector3, b: Vector3, width: float, finish := "stone") -> void:
	var direction := (b - a).normalized()
	var basis := Basis.looking_at(direction, Vector3.UP)
	var center := (a + b) * 0.5 - basis.y * 0.11
	city._add_tilted_box(center, basis, Vector3(width, 0.22, a.distance_to(b)), finish, true)


static func arch_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	# Open-backed trim with separate intrados and extrados so the opening
	# reads from the road in both directions, even in full shade.
	for index in 14:
		var begin := index * PI / 14.0
		var end := (index + 1) * PI / 14.0
		var first := Vector2(cos(begin), sin(begin))
		var last := Vector2(cos(end), sin(end))
		var a := Vector3(first.x * 0.52, first.y * 0.76, -0.5)
		var b := Vector3(last.x * 0.52, last.y * 0.76, -0.5)
		var c := Vector3(last.x * 0.575, last.y * 0.92, -0.5)
		var d := Vector3(first.x * 0.575, first.y * 0.92, -0.5)
		var depth := Vector3.BACK
		_quad(surface, a, b, c, d, Vector3.FORWARD, index)
		_quad(surface, a + depth, b + depth, c + depth, d + depth, Vector3.BACK, index)
		_quad(surface, a, b, b + depth, a + depth, Vector3(-first.x, -first.y, 0), index)
		_quad(surface, d, c, c + depth, d + depth, Vector3(first.x, first.y, 0), index)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, index: int) -> void:
	var corners := [a, b, c, d]
	var uv := [Vector2(index, 0), Vector2(index + 1, 0), Vector2(index + 1, 1), Vector2(index, 1)]
	var indices := [0, 1, 2, 0, 2, 3] if (c - a).cross(b - a).dot(outward) > 0.0 else [0, 2, 1, 0, 3, 2]
	for vertex: int in indices:
		surface.set_uv(uv[vertex])
		surface.add_vertex(corners[vertex])
