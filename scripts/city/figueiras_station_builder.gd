extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Connections = preload("res://scripts/city/figueiras_urban_connections.gd")
const Parts = preload("res://scripts/city/figueiras_building_parts.gd")
const Openings = preload("res://scripts/city/figueiras_openings.gd")
const PROPERTY := Rect2(110.0, 91.0, 93.0, 96.0)
const PLATFORM := Vector2(14.0, 38.0)
const SHED_SHIFT := 0.09

var _city: RefCounted
var _ground: RefCounted


func build(city: RefCounted, ground: RefCounted) -> void:
	_city = city
	_ground = ground
	var route := Layout.urban_routes()[Layout.ESTACAO_ROUTE]
	_ground.patch(Connections.ESTACAO_LOADING_APRON, "cobbles", 0.036)
	_ground.patch(Rect2(140.0, 140.5, 7.4, 38.0), "paving", 0.038)
	_ground.patch(Rect2(128.5, 100.0, 38.5, 12.4), "asphalt_repair", 0.031)
	install_approach_lamp(_city)
	_platform(route)
	_station(Vector2(132.9, 159.7))
	_freight_hall(Vector2(181.2, 155.8))
	_waterworks(Vector2(189.0, 103.0))
	_siding(route)
	_loading_marks()
	for site: Vector2 in [Vector2(143, 106), Vector2(160, 106), Vector2(139, 136), Vector2(168, 181), Vector2(198, 168)]:
		_city._tree(site, 5.3 + fposmod(site.x, 3.5), 1, true)
		_city._garden(site, 1.75, 8)
	for side: Vector2 in [Vector2(147.0, 177.0), Vector2(164.9, 142.6), Vector2(194.1, 139.0)]:
		_city._lamp(side, Vector2.LEFT)
	_city.scene_root.set_meta("station_passage_length", route.length)
	_city.scene_root.set_meta("station_canopy_span", PLATFORM)


static func install_approach_lamp(city: RefCounted) -> void:
	var junction := Layout.urban_routes()[Layout.ESTACAO_ROUTE].point_at(0.0)
	var verge: float = Layout.COLUMN_HALF_WIDTHS[-1] + 0.66
	city._lamp(junction + Vector2(verge, -10.0), Vector2.LEFT)


func _platform(route: RefCounted) -> void:
	# A simple canopy of constant roof pitch follows the original platform.
	# Its rectangular collision stays above the entire sloping road.
	var station := (PLATFORM.x + PLATFORM.y) * 0.5
	var site: Vector2 = route.point_at(station)
	var direction: Vector2 = route.direction_at(station)
	var yaw := atan2(direction.x, direction.y)
	var frame := Basis(Vector3.UP, yaw)
	var roof_y := -INF
	for meter: float in [PLATFORM.x, station, PLATFORM.y]:
		for lateral: float in [-5.8, 5.8]:
			roof_y = maxf(roof_y, _ground.surface_point(route.offset_at(meter, lateral)).y)
	roof_y += 5.04
	var canopy := Vector3(site.x, roof_y, site.y)
	var depth := PLATFORM.y - PLATFORM.x
	_city.add_collision(canopy + Vector3.UP * 0.28, Vector3(18.2, 0.55, depth), yaw)
	var ridge := canopy + Vector3.UP * 1.73
	_city.add_part(ridge, Vector3(0, 0.05, 0), Vector3(0.24, 0.17, depth + 1.46), "roof_gray", yaw)
	for x: float in [-9.02, 9.02]:
		var eave := canopy + frame.x * (x * 1.065) + Vector3.UP * 0.46
		var across := (eave - ridge).normalized() * signf(x)
		var slope := Basis(across, frame.z.cross(across).normalized(), frame.z)
		_city._add_tilted_box((eave + ridge) * 0.5, slope, Vector3(eave.distance_to(ridge), 0.16, depth + 1.36), "roof_gray", false)
		_city.add_part(canopy, Vector3(x, 0.28, 0), Vector3(0.19, 0.30, depth + 0.90), "metal", yaw)
		for purlin: float in [0.31, 0.63]:
			var purlin_position := eave.lerp(ridge, purlin) - Vector3.UP * 0.13
			_city.add_part(purlin_position, Vector3.ZERO, Vector3(0.115, 0.18, depth + 1.1), "wood", yaw)
		for z: float in [-10.6, -3.5, 3.5, 10.6]:
			var section := station + z
			var side := signf(x)
			var shoulder: Vector2 = route.offset_at(section, side * (route.edge_at(section, side) + 1.04))
			var top := Vector3(shoulder.x, canopy.y + 0.12, shoulder.y)
			var base: Vector3 = _ground.surface_point(shoulder, -0.22)
			_city.add_box(base.lerp(top, 0.5), Vector3(0.39, top.y - base.y, 0.42), "metal", true, yaw)
			_city.add_box(base + Vector3.UP * 0.46, Vector3(0.80, 0.96, 0.82), "brick", true, yaw)
			Parts.beam(_city, top - Vector3.UP * 1.03, top - frame.x * signf(x) * 1.26, 0.12, 0.16, "metal")
			_city.add_part(canopy, Vector3(x * 0.48, 0.005, z), Vector3(0.18, 0.17, 1.12), "light", yaw)
			if x < 0.0:
				var truss := canopy + frame.z * z
				_platform_truss(truss, frame, yaw)
	for depth_offset: float in [-7.0, 0.0, 7.0]:
		_city._lamp_marker(canopy + frame * Vector3(0, -0.22, depth_offset))
	for side: float in [-1.0, 1.0]:
		var face := canopy + frame * Vector3(0, 0.53, side * (depth * 0.5 + 0.56))
		_city.add_box(face - frame.z * (side * 0.09), Vector3(18.8, 0.15, 0.16), "metal", false, yaw)
		_city.add_box(face, Vector3(4.18, 0.42, 0.085), "awning_green", false, yaw)
		Openings.lettering(_city, "PÁTIO DA ESTAÇÃO", face + frame.z * side * 0.05, yaw if side > 0 else yaw + PI,
			3.62, 0.32, Color("ebddbe"))
	var marker := Marker3D.new()
	marker.name = "PatioDaEstacao"
	marker.position = _ground.surface_point(site)
	_city.scene_root.add_child(marker)


func _platform_truss(center: Vector3, frame: Basis, yaw: float) -> void:
	var tie := center + Vector3.UP * 0.16
	_city.add_part(tie, Vector3.ZERO, Vector3(18.40, 0.17, 0.21), "steel_plate", yaw)
	var ridge := center + Vector3.UP * 1.61
	Parts.beam(_city, tie, ridge, 0.09, 0.15, "metal")
	for side: float in [-1.0, 1.0]:
		var outer := frame.x * side
		Parts.beam(_city, tie + outer * 9.35, ridge, 0.14, 0.17, "metal")
		Parts.beam(_city, tie + outer * 4.72, ridge - Vector3.UP * 0.065, 0.080, 0.12, "metal")


func _station(site: Vector2) -> void:
	const YAW := PI * 0.5
	var base := _station_wing(site, Vector3(15.8, 4.7, 10.1), "sage", 4)
	_station_wing(site + Vector2(-0.85, -12.65), Vector3(10.0, 3.64, 8.42), "cream", 3)
	_station_wing(site + Vector2(-1.23, 12.8), Vector3(10.3, 4.04, 8.83), "terracotta", 3)
	_city.add_part(base, Vector3(-3.12, 6.51, -1.42), Vector3(6.96, 2.33, 5.64), "cream", YAW)
	_city.add_part(base, Vector3(-3.12, 8.42, -1.42), Vector3(7.63, 1.55, 6.10), "roof_gray", YAW, false, "hip_roof")
	var label := base + Basis(Vector3.UP, YAW) * Vector3(0, 3.67, 5.13)
	Openings.lettering(_city, "ESTAÇÃO FIGUEIRAS", label, YAW, 4.28, 0.34, Color("3d4336"))


func _station_wing(site: Vector2, size: Vector3, wall: String, bays: int) -> Vector3:
	const YAW := PI * 0.5
	var base := Parts.masonry_mass(_city, _ground, site, size, YAW, wall)
	var face := size.z * 0.5
	var roof_height := size.y + 0.68
	_city.add_part(base, Vector3(0, roof_height, 0), Vector3(size.x + 0.98, 1.48, size.z + 0.87), "roof", YAW, false, "hip_roof")
	_city.add_part(base, Vector3(0, -0.15, face + 1.49), Vector3(size.x + 0.20, 0.58, 3.18), "stone", YAW, true)
	_city.add_part(base, Vector3(0, 3.12, face + 1.49), Vector3(size.x + 0.54, 0.31, 3.46), "ceramic", YAW)
	var band := size.x - 0.86
	for index in bays + 1:
		var x := (float(index) / bays - 0.5) * band
		_city.add_part(base, Vector3(x, 1.48, face + 2.89), Vector3(0.22, 2.92, 0.25), "wood", YAW)
		_city.add_part(base, Vector3(x, 0.27, face + 2.89), Vector3(0.37, 0.43, 0.42), "brick", YAW)
		if index == bays:
			continue
		var opening := x + 0.5 * band / bays
		if index == 0:
			_city.add_part(base, Vector3(opening, 1.37, face + 0.06), Vector3(1.12, 2.74, 0.20), "door", YAW)
		else:
			_city._window(base, Vector3(opening, 1.75, face + 0.03), Vector2(1.27, 1.72), YAW, "residential_glass_lit", "timber")
	_city.add_part(base, Vector3(0, size.y - 0.24, face + 0.04), Vector3(size.x + 0.10, 0.18, 0.38), "trim", YAW)
	var landing := site + Vector2(face + 3.04, band * (0.5 - 0.5 / bays))
	_city._access(landing + Vector2(2.9, 0), landing, base.y + 0.12, YAW, 2.74)
	_city._lots += 1
	return base


func _freight_hall(site: Vector2) -> void:
	const YAW := -PI * 0.5
	var base := Parts.masonry_mass(_city, _ground, site, Vector3(42.8, 6.2, 20.2), YAW, "brick")
	var frame := Basis(Vector3.UP, YAW)
	var roof_size := Vector3(8.72, 2.42, 21.36)
	var short_pitch := Vector2(roof_size.x * SHED_SHIFT, roof_size.y)
	var slope := frame * Basis(Vector3.BACK, short_pitch.angle())
	_city.add_part(base, Vector3(0, 0.54, 10.18), Vector3(42.85, 1.08, 0.22), "parapet", YAW)
	_city.add_part(base, Vector3(0, 5.89, 10.24), Vector3(43.1, 0.23, 0.48), "steel_plate", YAW)
	for bay in 5:
		var x := (-2.0 + bay) * 8.6
		var roof := Vector3(x, 7.39, 0)
		_city.add_part(base, roof, roof_size, "roof_gray", YAW, false, "shed_roof")
		var glazing := base + frame * (roof + Vector3((short_pitch.x - roof_size.x) * 0.5, 0, 0)) + slope.y * 0.039
		_city._add_tilted_box(glazing, slope, Vector3(1.28, 0.072, 19.44), "residential_glass_lit", false)
		_city._window(base, Vector3(x, 6.82, 10.15), Vector2(5.52, 0.69), YAW, "glass")
		_city.add_part(base, Vector3(x - 4.09, 3.20, 10.15), Vector3(0.36, 6.43, 0.33), "plaster_dark", YAW)
		_city._garage_shutter(base, Vector3(x, 2.33, 10.18), 3.92 if bay == 1 else 4.45, YAW)
		_city.add_part(base, Vector3(x, 4.20, 10.86), Vector3(6.18, 0.20, 1.53), "steel_plate", YAW)
		_city.add_part(base, Vector3(x, 4.07, 10.97), Vector3(0.54, 0.10, 0.20), "light", YAW)
		if bay in [0, 3, 4]:
			var pad := base + Basis(Vector3.UP, YAW) * Vector3(x + 2.16, 0, 11.5)
			var site_on_ground: Vector3 = _ground.surface_point(Vector2(pad.x, pad.z), 0.37)
			_city.add_box(site_on_ground, Vector3(1.18, 0.72, 0.94), "bench", false, YAW)
			_city.add_box(site_on_ground + Vector3.UP * 0.39, Vector3(1.20, 0.06, 0.96), "metal", false, YAW)
		Openings.lettering(_city, "%02d" % (bay + 1), base + frame * Vector3(x - 3.18, 3.45, 10.29),
			YAW, 0.29, 0.25, Color("d1c4a7"))
	var sign_position := base + frame * Vector3(-8.6, 4.96, 10.163)
	Openings.lettering(_city, "ARMAZÉM FERROVIÁRIO", sign_position, YAW, 5.2, 0.36, Color("e2d1ad"))
	_city._lots += 1


func _waterworks(site: Vector2) -> void:
	var base := Parts.masonry_mass(_city, _ground, site, Vector3(13.3, 5.28, 11.7), PI, "terracotta")
	_city.add_part(base, Vector3(0, 5.95, 0), Vector3(13.94, 1.41, 12.42), "roof_gray", PI, false, "hip_roof")
	_city._window(base, Vector3(-2.9, 2.35, 5.91), Vector2(2.46, 2.1), PI, "glass")
	_city._window(base, Vector3(2.9, 2.35, 5.91), Vector2(2.46, 2.1), PI, "glass")
	_city.add_label("CASA DE MÁQUINAS", base + Vector3(0, 3.98, -5.91), PI, 0.013)
	var chimney: Vector3 = _ground.surface_point(site + Vector2(9.05, -4.35))
	_city.add_box(chimney + Vector3.UP * 1.13, Vector3(4.2, 2.29, 4.1), "stone", true)
	_city.add_instance("cylinder", "brick", chimney + Vector3.UP * 8.45, Vector3(1.52, 14.60, 1.52))
	_city.add_instance("cylinder", "brick", chimney + Vector3.UP * 16.8, Vector3(1.25, 2.36, 1.25))
	_city.add_instance("cylinder", "parapet", chimney + Vector3.UP * 18.10, Vector3(1.42, 0.43, 1.42))
	for height: float in [7.6, 12.6, 16.1]:
		var radius := 1.54 if height < 15.0 else 1.32
		_city.add_instance("cylinder", "metal", chimney + Vector3.UP * height, Vector3(radius, 0.12, radius))
	_city._lots += 1


func _siding(route: RefCounted) -> void:
	var crossing: Vector2 = route.point_at(32.0)
	for rail: float in [-0.72, 0.72]:
		_ground.patch(Rect2(crossing.x + rail - 0.055, 111.5, 0.11, 23.7), "steel_plate", 0.048)
	for index in 22:
		var site := Vector2(crossing.x, 112.27 + float(index) * 1.01)
		if Layout.road_distance(site) > 0.12:
			_ground.patch(Rect2(site - Vector2(1.25, 0.095), Vector2(2.50, 0.19)), "wood", 0.044)
	var buffer: Vector3 = _ground.surface_point(Vector2(crossing.x, 112.88))
	_city.add_box(buffer + Vector3.UP * 0.42, Vector3(2.14, 0.78, 0.55), "brick", true)
	_city.add_box(buffer + Vector3.UP * 0.72, Vector3(2.44, 0.23, 0.47), "metal")


func _loading_marks() -> void:
	for z: float in [148.4, 155.4, 162.4, 169.4]:
		_ground.patch(Rect2(161.0, z, 7.8, 0.13), "white", 0.045)
	for z: float in [151.4, 165.4]:
		_city._park(Vector2(164.3, z), -1, Vector2.RIGHT)
