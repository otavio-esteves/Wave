extends RefCounted

# Offline only: weld the sampled sidewalk's inner boundary to the authored road.
# A minimum of several distance fields, interpolated over a one metre cell,
# need not share the boundary of the road's triangle fan. Never move either
# authored surface or its collision to repair that narrow visual interval.
const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const TILE := 4.0
const MAX_GAP := 0.75
var edges: Array = []
var triangles: Array = []
var edge_tiles: Dictionary = {}
var triangle_tiles: Dictionary = {}
var matched_vertices: Dictionary = {}
var seam_count := 0
var maximum_gap := 0.0


func add_road(mesh: Mesh) -> void:
	var faces := mesh.get_faces()
	for index in range(0, faces.size(), 3):
		var triangle := PackedVector3Array([faces[index], faces[index + 1], faces[index + 2]])
		var id := triangles.size()
		triangles.append(triangle)
		_index(triangle_tiles, triangle, id)
	for edge in boundary_edges(mesh):
		var id := edges.size()
		edges.append(edge)
		_index(edge_tiles, edge, id, MAX_GAP)


func seal(mesh: Mesh) -> PackedVector3Array:
	var output := PackedVector3Array()
	for edge in boundary_edges(mesh):
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		# Both the pavement's outer edge and dropped ramps are low. Distance to
		# an actual saved road, below, distinguishes the inner edge from gardens.
		if not _low_edge(a) or not _low_edge(b):
			continue
		var middle := (a + b) * 0.5
		if _support(middle) != null:
			continue
		var nearest: Variant = _nearest(middle)
		if nearest == null or middle.distance_to(nearest) > MAX_GAP:
			continue
		var road_a: Variant = _vertex_match(a)
		var road_b: Variant = _vertex_match(b)
		if road_a == null or road_b == null:
			continue
		if a.distance_to(road_a) > MAX_GAP or b.distance_to(road_b) > MAX_GAP:
			continue
		var initial := output.size()
		_seal_interval(output, a, b, road_a, road_b, 0)
		if output.size() > initial:
			seam_count += 1
			maximum_gap = maxf(maximum_gap, middle.distance_to(nearest))
	return output


func _seal_interval(output: PackedVector3Array, a: Vector3, b: Vector3, road_a: Vector3, road_b: Vector3, depth: int) -> void:
	# At a junction the closest boundary can switch between a ribbon and fan.
	# A single chord between the projections would itself leave a tiny wedge.
	var middle := (a + b) * 0.5
	var road_middle: Variant = _vertex_match(middle)
	if road_middle == null or middle.distance_to(road_middle) > MAX_GAP:
		return
	if depth < 8 and road_middle.distance_to(road_a.lerp(road_b, 0.5)) > 0.001:
		_seal_interval(output, a, middle, road_a, road_middle, depth + 1)
		_seal_interval(output, middle, b, road_middle, road_b, depth + 1)
		return
	_triangle(output, a, b, road_a)
	_triangle(output, b, road_b, road_a)


static func boundary_edges(mesh: Mesh) -> Array:
	var positions: Array[Vector3] = []
	var ids: Dictionary = {}
	var counts: Dictionary = {}
	var faces := mesh.get_faces()
	for index in range(0, faces.size(), 3):
		var corners: Array[int] = []
		for offset in 3:
			var point := faces[index + offset]
			var key := Vector3i((point * 1000.0).round())
			if not ids.has(key):
				ids[key] = positions.size()
				positions.append(point)
			corners.append(ids[key])
		for offset in 3:
			var a := corners[offset]
			var b := corners[(offset + 1) % 3]
			var key := (mini(a, b) << 32) | maxi(a, b)
			counts[key] = int(counts.get(key, 0)) + 1
	var result: Array = []
	for key: int in counts:
		if counts[key] == 1:
			result.append(PackedVector3Array([positions[key >> 32], positions[key & 0xffffffff]]))
	return result


func _vertex_match(point: Vector3) -> Variant:
	var key := Vector3i((point * 1000.0).round())
	if not matched_vertices.has(key):
		var support = _support(point)
		matched_vertices[key] = support if support != null else _nearest(point)
	return matched_vertices[key]


func _nearest(point: Vector3) -> Variant:
	var nearest: Variant = null
	var distance := INF
	var flat := Vector2(point.x, point.z)
	for id: int in edge_tiles.get(_tile(point), []):
		var edge: PackedVector3Array = edges[id]
		var a := Vector2(edge[0].x, edge[0].z)
		var b := Vector2(edge[1].x, edge[1].z)
		var delta := b - a
		var fraction := clampf((flat - a).dot(delta) / maxf(delta.length_squared(), 0.000001), 0.0, 1.0)
		var candidate := edge[0].lerp(edge[1], fraction)
		var candidate_distance := flat.distance_squared_to(Vector2(candidate.x, candidate.z))
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = candidate
	return nearest


func _support(point: Vector3) -> Variant:
	for id: int in triangle_tiles.get(_tile(point), []):
		var t: PackedVector3Array = triangles[id]
		var a := Vector2(t[0].x, t[0].z)
		var ab := Vector2(t[1].x, t[1].z) - a
		var ac := Vector2(t[2].x, t[2].z) - a
		var determinant := ab.cross(ac)
		if absf(determinant) < 0.000001:
			continue
		var relative := Vector2(point.x, point.z) - a
		var u := relative.cross(ac) / determinant
		var v := ab.cross(relative) / determinant
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return Vector3(point.x, t[0].y + u * (t[1].y - t[0].y) + v * (t[2].y - t[0].y), point.z)
	return null


static func _low_edge(point: Vector3) -> bool:
	return absf(point.y - Layout.height_at(point.x, point.z) - Layout.ROAD_LIFT) < 0.006


static func _tile(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.z / TILE))


static func _index(tiles: Dictionary, points: PackedVector3Array, id: int, margin := 0.0) -> void:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		minimum = minimum.min(Vector2(point.x, point.z))
		maximum = maximum.max(Vector2(point.x, point.z))
	minimum -= Vector2.ONE * margin
	maximum += Vector2.ONE * margin
	for x in range(floori(minimum.x / TILE), floori(maximum.x / TILE) + 1):
		for z in range(floori(minimum.y / TILE), floori(maximum.y / TILE) + 1):
			var key := Vector2i(x, z)
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(id)


static func _triangle(output: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.0000000001:
		return
	output.append_array(PackedVector3Array([a, c, b] if normal.y > 0.0 else [a, b, c]))


static func mesh_from_faces(faces: PackedVector3Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in faces:
		tool.set_uv(Vector2(point.x, point.z) * 0.25)
		var wear := 0.94 + 0.035 * sin(point.x * 0.13 + point.z * 0.17) + 0.025 * cos(point.z * 0.34)
		var region := Color("b4a390") if point.x < -424 else (Color("a4aaa6") if point.x < 676 else Color("87949c"))
		var repaired := smoothstep(0.35, 0.85, sin(point.x * 0.018 + point.z * 0.025))
		tool.set_color(region * Color(wear, wear, wear) * lerpf(0.9, 1.08, repaired))
		tool.add_vertex(point)
	tool.generate_normals()
	tool.index()
	return tool.commit()
