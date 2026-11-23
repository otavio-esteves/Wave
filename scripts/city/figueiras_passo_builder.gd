extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Route = preload("res://scripts/city/figueiras_route.gd")
const BASALT = preload("res://assets/textures/figueiras/basalto-do-passo.png")
const SECTION_LENGTH := 4.5

var _city: RefCounted
var _ground: RefCounted
var _road: Route


func build(city: RefCounted, ground: RefCounted, road: Route) -> void:
	_city = city
	_ground = ground
	_road = road
	var strata := StandardMaterial3D.new()
	strata.resource_name = "passo_basalt"
	strata.albedo_color = Color("d0c6b1")
	strata.albedo_texture = BASALT
	strata.roughness = 0.96
	_city.materials["passo_basalt"] = strata
	_city.meshes["passo_talus"] = _talus_mesh()
	_earthworks()
	_turnout()
	_junction_sign(Layout.urban_routes()[Layout.HORTO_ROUTE], Layout.PASSO_HORTO_STATION)
	_junction_sign(Layout.scenic_routes()[0], Layout.PASSO_MIRANTE_STATION)
	_city.scene_root.set_meta("passo_length", _road.length)
	_city.scene_root.set_meta("passo_crest_station", _road.stop_station)
	_city = null
	_ground = null
	_road = null


func _earthworks() -> void:
	for first in range(22, floori(_road.length) - 24, 6):
		var last := float(first) + 6.0
		var middle := (first + last) * 0.5
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and absf(middle - _road.stop_station) < 39.0:
				continue
			var edge := _road.edge_at(middle, side)
			var toe: Vector3 = _ground.surface_point(_road.offset_at(middle, side * (edge + 2.1)))
			var crest: Vector3 = _ground.surface_point(_road.offset_at(middle, side * (edge + 9.0)))
			var rise := crest.y - toe.y
			if rise > 1.1 and ((middle > 78.0 and middle < 124.0) or (middle > 282.0 and middle < 321.0)):
				_retaining_course(first, last, side)
			elif rise > 1.7 and sin(middle * 0.22 + side) > -0.15:
				for index in 3:
					var along := middle + (index - 1) * 1.54
					var width := _road.edge_at(along, side) + 3.9 + absf(cos(along * 2.18)) * 1.45
					var site := _road.offset_at(along, width * side)
					var fragment_size := 0.24 + absf(sin(along * 0.79)) * 0.52
					if Layout.road_distance(site) > 2.8:
						_city.add_instance("passo_talus", "passo_basalt", _ground.surface_point(site, -0.03),
							Vector3(fragment_size, fragment_size * 0.56, fragment_size * 0.81), along * 2.33, false)
			if first % 18 == 4 and rise < 2.8:
				var sapling := _road.offset_at(middle, side * (edge + 6.6 + sin(middle * 0.56) * 2.4))
				if Layout.road_distance(sapling) > 3.0:
					_city._tree(sapling, 5.4 + absf(sin(middle * 0.18)) * 3.9, posmod(first, 4), false, false)


func _talus_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foot := PackedVector3Array()
	var top := PackedVector3Array()
	for corner in 6:
		var angle := TAU * corner / 6.0
		var radius := 0.45 + 0.13 * sin(corner * 2.61)
		var axis := Vector3(cos(angle), 0.0, sin(angle))
		foot.append(axis * (radius + 0.11) - Vector3.UP * 0.10)
		top.append(axis * radius * 0.82 + Vector3(0.11, 0.55 + 0.13 * sin(corner * 2.19), 0.05))
	for corner in 6:
		var next := (corner + 1) % 6
		for point: Vector3 in [foot[corner], foot[next], top[corner], foot[next], top[next], top[corner],
			Vector3(0.07, 0.62, 0.06), top[corner], top[next]]:
			surface.set_uv(Vector2(point.x * 0.42 + point.y * 0.23, point.z * 0.39 + point.y * 0.44))
			surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	return surface.commit()


func _strip(start: float, end: float, side: float, distances: Vector2, material: String, lift: float) -> void:
	var first_edge := _road.edge_at(start, side)
	var last_edge := _road.edge_at(end, side)
	var path := PackedVector2Array([
		_road.offset_at(start, side * (first_edge + distances.x)), _road.offset_at(end, side * (last_edge + distances.x)),
		_road.offset_at(end, side * (last_edge + distances.y)), _road.offset_at(start, side * (first_edge + distances.y))])
	if (path[1] - path[0]).cross(path[2] - path[0]) < 0.0:
		path.reverse()
	_ground.patch_polygon(path, material, lift)


func _retaining_course(start: float, end: float, side: float) -> void:
	var part := side * (_road.half_width + 2.85)
	var first: Vector3 = _ground.surface_point(_road.offset_at(start, part))
	var last: Vector3 = _ground.surface_point(_road.offset_at(end, part))
	var pose := Basis.looking_at((last - first).normalized())
	var center := (first + last) * 0.5
	var length := first.distance_to(last) + 0.04
	var height := 1.43 + 0.25 * cos(start * 0.09)
	_city._add_tilted_box(center + pose.y * (height * 0.40 - 0.18), pose, Vector3(0.74, height * 0.81 + 0.40, length), "passo_basalt", true)
	_city._add_tilted_box(center + pose.y * (height * 0.8 + 0.05), pose, Vector3(0.91, 0.16, length), "trim", false)


func _turnout() -> void:
	var stop := _road.stop_station
	for offset in range(-18, 18, 3):
		_strip(stop + offset, stop + offset + 3.0, -1.0, Vector2(-5.3, -0.26), "cobbles", 0.044)
	for index in 8:
		var segment := -18.0 + SECTION_LENGTH * index
		var low := _road.offset_at(stop + segment, -_road.half_width - 7.35)
		var high := _road.offset_at(stop + segment + SECTION_LENGTH, -_road.half_width - 7.35)
		_city._rail(low, high, 0.31, 0.58, "passo_basalt", true)
		_city._rail(low, high, 0.75, 0.12, "steel_plate")
	for offset: float in [-12.0, -6.0, 6.0, 12.0]:
		_strip(stop + offset, stop + offset + 0.12, -1.0, Vector2(-4.65, -0.34), "white", 0.052)
	var site := _road.offset_at(stop, -_road.half_width - 8.05)
	var point: Vector3 = _ground.surface_point(site)
	var toward := _road.direction_at(stop).orthogonal()
	var yaw := atan2(toward.x, toward.y)
	var look := Basis(Vector3.UP, yaw)
	_city.add_box(point + Vector3.UP * 1.03, Vector3(4.10, 2.06, 0.66), "passo_basalt", true, yaw)
	_city.add_box(point + Vector3.UP * 2.06, Vector3(4.26, 0.19, 0.76), "trim", false, yaw)
	_city.add_label("ALTO DO PASSO", point + look * Vector3(0, 1.69, 0.35), yaw, 0.0105)
	_city._bench(_road.offset_at(stop + 10.0, -_road.half_width - 6.78), yaw)
	var marker := Marker3D.new()
	marker.name = "AltoDoPasso"
	marker.position = point
	_city.scene_root.add_child(marker)


func _junction_sign(source: Route, station: float) -> void:
	var approach := station - 10.0
	var entry_side := signf(source.project(_road.point_at(8.0) if source == Layout.urban_routes()[Layout.HORTO_ROUTE] else _road.point_at(_road.length - 8.0)).y)
	var site := source.offset_at(approach, entry_side * (source.edge_at(approach, entry_side) + 2.5))
	if Layout.road_distance(site) < 0.8:
		site = source.offset_at(approach - 8.0, -entry_side * (source.edge_at(approach - 8.0, -entry_side) + 2.1))
	var origin: Vector3 = _ground.surface_point(site)
	var incoming := -source.direction_at(approach)
	var yaw := atan2(incoming.x, incoming.y)
	var basis := Basis(Vector3.UP, yaw)
	_city.add_part(origin, Vector3(0, 0.92, 0), Vector3(0.10, 1.94, 0.11), "steel_plate", yaw)
	_city.add_part(origin, Vector3(0, 1.78, 0.07), Vector3(2.88, 0.68, 0.12), "awning_green", yaw)
	_city.add_label("PASSO  →" if entry_side < 0.0 else "←  PASSO", origin + basis * Vector3(0, 1.78, 0.14), yaw, 0.012)
