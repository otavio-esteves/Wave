extends RefCounted

const Route = preload("res://scripts/city/figueiras_route.gd")

const AVENIDA := 0
const FABRICA := 1
const CANAL := 2
const TRAVESSA := 3
const BOUNDS := Rect2(-276, 238, 592, 348)
const WATER_TOWER := Vector2(-136, 431)
const BRIDGE_HALF_SPAN := 15.0
const LOADING_START := 12.0
const LOADING_END := 53.0

static var _roads: Array[Route] = []
static var _junctions: Dictionary[Route, PackedFloat32Array] = {}
static var _bounds: Array[Rect2] = []
static var _bridges: Dictionary[Route, float] = {}


static func routes(vale: Route) -> Array[Route]:
	if not _roads.is_empty():
		return _roads

	var west := _junction(vale, Vector2(-158, 282))
	var east := _junction(vale, Vector2(170, 307))
	var center := _junction(vale, Vector2(47, 287))
	var avenue := Route.new("Avenida da Baixada", 14.4, [
		[vale.point_at(west), Vector2.ZERO, Vector2(-26, 8)],
		[Vector2(-216, 333), Vector2(22, -24), Vector2(-19, 26)],
		[Vector2(-225, 420), Vector2(-4, -33), Vector2(5, 29)],
		[Vector2(-186, 498), Vector2(-23, -22), Vector2(25, 24)],
		[Vector2(-103, 526), Vector2(-35, 0), Vector2(35, 0)],
		[Vector2(-29, 524), Vector2(-30, 0), Vector2(34, 0)],
		[Vector2(81, 527), Vector2(-36, 0), Vector2(40, 0)],
		[Vector2(188, 505), Vector2(-34, 17), Vector2(38, -19)],
		[Vector2(260, 442), Vector2(-6, 30), Vector2(7, -34)],
		[Vector2(239, 359), Vector2(22, 21), Vector2(-24, -24)],
		[vale.point_at(east), Vector2(33, 19), Vector2.ZERO],
	], PackedVector2Array([
		Vector2(0.0, vale.height_at(west)), Vector2(0.11, 25.2), Vector2(0.23, 20.1),
		Vector2(0.36, 19.2), Vector2(0.53, 21.9), Vector2(0.65, 23.8),
		Vector2(0.79, 32.2), Vector2(0.89, 37.3), Vector2(1.0, vale.height_at(east)),
	]), -1.0, Vector2(6.5, 6.5))
	var factory_west := _junction(avenue, Vector2(-227, 393))
	var factory_south := _junction(avenue, Vector2(-108, 526))
	var canal_south := _junction(avenue, Vector2(51, 527))
	var factory := Route.new("Rua da Fábrica", 9.2, [
		[avenue.point_at(factory_west), Vector2.ZERO, Vector2(19, -2)],
		[Vector2(-169, 388), Vector2(-19, -7), Vector2(19, 7)],
		[Vector2(-124, 422), Vector2(-9, -14), Vector2(12, 18)],
		[Vector2(-103, 472), Vector2(-3, -18), Vector2(3, 18)],
		[avenue.point_at(factory_south), Vector2(0, -22), Vector2.ZERO],
	], PackedVector2Array([
		Vector2(0.0, avenue.height_at(factory_west)), Vector2(0.48, 20.1),
		Vector2(0.78, 19.6), Vector2(1.0, avenue.height_at(factory_south)),
	]), -1.0, Vector2(5.4, 5.3))
	var canal := Route.new("Alameda do Canal", 9.8, [
		[vale.point_at(center), Vector2.ZERO, Vector2(-1, 23)],
		[Vector2(35, 361), Vector2(4, -23), Vector2(-4, 27)],
		[Vector2(19, 439), Vector2(0, -26), Vector2(0, 24)],
		[Vector2(41, 487), Vector2(-14, -12), Vector2(13, 14)],
		[avenue.point_at(canal_south), Vector2(0, -14), Vector2.ZERO],
	], PackedVector2Array([
		Vector2(0.0, vale.height_at(center)), Vector2(0.35, 20.0),
		Vector2(0.66, 22.1), Vector2(1.0, avenue.height_at(canal_south)),
	]), -1.0, Vector2(5.4, 5.2))
	var factory_link := _junction(factory, Vector2(-131, 410))
	var canal_link := _junction(canal, Vector2(25, 407))
	var crossing := Route.new("Travessa da Usina", 8.0, [
		[factory.point_at(factory_link), Vector2.ZERO, Vector2(18, -2)],
		[Vector2(-80, 408), Vector2(-17, -1), Vector2(18, 2)],
		[Vector2(-24, 420), Vector2(-18, 1), Vector2(18, -1)],
		[canal.point_at(canal_link), Vector2(-17, 4), Vector2.ZERO],
	], PackedVector2Array([
		Vector2(0.0, factory.height_at(factory_link)), Vector2(0.54, 20.8),
		Vector2(1.0, canal.height_at(canal_link)),
	]), -1.0, Vector2(4.5, 4.5))
	_roads = [avenue, factory, canal, crossing]
	for road in _roads:
		var box := Rect2(road.points[0], Vector2.ZERO)
		for point in road.points:
			box = box.expand(point)
		_bounds.append(box.grow(24.0))
	return _roads


static func _junction(road: Route, approximate_site: Vector2) -> float:
	var station := road.project(approximate_site).x
	var stations: PackedFloat32Array = _junctions.get(road, PackedFloat32Array())
	stations.append(station)
	_junctions[road] = stations
	return station


static func junctions(road: Route) -> PackedFloat32Array:
	return _junctions.get(road, PackedFloat32Array())


static func near_junction(road: Route, station: float, padding: float) -> bool:
	for junction in junctions(road):
		if absf(junction - station) < padding:
			return true
	return false


static func sample(point: Vector2) -> Vector4:
	var best := Vector4(-1, 0, 0, INF)
	var best_edge := INF
	for index in _roads.size():
		if not _bounds[index].has_point(point):
			continue
		var road := _roads[index]
		var result := road.project(point)
		var distance := result.z - road.edge_at(result.x, result.y)
		if distance < best_edge:
			best_edge = distance
			best = Vector4(index, result.x, result.y, result.z)
	return best


static func edge(info: Vector4) -> float:
	return info.w - _roads[int(info.x)].edge_at(info.y, info.z) if info.x >= 0 else INF


static func floodplain_height(point: Vector2, surrounding: float) -> float:
	var basin := smoothstep(321.0, 393.0, point.y) * (1.0 - smoothstep(255.0, 340.0, absf(point.x + 9.0)))
	basin *= 1.0 - smoothstep(558.0, 640.0, point.y)
	var alluvium := 19.7 + point.x * 0.016 + 0.83 * cos(point.y * 0.029 + point.x * 0.012)
	var riverbank := 1.0 - smoothstep(16.0, 86.0, absf(point.x + 38.0))
	alluvium += 2.0 * (1.0 - riverbank) + 12.4 * smoothstep(99.0, 252.0, point.x)
	return lerpf(surrounding, alluvium, basin)


static func form_road(surrounding: float, info: Vector4, vale_edge: float) -> float:
	if info.x < 0 or info.w >= 26.0:
		return surrounding
	var road := _roads[int(info.x)]
	var distance := edge(info)
	var shoulder := clampf(distance / 0.40, 0.0, 1.0) * 0.118
	var crown := -minf(absf(info.z), road.half_width) * 0.015
	var sibling_join := near_junction(road, info.y, 11.0) or minf(info.y, road.length - info.y) < 11.0
	# Round off the lips across intersecting streets.
	if sibling_join:
		shoulder *= smoothstep(0.0, 2.0, distance)
	var fit := (1.0 - smoothstep(2.8, 18.0, distance)) * smoothstep(-1.0, 6.0, vale_edge)
	return lerpf(surrounding, road.height_at(info.y) + crown + shoulder, fit)


static func bridge_stations(creek_x: Callable) -> Dictionary[Route, float]:
	if _bridges.is_empty():
		for index in [AVENIDA, TRAVESSA]:
			var road := _roads[index]
			var station := road.project(Vector2(-40.0, 524.0 if index == AVENIDA else 418.0)).x
			for iteration in 3:
				var z := road.point_at(station).y
				station = road.project(Vector2(creek_x.call(z), z)).x
			_bridges[road] = station
	return _bridges


static func bridge_opening(info: Vector4, creek: float, creek_x: Callable) -> float:
	if info.x != AVENIDA and info.x != TRAVESSA:
		return 0.0
	var road := _roads[int(info.x)]
	var along := absf(info.y - bridge_stations(creek_x)[road])
	if along > BRIDGE_HALF_SPAN:
		return 0.0
	var across := maxf(creek, 1.0 - smoothstep(road.half_width + 0.3, road.half_width + 8.0, absf(info.z)))
	return (1.0 - smoothstep(7.3, BRIDGE_HALF_SPAN, along)) * across


static func loading_surface(info: Vector4) -> bool:
	return info.x == TRAVESSA and absf(info.z) < 3.96 and info.y > LOADING_START and info.y < LOADING_END


static func shelter(info: Vector4) -> float:
	if info.x != TRAVESSA:
		return 0.0
	var along := minf(info.y - 13.0, 53.0 - info.y)
	return smoothstep(-0.5, 1.1, along) * (1.0 - smoothstep(5.1, 6.35, absf(info.z)))
