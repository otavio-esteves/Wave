extends RefCounted

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var adjacency: Dictionary = {}
var streets: Array[Dictionary] = []


func _init() -> void:
	for edge in Layout.edges():
		var points := Layout.edge_points(edge.a, edge.b)
		var length := 0.0
		for index in points.size() - 1:
			length += points[index].distance_to(points[index + 1])
		streets.append({"a": edge.a, "b": edge.b, "points": points})
		for pair in [[edge.a, edge.b], [edge.b, edge.a]]:
			if not adjacency.has(pair[0]):
				adjacency[pair[0]] = []
			adjacency[pair[0]].append({"node": pair[1], "length": length})


func nearest_street(point: Vector3) -> Dictionary:
	var nearest := INF
	var result: Dictionary = {}
	for street in streets:
		var points: PackedVector3Array = street.points
		for index in points.size() - 1:
			var projected := Geometry3D.get_closest_point_to_segment(point, points[index], points[index + 1])
			var distance := point.distance_squared_to(projected)
			if distance < nearest:
				nearest = distance
				result = {"street": street, "index": index, "point": projected}
	return result


func shortest_path(start: int, destination: int) -> Array:
	var costs := {start: 0.0}
	var previous: Dictionary = {}
	var frontier := [start]
	while not frontier.is_empty():
		frontier.sort_custom(func(a: int, b: int) -> bool: return costs[a] < costs[b])
		var node: int = frontier.pop_front()
		if node == destination:
			break
		for neighbor in adjacency[node]:
			var cost: float = costs[node] + neighbor.length
			if cost < float(costs.get(neighbor.node, INF)):
				costs[neighbor.node] = cost
				previous[neighbor.node] = node
				if neighbor.node not in frontier:
					frontier.append(neighbor.node)
	if not costs.has(destination):
		return []
	var path := [destination]
	while path[0] != start:
		path.push_front(previous[path[0]])
	return path


func route_to_access(position: Vector3, access: PackedVector3Array, departure: PackedVector3Array = PackedVector3Array()) -> PackedVector3Array:
	var prefix := PackedVector3Array()
	if not departure.is_empty():
		var nearest := INF
		var at := 0
		var projected := position
		for index in departure.size() - 1:
			var point := Geometry3D.get_closest_point_to_segment(position, departure[index], departure[index + 1])
			if point.distance_squared_to(position) < nearest:
				nearest = point.distance_squared_to(position)
				at = index
				projected = point
		prefix.append(position)
		prefix.append(projected)
		for index in range(at, -1, -1):
			prefix.append(departure[index])
		position = departure[0]
	var source := nearest_street(position)
	var target := nearest_street(access[0])
	var best := PackedVector3Array()
	var best_length := INF
	# Include the distance along each partial edge when choosing its endpoint.
	for start in [source.street.a, source.street.b]:
		for end in [target.street.a, target.street.b]:
			var ids := shortest_path(start, end)
			if ids.is_empty():
				continue
			var candidate := _partial(source, start)
			if ids.size() > 1:
				candidate.append_array(Layout.route(ids))
			var arrival := _partial(target, end)
			arrival.reverse()
			candidate.append_array(arrival)
			candidate.append_array(access)
			var length := _length(candidate)
			if length < best_length:
				best_length = length
				best = candidate
	if source.street.a == target.street.a and source.street.b == target.street.b:
		var direct := PackedVector3Array([source.point])
		var first: int = source.index
		var last: int = target.index
		var direction := 1 if last >= first else -1
		for index in range(first + (1 if direction > 0 else 0), last + (1 if direction > 0 else -1), direction):
			direct.append(source.street.points[index])
		direct.append(target.point)
		direct.append_array(access)
		if _length(direct) < best_length:
			best = direct
	prefix.append_array(best)
	return _round_turns(prefix)


func _partial(location: Dictionary, endpoint: int) -> PackedVector3Array:
	var points: PackedVector3Array = location.street.points
	var result := PackedVector3Array([location.point])
	if endpoint == location.street.a:
		for index in range(location.index, -1, -1):
			result.append(points[index])
	else:
		for index in range(location.index + 1, points.size()):
			result.append(points[index])
	return result


static func _length(points: PackedVector3Array) -> float:
	var length := 0.0
	for index in points.size() - 1:
		length += points[index].distance_to(points[index + 1])
	return length


static func _round_turns(points: PackedVector3Array) -> PackedVector3Array:
	var clean := PackedVector3Array()
	for point in points:
		if clean.is_empty() or Vector2(point.x - clean[-1].x, point.z - clean[-1].z).length() > 0.01:
			clean.append(point)
	var result := PackedVector3Array()
	var index := 0
	while index < clean.size():
		if index > 0 and index < clean.size() - 1:
			var incoming := (clean[index] - clean[index - 1]).normalized()
			var outgoing := (clean[index + 1] - clean[index]).normalized()
			if incoming.dot(outgoing) < cos(deg_to_rad(35.0)):
				var before := index - 1
				var after := index + 1
				while before > 0 and clean[before].distance_to(clean[index]) < 6.0:
					before -= 1
				while after < clean.size() - 1 and clean[after].distance_to(clean[index]) < 6.0:
					after += 1
				var start := clean[index].move_toward(clean[before], 6.0)
				var end := clean[index].move_toward(clean[after], 6.0)
				while not result.is_empty() and result[-1].distance_to(clean[index]) < 6.0:
					result.remove_at(result.size() - 1)
				for step in 13:
					var t := step / 12.0
					var point := start.lerp(clean[index], t).lerp(clean[index].lerp(end, t), t)
					point.y = Layout.height_at(point.x, point.z) + Layout.CAR_LIFT
					result.append(point)
				index = after
				continue
		result.append(clean[index])
		index += 1
	return result
