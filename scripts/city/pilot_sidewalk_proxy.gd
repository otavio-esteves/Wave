extends RefCounted

# Simplify the boundary of each disconnected sidewalk strip, retaining its
# height changes. Hole bridges preserve access yards; ambiguous topology and
# triangulation failures retain the original mesh.
static func bake(mesh: ArrayMesh) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var unique: Dictionary = {}
	var original: Array[int] = []
	var remap := PackedInt32Array()
	for index in positions.size():
		var point := Vector2(positions[index].x, positions[index].z).snapped(Vector2.ONE * 0.001)
		if not unique.has(point):
			unique[point] = original.size()
			original.append(index)
		remap.append(unique[point])
	var edges: Dictionary = {}
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle in range(0, indices.size(), 3):
		for side in 3:
			var a := remap[indices[triangle + side]]
			var b := remap[indices[triangle + (side + 1) % 3]]
			if a == b:
				continue
			var key := Vector2i(mini(a, b), maxi(a, b))
			edges[key] = int(edges.get(key, 0)) + 1
	var adjacency: Dictionary = {}
	for edge: Vector2i in edges:
		if edges[edge] != 1:
			continue
		for vertex in [edge.x, edge.y]:
			if not adjacency.has(vertex):
				adjacency[vertex] = []
			adjacency[vertex].append(edge.y if vertex == edge.x else edge.x)
	for neighbours: Array in adjacency.values():
		if neighbours.size() != 2:
			return mesh
	var visited: Dictionary = {}
	var loops: Array[PackedInt32Array] = []
	for start: int in adjacency:
		if visited.has(start):
			continue
		var loop := PackedInt32Array()
		var previous := -1
		var current := start
		while not visited.has(current):
			visited[current] = true
			loop.append(original[current])
			var next: int = adjacency[current][0] if adjacency[current][0] != previous else adjacency[current][1]
			previous = current
			current = next
		if current != start or loop.size() < 3:
			return mesh
		loops.append(loop)
	var polygons: Array[PackedVector2Array] = []
	for loop in loops:
		var polygon := PackedVector2Array()
		for index in loop:
			polygon.append(Vector2(positions[index].x, positions[index].z))
		polygons.append(polygon)
	var simplified: Array[PackedVector3Array] = []
	var depths: Array[int] = []
	for loop_index in loops.size():
		var loop := loops[loop_index]
		var depth := 0
		for other in polygons.size():
			if other != loop_index and Geometry2D.is_point_in_polygon(polygons[loop_index][0], polygons[other]):
				depth += 1
		depths.append(depth)
		var pivot := 1
		for index in range(2, loop.size()):
			if positions[loop[index]].distance_squared_to(positions[loop[0]]) > positions[loop[pivot]].distance_squared_to(positions[loop[0]]):
				pivot = index
		var first := _simplify(loop.slice(0, pivot + 1), positions)
		var second := loop.slice(pivot)
		second.append(loop[0])
		second = _simplify(second, positions)
		first.append_array(second.slice(1, second.size() - 1))
		var points := PackedVector3Array()
		for index in first:
			points.append(positions[index])
		simplified.append(points)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for outer in loops.size():
		if depths[outer] % 2 == 1:
			continue
		var points := simplified[outer].duplicate()
		if Geometry2D.is_polygon_clockwise(_project(points)):
			points.reverse()
		var holes: Array[PackedVector3Array] = []
		for inner in loops.size():
			if depths[inner] == depths[outer] + 1 and Geometry2D.is_point_in_polygon(polygons[inner][0], polygons[outer]):
				holes.append(simplified[inner])
		holes.sort_custom(func(a, b): return _rightmost(a).x > _rightmost(b).x)
		for hole in holes:
			points = _bridge(points, hole)
			if points.is_empty():
				return mesh
		var triangles := _triangulate(_project(points))
		if triangles.is_empty() or triangles.size() % 3 != 0:
			return mesh
		for triangle in range(0, triangles.size(), 3):
			# CCW in X/Z projects to clockwise front faces from above in Godot.
			for vertex in [triangles[triangle], triangles[triangle + 1], triangles[triangle + 2]]:
				var point := points[vertex]
				var slab := int(floor(point.x / 1.3) + floor(point.z / 1.3)) % 7
				var variation := 0.92 + slab * 0.014
				tool.set_normal(Vector3.UP)
				tool.set_uv(Vector2(point.x, point.z) * 0.18)
				tool.set_color((Color("c3b79e") if point.x < -424 else Color("bcc4c5")) * Color(variation, variation, variation))
				tool.add_vertex(point)
	tool.index()
	var result := tool.commit()
	var original_area := _area(mesh.get_faces())
	if absf(_area(result.get_faces()) - original_area) > original_area * 0.03:
		return mesh
	return result if result.get_faces().size() < mesh.get_faces().size() else mesh


static func _project(points: PackedVector3Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(point.x, point.z))
	return result


static func _rightmost(points: PackedVector3Array) -> Vector3:
	var result := points[0]
	for point in points:
		if point.x > result.x:
			result = point
	return result


static func _bridge(outer: PackedVector3Array, hole: PackedVector3Array) -> PackedVector3Array:
	if not Geometry2D.is_polygon_clockwise(_project(hole)):
		hole.reverse()
	var index := 0
	for cursor in range(1, hole.size()):
		if hole[cursor].x > hole[index].x:
			index = cursor
	var h := hole[index]
	var edge := -1
	var nearest := INF
	var t := 0.0
	for cursor in outer.size():
		var a := outer[cursor]
		var b := outer[(cursor + 1) % outer.size()]
		if (a.z > h.z) == (b.z > h.z):
			continue
		var along := (h.z - a.z) / (b.z - a.z)
		var x := lerpf(a.x, b.x, along)
		if x > h.x and x < nearest:
			nearest = x
			edge = cursor
			t = along
	if edge < 0:
		return PackedVector3Array()
	var connection := outer[edge].lerp(outer[(edge + 1) % outer.size()], t)
	var insert := edge + 1
	outer.insert(insert, connection)
	var result := outer.slice(0, insert + 1)
	for cursor in hole.size():
		result.append(hole[(index + cursor) % hole.size()])
	result.append(h)
	result.append(connection)
	result.append_array(outer.slice(insert + 1))
	return result


static func _triangulate(points: PackedVector2Array) -> PackedInt32Array:
	if points.size() < 3:
		return PackedInt32Array()
	var remaining: Array[int] = []
	for index in points.size():
		remaining.append(index)
	var result := PackedInt32Array()
	while remaining.size() > 3:
		var clipped := false
		for cursor in remaining.size():
			var a := remaining[posmod(cursor - 1, remaining.size())]
			var b := remaining[cursor]
			var c := remaining[(cursor + 1) % remaining.size()]
			var area := (points[b] - points[a]).cross(points[c] - points[a])
			if area <= 0.000001:
				continue
			var blocked := false
			for other in remaining:
				if other in [a, b, c] or points[other].is_equal_approx(points[a]) or points[other].is_equal_approx(points[b]) or points[other].is_equal_approx(points[c]):
					continue
				if (points[b] - points[a]).cross(points[other] - points[a]) > 0.000001 and (points[c] - points[b]).cross(points[other] - points[b]) > 0.000001 and (points[a] - points[c]).cross(points[other] - points[c]) > 0.000001:
					blocked = true
					break
			if not blocked:
				result.append_array(PackedInt32Array([a, b, c]))
				remaining.remove_at(cursor)
				clipped = true
				break
		if not clipped:
			return PackedInt32Array()
	result.append_array(PackedInt32Array(remaining))
	return result


static func _area(faces: PackedVector3Array) -> float:
	var area := 0.0
	for index in range(0, faces.size(), 3):
		area += absf((faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).y) * 0.5
	return area


static func _simplify(path: PackedInt32Array, positions: PackedVector3Array) -> PackedInt32Array:
	if path.size() <= 2:
		return path
	var maximum := 0.035 * 0.035
	var pivot := -1
	for index in range(1, path.size() - 1):
		var point := positions[path[index]]
		var closest := Geometry3D.get_closest_point_to_segment(point, positions[path[0]], positions[path[-1]])
		var error := point.distance_squared_to(closest)
		if error > maximum:
			maximum = error
			pivot = index
	if pivot < 0:
		return PackedInt32Array([path[0], path[-1]])
	var first := _simplify(path.slice(0, pivot + 1), positions)
	first.append_array(_simplify(path.slice(pivot), positions).slice(1))
	return first
