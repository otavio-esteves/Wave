extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Route = preload("res://scripts/city/figueiras_route.gd")

var _city: RefCounted
var _ground: RefCounted


func build(builder: RefCounted, terrain: RefCounted) -> void:
	_city = builder
	_ground = terrain
	var length := 0.0
	for road in Layout.urban_routes():
		_junction(road, true)
		_junction(road, false)
		if road == Layout.urban_routes()[0] or road == Layout.urban_routes()[1]:
			_frontages(road)
		length += road.length
	_passage_markings(Layout.urban_routes()[Layout.GALERIA_ROUTE], 0.17, "yellow")
	_passage_markings(Layout.urban_routes()[Layout.ESTACAO_ROUTE], 0.0, "white")
	_city.scene_root.set_meta("urban_link_length", length)
	_median(Vector2(-111.0, Layout.AVENUE), 11.0)
	_median(Vector2(8.75, Layout.AVENUE), 3.5)
	_median(Vector2(131.0, Layout.AVENUE), 14.0)
	_city = null
	_ground = null


func _junction(road: Route, entry: bool) -> void:
	var end := 0.0 if entry else road.length
	var direction := 1.0 if entry else -1.0
	var mouth := road.point_at(end)
	var crossing := (Layout.AVENUE_HALF if absf(mouth.y - Layout.AVENUE) < 0.1 else Layout.LOCAL_HALF) + 4.6
	var station := end + direction * crossing
	var half_width := road.edge_at(station, 1.0)
	for strip in range(-floori(half_width - 0.7), floori(half_width - 0.7) + 1):
		_mark(road, station - 1.06, station + 1.06, strip - 0.27, strip + 0.27, "white")
	var stop := station + direction * 2.3
	_mark(road, stop - 0.15, stop + 0.15, minf(0.0, direction * -4.2), maxf(0.0, direction * -4.2), "white")
	var across := road.direction_at(station).orthogonal() * direction
	var corner := road.offset_at(station, direction * (half_width + 0.85))
	_city._lamp(corner, -across)
	var base := Layout.surface_point(corner + across * 0.64)
	var sign := base + Vector3.UP * 2.18
	var yaw := atan2(across.x, across.y)
	_city.add_box(base + Vector3.UP * 1.06, Vector3(0.10, 2.16, 0.10), "steel_plate")
	_city.add_box(sign, Vector3(3.9, 0.44, 0.12), "sign_ink", false, yaw)
	_city.add_label(road.title.to_upper(), sign + Vector3(across.x, 0, across.y) * 0.075, yaw, 0.0105)


func _mark(road: Route, start: float, end: float, left: float, right: float, finish: String) -> void:
	var polygon := PackedVector2Array([road.offset_at(start, left), road.offset_at(end, left),
		road.offset_at(end, right), road.offset_at(start, right)])
	if (polygon[1] - polygon[0]).cross(polygon[2] - polygon[0]) < 0.0:
		polygon.reverse()
	_ground.patch_polygon(polygon, finish, 0.028)


func _passage_markings(road: Route, lane_gap: float, finish: String) -> void:
	# Keep lane paint away from the junction crossing and its stop lines.
	for station in range(18, floori(road.length) - 17, 8):
		_mark(road, station, station + 3.0, lane_gap - 0.055, lane_gap + 0.055, finish)
		if lane_gap > 0.0:
			_mark(road, station, station + 3.0, -lane_gap - 0.055, -lane_gap + 0.055, finish)
	for side: float in [-1.0, 1.0]:
		for station in range(19, floori(road.length) - 20, 6):
			var edge := (road.edge_at(float(station + 3), side) - 0.48) * side
			_mark(road, station, station + 2.7, edge - 0.048, edge + 0.048, "white")


func _frontages(road: Route) -> void:
	var alameda := road == Layout.urban_routes()[1]
	var margin := road.half_width
	for station in range(20, floori(road.length) - 14, 10):
		var axis := road.direction_at(station)
		var across := axis.orthogonal()
		if alameda and station < road.length - 19.0:
			_mark(road, station, station + 4.5, -0.061, 0.061, "yellow")
		for side: float in [-1.0, 1.0]:
			var verge := road.offset_at(station, side * (road.edge_at(station, side) + 0.85))
			if station % 30 == 0 and side == 1.0:
				_city._lamp(verge, -across)
			else:
				_city._tree(verge, 4.8 + 1.35 * absf(sin(station * 0.26)), 1 if alameda else 3)
			_city._garden(road.offset_at(station, side * (margin + 4.2)), 1.18, 5)
	for station: float in ([41.0, 64.0, 92.0, 119.0] if alameda else [36.0, 65.0, 94.0]):
		var across := road.direction_at(station).orthogonal()
		for side: float in [-1.0, 1.0]:
			var front := road.offset_at(station, side * (margin + Layout.WALK_WIDTH))
			var site := front + across * side * 8.4
			if absf(site.x) > 37.0 or Layout._grid_distance(site) < 26.0:
				continue
			if alameda and station == 64.0 and side == -1.0:
				_station_garden(road, station, side)
				continue
			var yaw := atan2(-across.x * side, -across.y * side)
			var style := "cream" if alameda else ("sage" if side > 0.0 else "blue")
			_city._facade(site, front, yaw, 9.3 + absf(cos(station)) * 2.8, 2 if alameda else 1, 9.5, style, "")


func _station_garden(road: Route, station: float, side: float) -> void:
	var axis := road.direction_at(station)
	var facing := axis.orthogonal() * -side
	var yaw := atan2(facing.x, facing.y)
	var site := road.offset_at(station, side * 11.8)
	var point := Layout.surface_point(site)
	var corners := PackedVector2Array()
	for offset in [Vector2(-7.0, -3.3), Vector2(7.0, -3.3), Vector2(7.0, 3.3), Vector2(-7.0, 3.3)]:
		corners.append(site + axis * offset.x + facing * offset.y)
	if (corners[1] - corners[0]).cross(corners[2] - corners[0]) < 0.0:
		corners.reverse()
	_ground.patch_polygon(corners, "cobbles", 0.027)
	for x: float in [-5.2, 0.0, 5.2]:
		for z: float in [-1.25, 1.25]:
			var base := Layout.surface_point(site + axis * x + facing * z)
			var height := point.y + 3.16 - base.y
			_city.add_box(base + Vector3.UP * height * 0.5, Vector3(0.20, height, 0.20), "brick", true, yaw)
	_city.add_part(point, Vector3(0, 3.24, 0), Vector3(12.2, 0.26, 4.05), "roof_gray", yaw)
	_city.add_part(point, Vector3(0, 2.92, 1.87), Vector3(8.5, 0.42, 0.13), "sign_ink", yaw)
	var sign := point + Vector3(facing.x * 1.95, 2.92, facing.y * 1.95)
	_city.add_label("JARDIM DA ESTAÇÃO", sign, yaw, 0.018)
	for x: float in [-3.3, 3.3]:
		_city._bench(site + axis * x, yaw)
		_city._garden(site + axis * x - facing * 4.4, 2.35, 16)


func _median(site: Vector2, length: float) -> void:
	var refuge := length < 4.0
	var border := 0.79
	if not refuge:
		_ground.patch(Rect2(site - Vector2(length * 0.5 + 6.0, border), Vector2(length + 12.0, border * 2.0)), "median_pavers", 0.015)
		for side: float in [-1.0, 1.0]:
			for index in 3:
				var x := site.x + side * (length * 0.5 + 1.3 + index * 1.52)
				_ground.patch_polygon(PackedVector2Array([Vector2(x - 0.42, site.y - 0.67), Vector2(x - 0.23, site.y - 0.67),
					Vector2(x + 0.44, site.y + 0.67), Vector2(x + 0.25, site.y + 0.67)]), "yellow", 0.028)
	var span := length * 0.5
	if refuge:
		for side: float in [-1.0, 1.0]:
			var nose := Layout.surface_point(site + Vector2(side * (span + 0.69), 0), 0.073)
			_city.add_box(nose, Vector3(1.10, 0.19, 1.33), "curb", true)
			var post := nose + Vector3.UP * 0.42
			_city.add_instance("cylinder", "bollard", post, Vector3(0.19, 0.93, 0.19), 0.0, false)
			_city.add_instance("cylinder", "tactile", post + Vector3.UP * 0.38, Vector3(0.192, 0.16, 0.192), 0.0, false)
		_ground.patch(Rect2(site - Vector2(span, border), Vector2(length, border * 2.0)), "tactile", 0.023)
		return
	for segment in ceili(length / 2.8):
		var step := length / ceili(length / 2.8)
		var a := Layout.surface_point(site + Vector2(-span + segment * step, 0), 0.08)
		var b := Layout.surface_point(site + Vector2(-span + (segment + 1) * step, 0), 0.08)
		var basis := Basis.looking_at((b - a).normalized())
		_city._add_tilted_box((a + b) * 0.5, basis, Vector3(1.58, 0.24, a.distance_to(b) + 0.035), "curb", true)
	for index in range(-floori(span) + 1, floori(span), 2):
		var planter := Layout.surface_point(site + Vector2(index, 0), 0.39)
		_city.add_instance("shrub", "bush", planter, Vector3(0.60, 0.37, 0.63), index * 0.41, false)
		_city.add_instance("flower_heads", "flowers", planter + Vector3.UP * 0.20, Vector3(0.49, 0.23, 0.48), index * 0.41, false)
