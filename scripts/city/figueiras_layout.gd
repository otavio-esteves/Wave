extends RefCounted

const Route = preload("res://scripts/city/figueiras_route.gd")
const CityLinks = preload("res://scripts/city/figueiras_urban_connections.gd")
const Baixada = preload("res://scripts/city/figueiras_baixada.gd")
const COLUMNS := [-194.0, -63.0, 64.0, 208.0]
const ROWS := [-176.0, -54.0, 52.0, 194.0]
const LOCAL_HALF := 3.8
const COLLECTOR_HALF := 6.0
const COLLECTOR := 64.0
const COLUMN_HALF_WIDTHS := [LOCAL_HALF, LOCAL_HALF, COLLECTOR_HALF, LOCAL_HALF]
const AVENUE := 52.0
const AVENUE_LANE := 3.7
const AVENUE_MEDIAN_HALF := 0.95
const AVENUE_TRAVEL_HALF := AVENUE_MEDIAN_HALF + AVENUE_LANE * 2.0
const PARKING_WIDTH := 2.35
const AVENUE_HALF := AVENUE_TRAVEL_HALF + PARKING_WIDTH
const ROW_HALF_WIDTHS := [LOCAL_HALF, LOCAL_HALF, AVENUE_HALF, LOCAL_HALF]
const WALK_WIDTH := 2.50
const AVENUE_WALK := 4.25
const CURB_WIDTH := 0.40
const GROUND_STEP := 6
const TERRAIN := Rect2(-432, -416, 864, 1064)
const STREET_BOUNDS := Rect2(-214, -190, 442, 399)
const MAP_BOUNDS := Rect2(-423, -318, 786, 885)
const HORTO_ROUTE := 2
const HORTO_PLAZA := 0.58
const MERCADO_ROUTE := 3
const GALERIA_ROUTE := 4
const ESTACAO_ROUTE := 5
const PASSO_ROUTE := 3
const PASSO_HORTO_STATION := 160.0
const PASSO_MIRANTE_STATION := 99.0
const MERCADO_COVER := Rect2(-156, 97, 52, 34)
const PLAZA := Rect2(-53, -42, 104, 80.0)
const DEPOT_AXIS := -129.0
const DEPOT := Rect2(-146, -168, 34, 106)
const MARKET := Vector2(-128.5, 75.1)
const RESERVOIR := Vector2(251, 15)
const LAKE := Vector2(275, 123)
const LAKE_RADII := Vector2(36.5, 37.0)
const LAKE_LEVEL := 30.65
const GALLERY_START := 344.0
const GALLERY_END := 392.0
const CREEK_WATER_LEVEL := 13.9
const CREEK_RANGE := Vector2(217.0, 607.0)
const VALE_BRIDGE_HALF_SPAN := 14.0
const VALE_BRIDGE_BOUNDS := Rect2(-73, 267, 77, 56)
const SPAWN := Vector2(-174, AVENUE + AVENUE_MEDIAN_HALF + AVENUE_LANE * 0.5)
const URBAN_JUNCTIONS := [
	Vector2(16.0, -176.0), Vector2(-23.0, -54.0),
	Vector2(-23.0, AVENUE), Vector2(24.0, 194.0),
]
const URBAN_BOUNDS := [Rect2(-52, -193, 100, 156), Rect2(-55, 34, 112, 179), Rect2(-354, -204, 178, 178), Rect2(-179, 30, 115, 116)]
const SCENIC_BOUNDS := [Rect2(-241, -347, 501, 219), Rect2(165, 8, 227, 232), Rect2(-239, 147, 497, 214), Rect2(-448, -314, 317, 251)]
const COBBLE_SURFACE := {"surface": "paralelepípedo", "friction": 0.91, "rolling": 1.30}
const WALK_SURFACE := {"surface": "calçada", "friction": 0.88, "rolling": 1.35}
const SHOULDER_SURFACE := {"surface": "acostamento", "friction": 0.77, "rolling": 2.15}
const GRASS_SURFACE := {"surface": "gramado", "friction": 0.66, "rolling": 3.5}
const SHELTERED_ASPHALT := {"surface": "asfalto", "wet_scale": 0.24}
const SHELTERED_COBBLES := {"surface": "paralelepípedo", "friction": 0.91, "rolling": 1.30, "wet_scale": 0.24}
const LOADING_CONCRETE := {"surface": "concreto", "friction": 0.94, "rolling": 1.18, "wet_scale": 0.24}
static var _routes: Array[Route] = []
static var _urban_routes: Array[Route] = []
static var _nursery_frame := Transform2D.IDENTITY
static var _nursery_elevation := 0.0
static var _vale_crossing := 0.0


static func urban_routes() -> Array[Route]:
	if _urban_routes.is_empty():
		_urban_routes = [
			_urban_route("Rua das Jabuticabeiras", 7.8, [
				[URBAN_JUNCTIONS[0], Vector2.ZERO, Vector2(0, 20)],
				[Vector2(9, -133), Vector2(8, -17), Vector2(-9, 19)],
				[Vector2(-20, -87), Vector2(8, -13), Vector2(-5, 11)],
				[URBAN_JUNCTIONS[1], Vector2(0, -14), Vector2.ZERO],
			]),
			_urban_route("Alameda da Estação", 9.4, [
				[URBAN_JUNCTIONS[2], Vector2.ZERO, Vector2(0, 22)],
				[Vector2(-18, 93), Vector2(-8, -17), Vector2(10, 18)],
				[Vector2(16, 132), Vector2(-13, -12), Vector2(12, 11)],
				[URBAN_JUNCTIONS[3], Vector2(0, -27), Vector2.ZERO],
			]),
			_horto_route(),
			_market_route(),
		]
		_urban_routes.append_array(CityLinks.routes(_grid_height))
	return _urban_routes


static func _market_route() -> Route:
	var start := Vector2(-157.0, AVENUE)
	var finish := Vector2(-92.0, AVENUE)
	var entry := _grid_height(start)
	var exit := _grid_height(finish)
	return Route.new("Rua do Mercado", 8.8, [
		[start, Vector2.ZERO, Vector2(0, 14)],
		[Vector2(-156, 88), Vector2(-2, -13), Vector2(3, 15)],
		[Vector2(-132, 113), Vector2(-16, -1), Vector2(15, 0)],
		[Vector2(-104, 100), Vector2(-11, 11), Vector2(8, -9)],
		[Vector2(-91, 75), Vector2(0, 11), Vector2(0, -10)],
		[finish, Vector2(0, 11), Vector2.ZERO],
	], PackedVector2Array([
		Vector2(0.0, entry), Vector2(0.16, entry - 0.93),
		Vector2(0.38, entry - 4.25), Vector2(0.54, entry - 4.85),
		Vector2(0.75, exit - 2.45), Vector2(0.88, exit - 0.44), Vector2(1.0, exit),
	]), -1.0, Vector2(6.5, 6.5))


static func market_cover_span(road: Route) -> Vector2:
	return Vector2(road.length * 0.43, road.length * 0.57)


static func market_paving(point: Vector2) -> bool:
	if not MERCADO_COVER.grow(7.0).has_point(point):
		return false
	var road := urban_routes()[MERCADO_ROUTE]
	var sample := road.project(point)
	var span := market_cover_span(road)
	return sample.x > span.x + 0.14 and sample.x < span.y - 0.14 and absf(sample.y) > 5.08 and absf(sample.y) < 10.22


static func rain_shelter(point: Vector2) -> float:
	if point.y > 386.0 and Baixada.BOUNDS.has_point(point):
		return Baixada.shelter(district_sample(point))
	if MERCADO_COVER.has_point(point):
		var road := urban_routes()[MERCADO_ROUTE]
		var sample := road.project(point)
		var span := market_cover_span(road)
		var inside := minf(sample.x - span.x, span.y - sample.x)
		return smoothstep(-0.9, 1.5, inside) * (1.0 - smoothstep(5.7, 7.9, sample.z))
	for index in range(GALERIA_ROUTE, ESTACAO_ROUTE + 1):
		if not CityLinks.BOUNDS[index - GALERIA_ROUTE].has_point(point):
			continue
		var sample := urban_routes()[index].project(point)
		var span := Vector2(22.0, 45.0) if index == GALERIA_ROUTE else Vector2(14.0, 38.0)
		var half_width := 6.8 if index == GALERIA_ROUTE else 6.5
		var inside := minf(sample.x - span.x, span.y - sample.x)
		return smoothstep(-0.65, 1.0, inside) * (1.0 - smoothstep(half_width - 0.85, half_width + 0.55, sample.z))
	return gallery_shadow(point)


static func _horto_route() -> Route:
	var start := Vector2(-194, -54)
	var finish := Vector2(-194, -176)
	var floor_y := _grid_height(start)
	var crest := _grid_height(finish)
	return Route.new("Estrada do Horto", 8.6, [
		[start, Vector2.ZERO, Vector2(-20, 0)],
		[Vector2(-245, -65), Vector2(19, 11), Vector2(-24, -14)],
		[Vector2(-306, -79), Vector2(22, -1), Vector2(-19, 2)],
		[Vector2(-330, -126), Vector2(-4, 24), Vector2(4, -23)],
		[Vector2(-296, -171), Vector2(-20, 12), Vector2(19, -11)],
		[Vector2(-246, -186), Vector2(-20, -1), Vector2(21, 1)],
		[finish, Vector2(-14, 0), Vector2.ZERO],
	], PackedVector2Array([
		Vector2(0.0, floor_y), Vector2(0.17, floor_y + 4.0),
		Vector2(0.38, floor_y + 13.6), Vector2(0.58, maxf(floor_y + 18.6, crest + 1.1)),
		Vector2(0.77, crest + 2.8), Vector2(1.0, crest),
	]), HORTO_PLAZA, Vector2(8.8, 8.8))


static func _urban_route(title: String, width: float, knots: Array) -> Route:
	# Sample the base hillside along the curve, then lay a continuous grade
	# through those elevations. The middle sags toward the gardens.
	var mouths := Vector2.ONE * (width * 0.5 + 3.5)
	var road := Route.new(title, width, knots, PackedVector2Array(), -1.0, mouths)
	var heights := PackedVector2Array()
	for index in 9:
		var fraction := float(index) / 8.0
		var site := road.point_at(road.length * fraction)
		heights.append(Vector2(fraction, _landscape_height(site) - 0.66 * pow(sin(fraction * PI), 2.0)))
	road.set_elevations(heights)
	return road


static func urban_sample(point: Vector2) -> Vector4:
	var best := Vector4(-1, 0, 0, INF)
	for index in ESTACAO_ROUTE + 1:
		var bounds: Rect2 = URBAN_BOUNDS[index] if index < URBAN_BOUNDS.size() else CityLinks.BOUNDS[index - URBAN_BOUNDS.size()]
		if not bounds.has_point(point):
			continue
		var sample := urban_routes()[index].project(point)
		if sample.z < best.w:
			best = Vector4(index, sample.x, sample.y, sample.z)
	return best


static func urban_edge(sample: Vector4) -> float:
	if sample.x < 0:
		return INF
	var route := urban_routes()[int(sample.x)]
	if int(sample.x) == HORTO_ROUTE:
		return minf(sample.w - route.edge_at(sample.y, sample.z), _horto_apron_edge(sample, route))
	return sample.w - route.edge_at(sample.y, sample.z)


static func _horto_apron_edge(sample: Vector4, road: Route) -> float:
	# The paved apron opens into the bend on both sides of the pavilion.
	var lengthwise := absf(sample.y - road.stop_station) - 27.0
	return maxf(lengthwise, maxf(-sample.z - 17.4, sample.z + 2.9))


static func horto_paving(point: Vector2) -> bool:
	return URBAN_BOUNDS[HORTO_ROUTE].has_point(point) and _horto_paving(urban_sample(point))


static func _horto_paving(sample: Vector4) -> bool:
	return int(sample.x) == HORTO_ROUTE and sample.z < -6.6 and _horto_apron_edge(sample, urban_routes()[HORTO_ROUTE]) < -0.30


static func scenic_routes() -> Array[Route]:
	if not _routes.is_empty():
		return _routes
	var zero := Vector2.ZERO
	var west := Vector2(COLUMNS[0], -173)
	var north_east := Vector2(COLUMNS[3], -173)
	var east := Vector2(210, AVENUE)
	var south_east := Vector2(210, ROWS[3])
	_routes = [
		Route.new("Estrada do Mirante", 10.8, [
			[west, zero, Vector2(0, -42)],
			[Vector2(-157, -277), Vector2(-37, 0), Vector2(49, 0)],
			[Vector2(-23, -264), Vector2(-46, -10), Vector2(37, 8)],
			[Vector2(117, -296), Vector2(-51, -1), Vector2(51, 1)],
			[Vector2(COLUMNS[3], -228), Vector2(0, -39), Vector2(0, 22)],
			[north_east, Vector2(0, -22), zero],
		], PackedVector2Array([Vector2(0, _grid_height(west)), Vector2(0.21, 67), Vector2(0.43, 73.5),
			Vector2(0.63, 65.4), Vector2(0.81, 53.9), Vector2(1, _grid_height(north_east))]), 0.43, Vector2(LOCAL_HALF, LOCAL_HALF)),
		Route.new("Contorno das Águas", 11.4, [
			[east, zero, Vector2(42, 0)],
			[Vector2(302, 63), Vector2(-33, -8), Vector2(29, 9)],
			[Vector2(340, 125), Vector2(0, -32), Vector2(0, 32)],
			[Vector2(300, 185), Vector2(27, -9), Vector2(-34, 11)],
			[south_east, Vector2(38, 0), zero],
		], PackedVector2Array([Vector2(0, _grid_height(east)), Vector2(0.26, 32.3), Vector2(0.54, 40.5),
			Vector2(0.74, 42.0), Vector2(0.87, 40.0), Vector2(1, _grid_height(south_east))]), 0.54, Vector2(AVENUE_HALF, LOCAL_HALF)),
		Route.new("Estrada do Vale", 10.6, [
			[Vector2(COLUMNS[0], 191), zero, Vector2(0, 36)],
			[Vector2(-174, 273), Vector2(-23, -13), Vector2(38, 22)],
			[Vector2(-82, 301), Vector2(-36, 0), Vector2(40, 0)],
			[Vector2(27, 287), Vector2(-37, 6), Vector2(42, -7)],
			[Vector2(139, 311), Vector2(-34, -8), Vector2(45, 11)],
			[Vector2(COLUMNS[3], 249), Vector2(0, 35), Vector2(0, -31)],
			[Vector2(COLUMNS[3], 191), Vector2(0, 22), zero],
		], PackedVector2Array([Vector2(0, _grid_height(Vector2(COLUMNS[0], 191))),
			Vector2(0.18, 29.4), Vector2(0.43, 18.3), Vector2(0.61, 22.4), Vector2(0.80, 33.5),
			Vector2(1, _grid_height(Vector2(COLUMNS[3], 191)))]), 0.64, Vector2(LOCAL_HALF, LOCAL_HALF)),
	]
	_routes.append(_passo_route(urban_routes()[HORTO_ROUTE], _routes[0]))
	var valley := _routes[2]
	_vale_crossing = valley.project(Vector2(creek_axis(294.0), 294.0)).x
	var nursery_station := valley.stop_station + 4.0
	var axis := valley.direction_at(nursery_station)
	_nursery_frame = Transform2D(axis, axis.orthogonal(), valley.offset_at(nursery_station, -24.0))
	_nursery_elevation = valley.height_at(nursery_station) + 0.84
	return _routes


static func district_routes() -> Array[Route]:
	return Baixada.routes(scenic_routes()[2])


static func district_sample(point: Vector2) -> Vector4:
	if not Baixada.BOUNDS.has_point(point):
		return Vector4(-1, 0, 0, INF)
	district_routes()
	return Baixada.sample(point)


static func district_bridges() -> Dictionary[Route, float]:
	district_routes()
	return Baixada.bridge_stations(creek_axis)


static func _passo_route(horto: Route, mirante: Route) -> Route:
	var entry := horto.point_at(PASSO_HORTO_STATION)
	var exit := mirante.point_at(PASSO_MIRANTE_STATION)
	# A narrow climbing fork leads from the nursery road to the saddle. Beyond
	# the crest the reverse curve slows the return to the faster Mirante road.
	return Route.new("Estrada do Passo", 8.8, [
		[entry, Vector2.ZERO, Vector2(-13, -17)],
		[Vector2(-373, -150), Vector2(16, 19), Vector2(-14, -17)],
		[Vector2(-397, -200), Vector2(0, 23), Vector2(0, -21)],
		[Vector2(-363, -246), Vector2(-26, 13), Vector2(22, -11)],
		[Vector2(-318, -245), Vector2(-16, -8), Vector2(16, 8)],
		[Vector2(-270, -226), Vector2(-19, 0), Vector2(15, 0)],
		[Vector2(-224, -243), Vector2(-12, 12), Vector2(11, -12)],
		[Vector2(-203, -271), Vector2(-7, 8), Vector2(9, -8)],
		[exit, Vector2(-10, -0.8), Vector2.ZERO],
	], PackedVector2Array([
		Vector2(0.0, horto.height_at(PASSO_HORTO_STATION)), Vector2(0.12, 64.3),
		Vector2(0.29, 74.4), Vector2(0.45, 85.5), Vector2(0.56, 87.6),
		Vector2(0.66, 85.4), Vector2(0.81, 75.2), Vector2(0.93, 66.8),
		Vector2(1.0, mirante.height_at(PASSO_MIRANTE_STATION)),
	]), 0.54, Vector2(6.7, 7.1))


static func passo_junction_near(route: Route, station: float, margin: float) -> bool:
	return (route == urban_routes()[HORTO_ROUTE] and absf(station - PASSO_HORTO_STATION) < margin
		or route == scenic_routes()[0] and absf(station - PASSO_MIRANTE_STATION) < margin)


static func passo_paving(point: Vector2) -> bool:
	return _passo_paving(_passo_sample(point))


static func _passo_paving(sample: Vector4) -> bool:
	if sample.x < 0:
		return false
	var route := scenic_routes()[PASSO_ROUTE]
	if absf(sample.y - route.stop_station) > 18.0:
		return false
	var edge := route.edge_at(sample.y, -1.0)
	return sample.z <= -edge + 5.30 and sample.z >= -edge + 0.26


static func scenic_sample(point: Vector2) -> Vector4:
	return _closer_scenic(_main_scenic_sample(point), _passo_sample(point))


static func _main_scenic_sample(point: Vector2) -> Vector4:
	if point.x > -239 and point.x < 165.0 and point.y > -128.0 and point.y < 147.0:
		return Vector4(-1, 0, 0, INF)
	var routes := scenic_routes()
	var best := Vector4(-1, 0, 0, INF)
	for index in PASSO_ROUTE:
		if not SCENIC_BOUNDS[index].has_point(point):
			continue
		var sample := routes[index].project(point)
		if sample.z < best.w:
			best = Vector4(index, sample.x, sample.y, sample.z)
	return best


static func _passo_sample(point: Vector2) -> Vector4:
	if not SCENIC_BOUNDS[PASSO_ROUTE].has_point(point):
		return Vector4(-1, 0, 0, INF)
	var sample := scenic_routes()[PASSO_ROUTE].project(point)
	return Vector4(PASSO_ROUTE, sample.x, sample.y, sample.z) if is_finite(sample.z) else Vector4(-1, 0, 0, INF)


static func passo_cut_mask(point: Vector2) -> float:
	var edge := scenic_edge(_passo_sample(point))
	return smoothstep(1.9, 5.5, edge) * (1.0 - smoothstep(10.0, 24.0, edge))


static func _closer_scenic(main: Vector4, passo: Vector4) -> Vector4:
	return passo if scenic_edge(passo) < scenic_edge(main) else main


static func scenic_edge(sample: Vector4) -> float:
	return sample.w - scenic_routes()[int(sample.x)].edge_at(sample.y, sample.z) if sample.x >= 0 else INF


static func walk_width(z: float) -> float:
	return AVENUE_WALK if z == AVENUE else WALK_WIDTH


static func road_distance(point: Vector2) -> float:
	return _road_distance(point, urban_sample(point), scenic_sample(point), Baixada.edge(district_sample(point)))


static func _road_distance(point: Vector2, urban: Vector4, scenic: Vector4, district_edge: float) -> float:
	var edge := minf(minf(_grid_distance(point), urban_edge(urban)), scenic_edge(scenic))
	if is_depot(point):
		edge = minf(edge, -0.3)
	return minf(edge, district_edge)

static func is_depot(point: Vector2) -> bool:
	return DEPOT.has_point(point) or (point.y > -174.0 and point.y < -55.0 and absf(point.x - DEPOT_AXIS) < 4.8)


static func _grid_distance(point: Vector2) -> float:
	var x := _nearest_street(point.x, COLUMNS)
	var z := _nearest_street(point.y, ROWS)
	var dx := absf(point.x - COLUMNS[x]) - float(COLUMN_HALF_WIDTHS[x])
	var dz := absf(point.y - ROWS[z]) - float(ROW_HALF_WIDTHS[z])
	return maxf(_corner_distance(dx, dz, junction_radius(x, z)), _outside_streets(point))


static func junction_radius(column: int, row: int) -> float:
	if ROWS[row] == AVENUE:
		return 10.5 if COLUMNS[column] == COLLECTOR else 7.0
	return 5.8 if COLUMNS[column] == COLLECTOR else 3.6


static func _corner_distance(dx: float, dz: float, radius: float) -> float:
	# A quarter circle rounds the inside of each parcel where two roads meet.
	if dx >= radius or dz >= radius:
		return minf(dx, dz)
	return radius - Vector2(radius - dx, radius - dz).length()


static func road_finish(point: Vector2) -> Color:
	var x := _nearest_street(point.x, COLUMNS)
	var z := _nearest_street(point.y, ROWS)
	var across_x := absf(point.x - COLUMNS[x])
	var across_z := absf(point.y - ROWS[z])
	var dx := across_x - float(COLUMN_HALF_WIDTHS[x])
	var dz := across_z - float(ROW_HALF_WIDTHS[z])
	var edge := maxf(_corner_distance(dx, dz, junction_radius(x, z)), _outside_streets(point))
	var lane_center := COLLECTOR_HALF * 0.5 if dx < dz and COLUMNS[x] == COLLECTOR else LOCAL_HALF * 0.5
	var lane := (across_x if dx < dz else across_z) - lane_center
	var straight := smoothstep(1.0, 11.0, maxf(dx, dz))
	var avenue := 1.0 if dx >= dz and ROWS[z] == AVENUE else 0.0
	if avenue > 0.0:
		lane = across_z
	var link := urban_sample(point)
	var link_edge := urban_edge(link)
	if link_edge < edge:
		var street := urban_routes()[int(link.x)]
		edge = link_edge
		lane = absf(link.z) - street.half_width * 0.5
		straight = smoothstep(8.0, 16.0, minf(link.y, street.length - link.y))
		avenue = 0.0
	var route := scenic_sample(point)
	var margin := scenic_edge(route)
	var district := district_sample(point)
	var district_edge := Baixada.edge(district)
	if district_edge < minf(edge, margin):
		var street := district_routes()[int(district.x)]
		return Color(clampf(-district_edge / 3.0, 0.0, 1.0), clampf((absf(district.z) - street.half_width * 0.5 + 4.0) / 16.0, 0.0, 1.0), 1.0, 0.0)
	if margin < edge:
		edge = margin
		lane = absf(route.z) - scenic_routes()[int(route.x)].half_width * 0.5
		straight = 1.0
		avenue = 0.0
	return Color(clampf(-edge / 3.0, 0.0, 1.0), clampf((lane + 4.0) / 16.0, 0.0, 1.0), straight, avenue)


static func ground_band(point: Vector2) -> float:
	return _ground_band(point, road_distance(point))


static func driving_surface(point: Vector2, wet: bool) -> Dictionary:
	# Reuse the route projections for paving, grip and shelter at each tire.
	var district := district_sample(point)
	var district_shelter := point.y > 386.0 and Baixada.BOUNDS.has_point(point)
	if district_shelter and Baixada.loading_surface(district):
		return LOADING_CONCRETE
	var urban := urban_sample(point)
	var passo := _passo_sample(point)
	if _horto_paving(urban) or _passo_paving(passo) or CityLinks.ESTACAO_LOADING_APRON.has_point(point) \
		or (is_depot(point) and absf(point.x - DEPOT_AXIS) >= 4.65):
		return COBBLE_SURFACE
	if market_paving(point):
		return SHELTERED_COBBLES if wet and rain_shelter(point) >= 0.74 else COBBLE_SURFACE
	var scenic := _closer_scenic(_main_scenic_sample(point), passo)
	var district_edge := Baixada.edge(district)
	var band := _ground_band(point, _road_distance(point, urban, scenic, district_edge))
	if band <= 0.12:
		if wet:
			var shelter := Baixada.shelter(district) if district_shelter else rain_shelter(point)
			if shelter >= 0.74:
				return SHELTERED_ASPHALT
		return {}
	if band <= WALK_WIDTH + 0.50:
		return WALK_SURFACE if STREET_BOUNDS.grow(3.0).has_point(point) or district_edge < WALK_WIDTH else SHOULDER_SURFACE
	return GRASS_SURFACE


static func _ground_band(point: Vector2, distance: float) -> float:
	if distance <= CURB_WIDTH:
		return distance
	var commercial := 1.0 - smoothstep(AVENUE_HALF + AVENUE_WALK, AVENUE_HALF + AVENUE_WALK + 4.0, absf(point.y - AVENUE))
	return CURB_WIDTH + (distance - CURB_WIDTH) * (WALK_WIDTH - CURB_WIDTH) / (lerpf(WALK_WIDTH, AVENUE_WALK, commercial) - CURB_WIDTH)


static func lake_outline(angle: float) -> Vector2:
	return Vector2.from_angle(angle) * LAKE_RADII * _lake_inlet(angle)


static func lake_distance(point: Vector2) -> float:
	var offset := (point - LAKE) / LAKE_RADII
	var distance := offset.length()
	return distance / _lake_inlet(offset.angle()) if distance < 1.75 else distance


static func _lake_inlet(angle: float) -> float:
	return 1.0 + 0.103 * sin(angle * 3.0 + 0.24) + 0.059 * sin(angle * 5.0 + 0.79)


static func creek_axis(z: float) -> float:
	return -40.0 + sin(z * 0.031) * 9.0 + sin(z * 0.065) * 3.4


static func creek_width(z: float) -> float:
	return 5.3 + sin(z * 0.18) * 1.35 + sin(z * 0.041) * 0.68


static func creek_weight(point: Vector2) -> float:
	if point.y <= CREEK_RANGE.x or point.y >= CREEK_RANGE.y:
		return 0.0
	var opening := smoothstep(CREEK_RANGE.x, CREEK_RANGE.x + 33.0, point.y)
	opening *= 1.0 - smoothstep(CREEK_RANGE.y - 35.0, CREEK_RANGE.y, point.y)
	return opening * (1.0 - smoothstep(4.5, 25.0, absf(point.x - creek_axis(point.y))))


static func gallery_shadow(point: Vector2) -> float:
	if point.y > -235.0 or point.x < 10.0 or point.x > 180.0:
		return 0.0
	var sample := scenic_routes()[0].project(point)
	if sample.z > 7.5:
		return 0.0
	return smoothstep(GALLERY_START - 0.8, GALLERY_START + 4.0, sample.x) * (1.0 - smoothstep(GALLERY_END - 4.0, GALLERY_END + 0.8, sample.x))


static func nursery_frame() -> Transform2D:
	scenic_routes()
	return _nursery_frame


static func nursery_terrace(point: Vector2) -> Vector2:
	if point.x < 68.0 or point.x > 122.0 or point.y < 297.0 or point.y > 349.0:
		return Vector2.ZERO
	var frame := nursery_frame()
	var offset := point - frame.origin
	var spread := 1.0 - smoothstep(6.95, 15.2, absf(offset.dot(frame.x)))
	var depth := offset.dot(frame.y)
	var cut := smoothstep(-14.0, -5.5, depth) * (1.0 - smoothstep(8.5, 11.5, depth))
	return Vector2(_nursery_elevation - depth * 0.047, spread * cut)


static func height_at(point: Vector2) -> float:
	return _height_from_roads(point, urban_sample(point), _main_scenic_sample(point), _passo_sample(point), district_sample(point))


static func ground_sample(point: Vector2) -> Vector2:
	var urban := urban_sample(point)
	var main := _main_scenic_sample(point)
	var passo := _passo_sample(point)
	var district := district_sample(point)
	var distance := minf(Baixada.edge(district), minf(_grid_distance(point), minf(urban_edge(urban), minf(scenic_edge(main), scenic_edge(passo)))))
	if is_depot(point):
		distance = minf(distance, -0.3)
	var height := _height_from_roads(point, urban, main, passo, district)
	var lowering := _bridge_opening(point, main)
	if district.x >= 0.0:
		lowering = maxf(lowering, Baixada.bridge_opening(district, creek_weight(point), creek_axis))
	if lowering > 0.0:
		var bed := CREEK_WATER_LEVEL - 0.83 + pow(absf(point.x - creek_axis(point.y)) / creek_width(point.y), 1.32)
		height = lerpf(height, minf(height, bed), lowering)
		distance = lerpf(distance, maxf(distance, WALK_WIDTH + 0.8), smoothstep(0.0, 0.38, lowering))
	return Vector2(height, _ground_band(point, distance))


static func vale_bridge_station() -> float:
	scenic_routes()
	return _vale_crossing


static func bridge_opening(point: Vector2) -> float:
	if point.y > 386.0 and Baixada.BOUNDS.has_point(point):
		return Baixada.bridge_opening(district_sample(point), creek_weight(point), creek_axis)
	if not VALE_BRIDGE_BOUNDS.has_point(point):
		return 0.0
	return _bridge_opening(point, _main_scenic_sample(point))


static func _bridge_opening(point: Vector2, road: Vector4) -> float:
	if int(road.x) != 2 or not VALE_BRIDGE_BOUNDS.has_point(point):
		return 0.0
	var lengthwise := 1.0 - smoothstep(6.8, VALE_BRIDGE_HALF_SPAN, absf(road.y - _vale_crossing))
	var transverse := maxf(creek_weight(point), 1.0 - smoothstep(6.25, 14.5, absf(road.z)))
	return lengthwise * transverse


static func _height_from_roads(point: Vector2, link: Vector4, sample: Vector4, passo: Vector4, district: Vector4) -> float:
	var height := _grid_height(point)
	if point.y > 321.0:
		height = Baixada.floodplain_height(point, height)
	var route_index := int(link.x)
	var limit := 37.0 if route_index == HORTO_ROUTE else (24.0 if route_index == MERCADO_ROUTE else 16.0)
	if route_index >= 0 and link.w < limit:
		var street := urban_routes()[route_index]
		var edge := urban_edge(link)
		var approach := smoothstep(1.0, 13.0, minf(link.y, street.length - link.y))
		var shelf := WALK_WIDTH
		var margin := 17.0 if route_index == HORTO_ROUTE else 9.0
		if route_index == MERCADO_ROUTE:
			var yard := smoothstep(12.0, 43.0, minf(link.y, street.length - link.y))
			shelf = lerpf(WALK_WIDTH, 5.25, yard)
			margin = lerpf(10.0, 16.3, yard)
		var blend := (1.0 - smoothstep(shelf, margin, edge)) * approach
		var crossfall := 0.016 * minf(absf(link.z), street.half_width)
		if route_index == HORTO_ROUTE:
			crossfall += (0.032 - street.bank_at(link.y) * 0.68) * clampf(link.z, -21.0, street.half_width)
		var curb := clampf(minf(edge, _grid_distance(point)) / CURB_WIDTH, 0.0, 1.0) * lerpf(0.040, 0.145, approach)
		height = lerpf(height, street.height_at(link.y) - crossfall + curb, blend)
	var creek := creek_weight(point)
	if creek > 0.0:
		var bed := CREEK_WATER_LEVEL - 0.83 + pow(absf(point.x - creek_axis(point.y)) / creek_width(point.y), 1.32)
		height = lerpf(height, bed, creek)
	if sample.x >= 0 and sample.w < 40.0:
		var route := scenic_routes()[int(sample.x)]
		var edge := sample.w - route.edge_at(sample.y, sample.z)
		var run_in := smoothstep(4.0, 36.0, minf(sample.y, route.length - sample.y))
		var slope_margin := lerpf(Route.GRADE_MARGIN, 13.0, creek)
		var fit := (1.0 - smoothstep(2.4, slope_margin, edge)) * run_in
		var gutter := 0.11 * clampf(edge / CURB_WIDTH, 0.0, 1.0)
		height = lerpf(height, scenic_surface_height(route, sample.y, sample.z) + gutter, fit)
	if passo.x >= 0 and passo.w < 37.0:
		var route := scenic_routes()[PASSO_ROUTE]
		var edge := scenic_edge(passo)
		var road_height := scenic_surface_height(route, passo.y, passo.z)
		var trunk_edge := minf(urban_edge(link), scenic_edge(sample))
		var priority := smoothstep(-0.4, 2.8, trunk_edge)
		var formed := _passo_formation(height, road_height, edge)
		# Shallow gullies run down the cut. The ditch and first shoulder use
		# the road profile all the way through the hairpin.
		var bank := smoothstep(0.6, 2.2, formed - road_height)
		var gullies := absf(sin(passo.y * 0.31 + edge * 0.13 + cos(passo.y * 0.12)))
		var erosion := (1.0 - smoothstep(0.04, 0.56, gullies)) * bank
		formed -= erosion * 0.31 * smoothstep(3.8, 6.9, edge) * (1.0 - smoothstep(14.0, 24.0, edge))
		height = lerpf(height, formed, priority)
	var basin := lake_distance(point)
	if basin < 1.48:
		var shore := LAKE_LEVEL + (basin - 0.93) * 5.5
		height = lerpf(shore, height, smoothstep(1.06, 1.48, basin))
	if district.x >= 0.0:
		height = Baixada.form_road(height, district, scenic_edge(sample))
	var terrace := nursery_terrace(point)
	return lerpf(height, terrace.x, terrace.y)


static func scenic_surface_height(route: Route, station: float, lateral: float) -> float:
	var bank := route.bank_at(station)
	var road_width := clampf(lateral, -route.half_width, route.half_width)
	var crown := 0.021 * (1.0 - smoothstep(0.017, 0.052, absf(bank)))
	return route.height_at(station) + road_width * bank - absf(road_width) * crown


static func _passo_formation(ground: float, road: float, edge: float) -> float:
	if edge <= 0.0:
		return road
	# The cut has two benches with an intercepting drain at its foot. The
	# outside of the road instead follows a longer fill slope down the valley.
	var toe := road - 0.31 * smoothstep(0.7, 2.4, edge)
	var difference := ground - toe
	if difference < 0.0:
		return lerpf(toe, ground, smoothstep(2.3, 18.0, edge))
	var first_bank := minf(difference, 3.9) * smoothstep(2.3, 6.5, edge)
	var second_bank := minf(maxf(difference - 3.9, 0.0), 5.0) * smoothstep(8.1, 13.7, edge)
	var crest := maxf(difference - 8.9, 0.0) * smoothstep(15.8, 28.5, edge)
	return toe + first_bank + second_bank + crest


static func _grid_height(point: Vector2) -> float:
	var x_index := _nearest_street(point.x, COLUMNS)
	var z_index := _nearest_street(point.y, ROWS)
	var x_offset := absf(point.x - COLUMNS[x_index])
	var z_offset := absf(point.y - ROWS[z_index])
	var dx := x_offset - float(COLUMN_HALF_WIDTHS[x_index])
	var dz := z_offset - float(ROW_HALF_WIDTHS[z_index])
	var radius := junction_radius(x_index, z_index)
	var outside := _outside_streets(point)
	var limit := 1.0 - smoothstep(0.0, 21.0, outside)
	var x_blend := (1.0 - smoothstep(0.0, 17.0, dx)) * smoothstep(0.0, radius + 8.0, dz) * limit
	var z_blend := (1.0 - smoothstep(0.0, 17.0, dz)) * smoothstep(0.0, radius + 8.0, dx) * limit
	var grade_point := point.lerp(Vector2(COLUMNS[x_index], point.y), x_blend * 0.79)
	grade_point = grade_point.lerp(Vector2(grade_point.x, ROWS[z_index]), z_blend * 0.88)
	var distance := maxf(_corner_distance(dx, dz, radius), outside)
	var crown := 0.013 * (maxf(-dx, 0.0) * x_blend + maxf(-dz, 0.0) * z_blend)
	var crossing := lerpf(0.036, 0.145, smoothstep(radius + 2.5, radius + 6.1, maxf(dx, dz)))
	var curb := clampf(distance / CURB_WIDTH, 0.0, 1.0) * crossing
	if is_depot(point):
		var mouth := (1.0 - smoothstep(2.9, 5.2, absf(point.x - DEPOT_AXIS))) * (1.0 - smoothstep(4.0, 12.0, z_offset))
		curb *= 1.0 - mouth
	return _landscape_height(grade_point) + curb + crown


static func _nearest_street(coordinate: float, streets: Array) -> int:
	var nearest := 0
	for index in range(1, streets.size()):
		if absf(coordinate - streets[index]) < absf(coordinate - streets[nearest]):
			nearest = index
	return nearest


static func _outside_streets(point: Vector2) -> float:
	var outside := (point - STREET_BOUNDS.get_center()).abs() - STREET_BOUNDS.size * 0.5
	return maxf(outside.x, outside.y)


static func _landscape_height(point: Vector2) -> float:
	# The avenue's vertical alignment controls the valley floor. The hills rise
	# from it with a vertical curve, so the streets have no abrupt grade changes.
	var valley := 23.0 - 0.016 * point.x + 5.4 * exp(-pow((point.x + 163.0) / 84.0, 2))
	valley += -3.5 * exp(-pow((point.x - 30.0) / 93.0, 2)) + 8.3 * exp(-pow((point.x - 219.0) / 80.0, 2))
	var north := maxf(0.0, AVENUE - point.y)
	var south := maxf(0.0, point.y - AVENUE)
	var west := 1.0 - smoothstep(-208.0, 98.0, point.x)
	var east := smoothstep(-154.0, 216.0, point.x)
	var west_slope := (sqrt(north * north + 28.0 * 28.0) - 28.0) * lerpf(0.069, 0.133, west)
	var east_slope := (sqrt(south * south + 31.0 * 31.0) - 31.0) * lerpf(0.027, 0.076, east)
	var shoulder := 1.22 * sin(point.x / 51.0 + point.y / 54.0) * smoothstep(12.0, 92.0, absf(point.y - AVENUE))
	var outside := _outside_streets(point)
	# The Mirante follows the inside of the northern ridge. Shorter, offset
	# spurs fold into that ridge and leave the Horto in a catchment below it.
	var north_axis := point.y + 320.0 + 28.0 * sin((point.x - 17.0) * 0.011) + point.x * 0.073
	var north_width := 81.0 + 15.0 * cos(point.x * 0.013)
	var north_ridge := (40.0 + 11.0 * cos(point.x * 0.009 + 1.1)) * exp(-pow(north_axis / north_width, 2.0))
	var west_crest := _ridge(point - Vector2(-377, -198), Vector2(0.26, 0.97), Vector2(152, 54), 24.0)
	var east_crest := _ridge(point - Vector2(406, -112), Vector2(0.38, 0.925), Vector2(192, 68), 58.0)
	var south_crest := _ridge(point - Vector2(260, 392), Vector2(0.92, -0.39), Vector2(230, 68), 43.0)
	var west_draw := _ridge(point - Vector2(-374, -39), Vector2(0.88, 0.47), Vector2(120, 33), 9.5)
	var valley_draw := _ridge(point - Vector2(-63, 350), Vector2(0.94, 0.34), Vector2(162, 42), 8.0)
	var spurs := sin(point.x * 0.025 + point.y * 0.037 + 0.57 * sin(point.y * 0.021)) * 2.3
	spurs += sin(point.x * 0.047 - point.y * 0.063) * 0.74
	var hills := north_ridge + west_crest + east_crest + south_crest - west_draw - valley_draw
	# The saddles open onto two catchments. Narrow tributaries cut into the
	# spur faces, above the authored creek and below the rim of the plateau.
	var saddle := _ridge(point - Vector2(-127, -360), Vector2(0.82, -0.57), Vector2(89, 31), 12.0)
	var tributary := _ridge(point - Vector2(-362, -15), Vector2(0.63, -0.78), Vector2(112, 22), 9.0)
	tributary += _ridge(point - Vector2(350, 253), Vector2(0.56, 0.83), Vector2(109, 29), 13.0)
	var folds := (hills - saddle - tributary) * smoothstep(12.0, 115.0, outside)
	return valley + west_slope + east_slope + shoulder + folds + spurs * smoothstep(28.0, 89.0, outside)


static func _ridge(offset: Vector2, axis: Vector2, radii: Vector2, height: float) -> float:
	var shape := Vector2(offset.dot(axis), offset.dot(axis.orthogonal())) / radii
	return height * exp(-shape.length_squared())


static func horizon_height(point: Vector2) -> float:
	var north_axis := point.y + 705.0 + 86.0 * sin(point.x * 0.0047) - point.x * 0.18
	var north := 134.0 * exp(-pow(north_axis / 208.0, 2.0)) * (0.88 + 0.12 * sin(point.x * 0.009))
	var east := _ridge(point - Vector2(916.0, -64.0), Vector2(0.34, 0.94), Vector2(564.0, 132.0), 154.0)
	var southwest := _ridge(point - Vector2(-680.0, 640.0), Vector2(0.85, -0.53), Vector2(526.0, 115.0), 101.0)
	var south := _ridge(point - Vector2(252.0, 953.0), Vector2(0.93, -0.37), Vector2(680.0, 156.0), 81.0)
	var rear := _ridge(point - Vector2(-430.0, -1330.0), Vector2(0.89, 0.45), Vector2(870.0, 245.0), 215.0)
	rear += _ridge(point - Vector2(1340.0, 910.0), Vector2(0.68, -0.73), Vector2(780.0, 224.0), 173.0)
	var ravine := _ridge(point - Vector2(745.0, -462.0), Vector2(0.73, 0.68), Vector2(300.0, 56.0), 41.0)
	var crest := north + east + southwest + south + rear
	var folds := sin(point.x * 0.019 + point.y * 0.013 + 1.2 * sin(point.y * 0.008))
	folds += 0.45 * sin(point.x * 0.034 - point.y * 0.021)
	return 25.0 + crest - ravine + crest * 0.054 * folds


static func canopy_cover(point: Vector2) -> float:
	# Forest follows long landforms. The open valley floor, roads and a few
	# areas on the dry western side expose grass and dark red soil.
	var channels := sin(point.x * 0.020 + point.y * 0.015 + 1.35 * sin(point.y * 0.010))
	var pasture := sin(point.x * 0.037 - point.y * 0.026 + sin(point.x * 0.009))
	var boundary := sin(point.x * 0.092 + point.y * 0.077) * cos(point.y * 0.106 - point.x * 0.028)
	var ridge_cover := smoothstep(205.0, 350.0, -point.y) * 0.36 + smoothstep(325.0, 443.0, point.x) * 0.28
	var cover := 0.31 + ridge_cover + channels * 0.25 + pasture * 0.17 + boundary * 0.073
	return clampf(cover + creek_weight(point) * 0.47, 0.0, 1.0)


static func surface_point(point: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(point.x, height_at(point) + lift, point.y)


static func spawn() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), surface_point(SPAWN, 0.39))


static func block(column: int, row: int) -> Rect2:
	var left: float = COLUMNS[column] + COLUMN_HALF_WIDTHS[column] + WALK_WIDTH
	var top: float = ROWS[row] + ROW_HALF_WIDTHS[row] + walk_width(ROWS[row])
	var right: float = COLUMNS[column + 1] - COLUMN_HALF_WIDTHS[column + 1] - WALK_WIDTH
	var bottom: float = ROWS[row + 1] - ROW_HALF_WIDTHS[row + 1] - walk_width(ROWS[row + 1])
	return Rect2(left, top, right - left, bottom - top)
