extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Route = preload("res://scripts/city/figueiras_route.gd")
const LAKE_SHADER = preload("res://assets/shaders/figueiras/lake.gdshader")
const LAKESHORE_AUDIO = preload("res://assets/audio/wave-lakeshore.wav")
var _city: RefCounted
var _ground: RefCounted


func build(builder: RefCounted, terrain: RefCounted) -> void:
	_city = builder
	_ground = terrain
	var routes := Layout.scenic_routes()
	for route in routes:
		_paint_road(route)
		_guardrails(route)
		_sign(route, 22.0, 1.0)
		_sign(route, route.length - 23.0, -1.0)
		_bay(route)
		_roadside_groves(route)
	_lookout(routes[0])
	_lake()
	_lakeside(routes[1])
	_city = null
	_ground = null


func _quad(points: PackedVector2Array, material: String, lift: float) -> void:
	if (points[1] - points[0]).cross(points[2] - points[0]) < 0.0:
		points.reverse()
	_ground.patch_polygon(points, material, lift)


func _stripe(route: Route, start: float, end: float, left: float, right: float, material: String, lift := 0.026, drift := 0.0) -> void:
	var pieces := maxi(1, ceili((end - start) / 1.4))
	var a := route.offset_at(start, left)
	var d := route.offset_at(start, right)
	for piece in range(1, pieces + 1):
		var fraction := float(piece) / pieces
		var station := lerpf(start, end, fraction)
		var b := route.offset_at(station, left + drift * fraction)
		var c := route.offset_at(station, right + drift * fraction)
		_quad(PackedVector2Array([a, b, c, d]), material, lift)
		a = b
		d = c


func _painted_edge(route: Route, station: float, side: float) -> float:
	var width := route.half_width if absf(station - route.stop_station) < 32.0 else route.edge_at(station, side)
	return side * (width - 0.49)


func _paint_road(route: Route) -> void:
	var first := 23.0
	var last := route.length - 22.0
	for station in range(23, floori(last), 5):
		for side: float in [-1, 1]:
			var dashed := side < 0.0 and absf(station - route.stop_station) < 23.0
			var end := minf(station + (2.6 if dashed else 5.0), last)
			var edge := _painted_edge(route, station, side)
			var drift := _painted_edge(route, end, side) - edge
			_stripe(route, station, end, edge - 0.066, edge + 0.066, "white", 0.026, drift)
	for station in range(roundi(first), floori(last), 8):
		var tight := absf(route.bank_at(station + 4.0)) > 0.032
		if tight:
			for offset: float in [-0.145, 0.145]:
				_stripe(route, station, minf(station + 8.0, last), offset - 0.055, offset + 0.055, "yellow")
		else:
			_stripe(route, station, minf(station + 4.15, last), -0.058, 0.058, "yellow")


func _guardrails(route: Route) -> void:
	for station in range(32, floori(route.length) - 30, 6):
		var outer := maxf(route.edge_at(station, -1.0), route.edge_at(station + 6.0, -1.0)) + 1.03
		var a := route.offset_at(station, -outer)
		if absf(station + 3.0 - route.stop_station) > 34.0:
			var b := route.offset_at(station + 6.0, -outer)
			var first := Layout.surface_point(a, 0.64)
			var last := Layout.surface_point(b, 0.64)
			var axis := (last - first).normalized()
			var center := (first + last) * 0.5
			_city._add_tilted_box(center, Basis.looking_at(axis), Vector3(0.15, 0.27, first.distance_to(last) + 0.045), "steel_plate", true)
			_city.add_box(Layout.surface_point(a, 0.33), Vector3(0.12, 0.74, 0.12), "steel_plate")
		if station % 12 == 8:
			var marker := Layout.surface_point(route.offset_at(station, route.edge_at(station, 1.0) + 1.23))
			_city.add_box(marker + Vector3.UP * 0.34, Vector3(0.135, 0.71, 0.135), "trim")
			_city.add_box(marker + Vector3.UP * 0.64, Vector3(0.152, 0.12, 0.152), "signal_amber")
	for station in range(49, floori(route.length) - 42, 35):
		if absf(station - route.stop_station) < 38.0:
			continue
		var side := 1.0 if station % 2 else -1.0
		var center := route.offset_at(station, side * (route.edge_at(station, side) + 1.85))
		_city._lamp(center, -route.direction_at(station).orthogonal() * side)
	for station in range(53, floori(route.length) - 40, 18):
		if absf(route.bank_at(station)) > 0.043 and absf(station - route.stop_station) > 38.0:
			_chevron(route, station)


func _chevron(route: Route, station: float) -> void:
	var direction := route.direction_at(station)
	var side := signf(route.bank_at(station))
	var origin := Layout.surface_point(route.offset_at(station, side * (route.half_width + 1.46)))
	var yaw := atan2(-direction.x, -direction.y)
	var basis := Basis(Vector3.UP, yaw)
	_city.add_part(origin, Vector3(0, 0.77, 0), Vector3(0.083, 1.54, 0.093), "steel_plate", yaw)
	_city.add_part(origin, Vector3(0, 1.45, 0), Vector3(0.70, 0.61, 0.13), "sign_ink", yaw)
	_city.add_label("›" if side > 0.0 else "‹", origin + basis * Vector3(0, 1.47, 0.077), yaw, 0.018)


func _sign(route: Route, station: float, travel: float) -> void:
	var direction := route.direction_at(station) * travel
	var yaw := atan2(-direction.x, -direction.y)
	var facing := Basis(Vector3.UP, yaw)
	var site := route.offset_at(station, -travel * (route.edge_at(station, -travel) + 3.3))
	var origin := Layout.surface_point(site)
	for x: float in [-1.44, 1.44]:
		_city.add_part(origin, Vector3(x, 1.18, 0), Vector3(0.13, 2.39, 0.15), "steel_plate", yaw, true)
	_city.add_part(origin, Vector3(0, 2.14, 0), Vector3(4.54, 0.79, 0.14), "awning_green", yaw)
	_city.add_label(route.title.to_upper(), origin + facing * Vector3(0, 2.14, 0.083), yaw, 0.0096)


func _bay(route: Route) -> void:
	var station := route.stop_station
	for offset: float in [-9.0, -3.0, 3.0, 9.0]:
		_stripe(route, station + offset, station + offset + 0.10, -route.half_width - 5.4, -route.half_width - 0.72, "white", 0.029)
	var foot := route.offset_at(station, -route.half_width - 8.04)
	var direction := route.direction_at(station)
	var yaw := atan2(direction.x, direction.y)
	_station_shelter(foot, yaw, "MIRANTE DO IPÊ" if route == Layout.scenic_routes()[0] else "PARQUE DAS ÁGUAS")
	for delta: float in [-15, 16]:
		var site := route.offset_at(station + delta, -route.half_width - 8.92)
		_city._tree(site, 8.3, 1 if delta < 0.0 else 0, false)
		_city._garden(site, 3.1, 17)
		_city._lamp(route.offset_at(station + delta, -route.half_width - 6.9), direction.orthogonal())


func _station_shelter(site: Vector2, yaw: float, title: String) -> void:
	var base := Layout.surface_point(site)
	var basis := Basis(Vector3.UP, yaw)
	var cross := Vector2(basis.x.x, basis.x.z)
	var front := Vector2(basis.z.x, basis.z.z)
	_quad(PackedVector2Array([site - cross * 2.7 - front * 5.3, site + cross * 2.7 - front * 5.3,
		site + cross * 2.7 + front * 5.3, site - cross * 2.7 + front * 5.3]), "cobbles", 0.054)
	var roof_y := base.y + 3.40
	for x: float in [-1.88, 1.88]:
		for z: float in [-4.05, 4.05]:
			var foot := Layout.surface_point(site + cross * x + front * z)
			var height := roof_y - foot.y
			_city.add_box(foot + Vector3.UP * height * 0.5, Vector3(0.29, height, 0.32), "brick", true, yaw)
			_city.add_box(foot + Vector3.UP * 0.25, Vector3(0.49, 0.51, 0.50), "stone", false, yaw)
	_city.add_part(base, Vector3(0, 3.44, 0), Vector3(4.75, 0.28, 9.27), "awning_green", yaw)
	_city.add_part(base, Vector3(0, 3.79, 0), Vector3(4.68, 0.63, 9.12), "roof", yaw, false, "roof")
	for z: float in [-2.62, 2.62]:
		_city._bench(site + front * z, yaw + PI * 0.5)
	var plate := base + basis * Vector3(2.36, 3.09, 0)
	_city.add_box(plate, Vector3(0.13, 0.51, 4.52), "sign_ink", false, yaw)
	_city.add_label(title, plate + basis.x * 0.077, yaw + PI * 0.5, 0.0115)


func _lookout(route: Route) -> void:
	var station := route.stop_station
	var across := route.direction_at(station).orthogonal()
	var yaw := atan2(-across.x, -across.y)
	var site := route.offset_at(station + 4.0, route.half_width + 3.60)
	var origin := Layout.surface_point(site)
	_city.add_part(origin, Vector3(0, 1.70, -0.05), Vector3(7.85, 3.95, 0.56), "stone", yaw, true)
	_city.add_part(origin, Vector3(0, 3.73, 0), Vector3(8.16, 0.17, 0.66), "trim", yaw)
	_city.add_part(origin, Vector3(0, 1.96, 0.247), Vector3(7.42, 3.35, 1.0), "mural_ipe", yaw, false, "pane")
	for side: float in [-1, 1]:
		_city.add_part(origin, Vector3(side * 3.88, 1.84, 0.24), Vector3(0.35, 3.76, 0.64), "brick", yaw)
		var axis := Vector2(cos(yaw), -sin(yaw)) * side
		for section in 3:
			var a := site + axis * (4.01 + section * 2.4)
			var b := a + axis * 2.4
			var height := 1.38 - section * 0.29
			_city._rail(a, b, height * 0.32, height * 1.45, "stone", true)
			_city._rail(a, b, height * 1.04, 0.15, "trim")
		_city._garden(site + axis * 10.0 - across * 0.80, 1.8, 9)
	for delta in range(-22, 22, 5):
		var outer := -route.half_width - 11.75
		var a := route.offset_at(station + delta, outer)
		var b := route.offset_at(station + delta + 5, outer)
		_city._rail(a, b, 0.31, 0.57, "stone", true)
		_city._rail(a, b, 0.86, 0.13, "steel_plate")
		_city.add_box(Layout.surface_point(a, 0.69), Vector3(0.17, 0.44, 0.18), "steel_plate")


func _lake() -> void:
	var center := Vector3(Layout.LAKE.x, Layout.LAKE_LEVEL, Layout.LAKE.y)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 96:
		surface.set_uv(Vector2(0.5, 0.5))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3.ZERO)
		for boundary: int in [index, index + 1]:
			var angle := TAU * boundary / 96.0
			var vertex := Layout.lake_outline(angle)
			surface.set_uv(Vector2.from_angle(angle) * 0.5 + Vector2(0.5, 0.5))
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(vertex.x, 0, vertex.y))
	surface.index()
	var material := ShaderMaterial.new()
	material.resource_name = "figueiras_lake"
	material.shader = LAKE_SHADER
	var lake := MeshInstance3D.new()
	lake.name = &"LagoDasFigueiras"
	lake.mesh = surface.commit()
	lake.material_override = material
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lake.position = center
	_city.scene_root.add_child(lake)
	var shore := AudioStreamPlayer3D.new()
	shore.name = &"SomDaMargem"
	var stream := LAKESHORE_AUDIO.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	shore.stream = stream
	shore.bus = &"Ambiente"
	shore.volume_db = -8.0
	shore.unit_size = 21.0
	shore.max_distance = 62.0
	shore.position = center + Vector3(26.0, 1.0, 3.5)
	shore.autoplay = true
	_city.scene_root.add_child(shore)
	for index in 48:
		var a := Layout.lake_outline(TAU * index / 48.0)
		var b := Layout.lake_outline(TAU * (index + 1) / 48.0)
		_quad(PackedVector2Array([Layout.LAKE + a * 1.095, Layout.LAKE + b * 1.095,
			Layout.LAKE + b * 1.174, Layout.LAKE + a * 1.174]), "cobbles", 0.042)
		if index in [4, 5, 6, 15, 16, 17, 28, 29, 35, 36, 37]:
			var bank := 1.02 + 0.043 * sin(index * 2.3)
			var next_bank := 1.02 + 0.043 * sin((index + 1) * 2.3)
			_quad(PackedVector2Array([Layout.LAKE + a * 0.91, Layout.LAKE + b * 0.91,
				Layout.LAKE + b * next_bank, Layout.LAKE + a * bank]), "mulch", 0.023)
			var stone := Layout.surface_point(Layout.LAKE + a * 0.963, 0.16)
			_city.add_instance("shrub", "stone", stone, Vector3(0.95, 0.54, 0.69), index * 0.81)
		if index % 5 == 0 and a.x < Layout.LAKE_RADII.x * 0.57:
			var site := Layout.LAKE + a * 1.26
			if Layout.road_distance(site) > 5.0:
				_city._tree(site, 6.4 + float(index % 4), index % 3, false)
				_city._garden(site, 2.85, 17)
		if index % 7 == 0:
			var reeds := Layout.LAKE + a * 0.995
			_city._garden(reeds, 1.5, 8)


func _roadside_groves(route: Route) -> void:
	var next_cluster := 0
	for station in range(44, floori(route.length) - 39, 14):
		var side := 1.0 if next_cluster % 4 != 1 else -1.0
		next_cluster += 1
		if absf(station - route.stop_station) < 37.0:
			continue
		for offset: float in [0, 5.0]:
			var distance := route.half_width + 7.5 + 4.5 * sin(station * 0.112 + offset) + offset
			var site := route.offset_at(station + offset, distance * side)
			if Layout.road_distance(site) < 3.4 or Layout.lake_distance(site) < 1.24:
				continue
			var height := 5.8 + 2.6 * absf(sin(station * 0.078 + offset))
			_city._tree(site, height, (next_cluster + roundi(offset)) % 4, false)
			if offset == 0.0:
				_city._garden(site, 2.3, 9)


func _lakeside(route: Route) -> void:
	var pier := Vector3(Layout.LAKE.x + 25.5, Layout.LAKE_LEVEL + 0.49, Layout.LAKE.y + 3.5)
	_city.add_box(pier, Vector3(21.2, 0.19, 3.36), "bench", true)
	_city.add_box(pier + Vector3(-9.63, 0, 0), Vector3(4.7, 0.21, 6.55), "bench", true)
	_city.add_box(pier + Vector3(13.7, 0, 0), Vector3(6.25, 0.18, 3.36), "bench", true)
	for x: float in [-9.9, -6.45, -2.95, 0.5, 4.1, 7.7, 10.4]:
		for side: float in [-1, 1]:
			var z := side * 1.56
			_city.add_box(pier + Vector3(x, -0.78, z), Vector3(0.22, 1.8, 0.23), "wood")
			_city.add_box(pier + Vector3(x, 0.47, z), Vector3(0.12, 0.96, 0.12), "wood")
	for side: float in [-1, 1]:
		_city.add_box(pier + Vector3(0, 0.93, side * 1.56), Vector3(21.1, 0.11, 0.12), "wood")
	var site := route.offset_at(route.stop_station - 13.0, -16.3)
	var center := Layout.surface_point(site)
	var heading := route.direction_at(route.stop_station - 13.0).orthogonal()
	var yaw := atan2(heading.x, heading.y)
	_city.add_part(center, Vector3(0, 1.33, 0), Vector3(7.12, 3.21, 5.20), "sage", yaw, true)
	_city.add_part(center, Vector3(0, 3.11, 0), Vector3(7.63, 0.39, 5.72), "roof_gray", yaw)
	_city.add_part(center, Vector3(0, 2.78, 2.89), Vector3(7.53, 0.22, 1.48), "awning_green", yaw)
	_city._window(center, Vector3(0, 1.42, 2.62), Vector2(4.64, 1.89), yaw, "shop_market_left")
	_city.add_label("QUIOSQUE DO LAGO", center + Basis(Vector3.UP, yaw) * Vector3(0, 2.61, 2.65), yaw, 0.011)
