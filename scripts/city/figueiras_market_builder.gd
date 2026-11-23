extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Route = preload("res://scripts/city/figueiras_route.gd")
const Parts = preload("res://scripts/city/figueiras_building_parts.gd")
const Openings = preload("res://scripts/city/figueiras_openings.gd")
const TILES := "res://assets/textures/figueiras/painel-do-mercado.png"
const CANOPY_HALF := 7.65
const CANOPY_EAVE := 5.45
const TOWER := Vector2(-145.0, 152.0)
var _city: RefCounted
var _ground: RefCounted


static func install_materials(materials: Dictionary) -> void:
	var mural := StandardMaterial3D.new()
	mural.resource_name = "market_mural"
	mural.albedo_color = Color("d0ba92")
	mural.roughness = 0.55
	if ResourceLoader.exists(TILES):
		mural.albedo_texture = load(TILES)
		mural.albedo_color = Color.WHITE
	mural.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials["market_mural"] = mural


static func build_hall(city: RefCounted, ground: RefCounted, site: Vector2, frontage: Vector2, width: float, depth: float, yaw: float) -> void:
	var bounds := Parts.floor_range(ground, site, width, depth, yaw)
	var frame := Basis(Vector3.UP, yaw)
	var forward := Vector2(frame.z.x, frame.z.z)
	var face := depth * 0.5
	var front_height := -INF
	for x: float in [-0.5, 0.0, 0.5]:
		front_height = maxf(front_height, ground.surface_point(site + forward * face + Vector2(frame.x.x, frame.x.z) * x * width).y)
	var base := Vector3(site.x, front_height + 0.24, site.y)
	var foundation := base.y - bounds.x + 0.38
	city.add_part(base, Vector3(0, -foundation * 0.50, 0), Vector3(width + 0.24, foundation, depth + 0.16), "stone", yaw, true)
	city.add_part(base, Vector3(0, 0.018, 0), Vector3(width, 0.045, depth), "paving", yaw)
	_market_walls(city, ground, base, width, depth, yaw)
	_market_roof(city, base, width, depth, yaw)
	_market_stalls(city, base, width, depth, yaw)
	var entry := site + forward * (face + 0.10)
	city._access(frontage, entry, base.y, yaw, width * 0.64)
	for side: float in [-1.0, 1.0]:
		var edge := entry + Vector2(frame.x.x, frame.x.z) * side * width * 0.42
		var planter: Vector3 = ground.surface_point(edge + forward * 1.1, 0.20)
		city.add_box(planter, Vector3(2.13, 0.44, 1.38), "stone", true, yaw)
		city._garden(Vector2(planter.x, planter.z), 1.1, 8)
	var board := base + frame * Vector3(0, 4.70, face + 0.294)
	city.add_box(board, Vector3(width * 0.37, 0.48, 0.074), "parapet", false, yaw)
	Openings.lettering(city, "MERCADO DAS FIGUEIRAS", board + frame.z * 0.042, yaw, width * 0.33, 0.39, Color("40392f"))
	var marker := Marker3D.new()
	marker.name = "MercadoNave"
	marker.position = base
	city.scene_root.add_child(marker)
	city.scene_root.set_meta("market_hall_area", width * depth)
	city._lots += 1


static func _market_walls(city: RefCounted, ground: RefCounted, base: Vector3, width: float, depth: float, yaw: float) -> void:
	var face := depth * 0.5
	var frame := Basis(Vector3.UP, yaw)
	city.add_part(base, Vector3(0, 2.58, -face + 0.15), Vector3(width, 5.16, 0.38), "brick", yaw, true)
	city.add_part(base, Vector3(0, 4.41, face + 0.03), Vector3(width, 1.33, 0.48), "brick", yaw, true)
	for index in 4:
		var x := (float(index) / 3.0 - 0.5) * (width - 0.69)
		city.add_part(base, Vector3(x, 1.96, face), Vector3(0.74, 3.92, 0.73), "brick", yaw, true)
		city.add_part(base, Vector3(x, 0.38, face), Vector3(0.98, 0.76, 0.97), "stone", yaw)
		city.add_part(base, Vector3(x, 3.08, face + 0.039), Vector3(0.94, 0.23, 0.92), "trim", yaw)
	for bay: float in [-1.0, 0.0, 1.0]:
		var x := bay * (width - 0.65) / 3.0
		var spring := base + frame * Vector3(x, 2.25, face + 0.09)
		city.add_instance("masonry_arch", "stone", spring, Vector3((width - 3.06) / 3.0, 2.18, 0.73), yaw)
		var open_width := (width - 3.06) / 3.0 * 0.91
		city.add_part(base, Vector3(x, 3.76, face - 0.66), Vector3(open_width, 0.17, 0.30), "metal", yaw)
		city.add_part(base, Vector3(x, 3.57, face - 0.64), Vector3(open_width, 0.24, 0.12), "steel_plate", yaw)
		city.add_part(base, Vector3(x, 3.46, face - 0.71), Vector3(0.62, 0.085, 0.25), "light", yaw)
		for side: float in [-1.0, 1.0]:
			city.add_part(base, Vector3(x + open_width * 0.47 * side, 1.76, face - 0.69), Vector3(0.10, 3.49, 0.16), "metal", yaw)
	for side: float in [-1.0, 1.0]:
		var bearing := yaw + side * PI * 0.5
		var side_frame := Basis(Vector3.UP, bearing)
		var wall := width * 0.50
		city.add_part(base, Vector3(0, 0.65, wall - 0.14), Vector3(depth, 1.30, 0.40), "brick", bearing, true)
		city.add_part(base, Vector3(0, 4.03, wall - 0.14), Vector3(depth, 2.28, 0.40), "brick", bearing, true)
		city.add_part(base, Vector3(0, 0.42, wall + 0.14), Vector3(depth + 0.34, 0.82, 0.22), "stone", bearing)
		for bay in 6:
			var x := (float(bay) / 5.0 - 0.5) * (depth - 0.43)
			city.add_part(base, Vector3(x, 2.07, wall - 0.13), Vector3(0.40, 1.68, 0.41), "brick", bearing, true)
			city.add_part(base, Vector3(x, 2.60, wall + 0.12), Vector3(0.30, 5.13, 0.26), "parapet", bearing)
			if bay < 5:
				city._window(base, Vector3(x + (depth - 0.43) * 0.10, 2.17, wall - 0.14), Vector2((depth - 0.43) * 0.20 - 0.49, 1.72), bearing, "residential_glass_lit", "aluminium")
		var dock := base + side_frame * Vector3(-0.34 * depth, 0, wall + 1.11)
		var dock_site := Vector2(dock.x, dock.z)
		var local_floor: Vector3 = ground.surface_point(dock_site, 0.14)
		city.add_box(local_floor, Vector3(2.94, 0.32, 1.60), "stone", false, bearing)
		city.add_part(base, Vector3(0, 4.99, wall + 0.06), Vector3(depth + 0.37, 0.22, 0.62), "trim", bearing)


static func _market_roof(city: RefCounted, base: Vector3, width: float, depth: float, yaw: float) -> void:
	var frame := Basis(Vector3.UP, yaw)
	var nave := width * 0.59
	for side: float in [-1.0, 1.0]:
		var eave := base + frame * Vector3(side * (width * 0.5 + 0.76), 5.20, 0)
		var high := base + frame * Vector3(side * (nave * 0.5 - 0.28), 6.22, 0)
		var slope := (high - eave).normalized()
		var sheet := Basis(slope, frame.z.cross(slope).normalized(), frame.z)
		city._add_tilted_box((high + eave) * 0.5, sheet, Vector3(high.distance_to(eave), 0.23, depth + 1.24), "roof", false)
		var facing := yaw + side * PI * 0.5
		city.add_part(base, Vector3(0, 6.88, nave * 0.50), Vector3(depth, 1.77, 0.21), "plaster_dark", facing)
		for bay in 4:
			city._window(base, Vector3((bay - 1.5) * depth * 0.225, 6.94, nave * 0.50 + 0.05), Vector2(depth * 0.20, 0.95), facing, "residential_glass_lit")
	city.add_part(base, Vector3(0, 6.87, depth * 0.50 - 0.055), Vector3(nave + 0.20, 1.61, 0.28), "brick", yaw)
	city.add_part(base, Vector3(0, 5.54, depth * 0.50 - 0.070), Vector3(nave + 0.20, 1.09, 0.25), "brick", yaw)
	city.add_part(base, Vector3(0, 6.90, depth * 0.50 + 0.104), Vector3(nave * 0.60, 1.20, 1.0), "market_mural", yaw, false, "pane")
	city.add_part(base, Vector3(0, 6.84, -depth * 0.50 + 0.055), Vector3(nave + 0.20, 1.70, 0.28), "brick", yaw)
	city.add_part(base, Vector3(0, 8.81, 0), Vector3(nave + 1.48, 2.32, depth + 0.94), "roof_gray", yaw, false, "roof")
	for z: float in [-0.35, -0.10, 0.15, 0.40]:
		city.add_part(base, Vector3(0, 4.74, z * depth), Vector3(width * 0.99, 0.18, 0.22), "steel_plate", yaw)
		var center := base + frame * Vector3(0, 4.86, z * depth)
		Parts.beam(city, center, center + frame * Vector3(-width * 0.46, 1.0, 0), 0.11, 0.13, "metal")
		Parts.beam(city, center, center + frame * Vector3(width * 0.46, 1.0, 0), 0.11, 0.13, "metal")


static func _market_stalls(city: RefCounted, base: Vector3, width: float, depth: float, yaw: float) -> void:
	var frame := Basis(Vector3.UP, yaw)
	var stalls := [["HORTALIÇAS", "GRÃOS", "QUEIJOS"], ["FRUTAS", "FARINHAS", "CAFÉ"]]
	for side: float in [-1.0, 1.0]:
		for row in 3:
			var offset := Vector3(side * width * 0.24, 0, depth * (0.20 - row * 0.24))
			var finish := ["ceramic", "awning", "awning_green"][row] as String
			city.add_part(base, offset + Vector3.UP * 0.46, Vector3(3.21, 0.89, 2.12), "parapet", yaw)
			city.add_part(base, offset + Vector3.UP * 0.94, Vector3(3.42, 0.082, 2.30), "stone", yaw)
			city.add_part(base, offset + Vector3(0, 0.48, 1.07), Vector3(3.03, 0.55, 0.03), finish, yaw)
			if row != 1:
				for support: float in [-1.38, 1.38]:
					city.add_part(base, offset + Vector3(support, 1.62, -0.91), Vector3(0.07, 1.36, 0.09), "metal", yaw)
				city.add_part(base, offset + Vector3(0, 2.33, -0.36), Vector3(3.29, 0.09, 1.56), finish, yaw)
			var label := base + frame * (offset + Vector3(0, 0.52, 1.095))
			Openings.lettering(city, stalls[0 if side < 0.0 else 1][row], label, yaw, 1.12, 0.21, Color("eaddbe"))
			for crate in 3:
				var color: String = ["terracotta_pot", "sage", "tactile"][posmod(crate + row, 3)]
				var tray := offset + Vector3(0.88 * (crate - 1), 1.06, 0.36)
				city.add_part(base, tray, Vector3(0.69, 0.13, 0.72), "wood", yaw)
				for item in 4:
					var fruit := tray + Vector3((item % 2) * 0.292 - 0.15, 0.16, floori(item * 0.5) * 0.274 - 0.14)
					city.add_instance("foliage", color, base + frame * fruit, Vector3(0.12, 0.085, 0.11), yaw, false)


func build(builder: RefCounted, ground: RefCounted) -> void:
	_city = builder
	_ground = ground
	var road := Layout.urban_routes()[Layout.MERCADO_ROUTE]
	var span := Layout.market_cover_span(road)
	_mark_road(road)
	_canopy(road, span)
	_loading_yard(road, span)
	_landscape(road, span)
	_tower()
	_city.scene_root.set_meta("market_road_length", road.length)
	_city.scene_root.set_meta("market_canopy_span", span)
	_city = null
	_ground = null


func _mark_road(road: Route) -> void:
	for station in range(16, floori(road.length) - 16, 5):
		_strip(road, station, station + 2.65, -0.063, 0.063, "yellow")
		for side: float in [-1.0, 1.0]:
			var edge := side * 4.14
			_strip(road, station, station + 5.0, edge - 0.048, edge + 0.048, "white")
		if station % 20 != 16:
			continue
		var site := road.offset_at(station, 6.35)
		_city._lamp(site, -road.direction_at(station).orthogonal())
	for x: float in [-170.50, -102.50]:
		var site := Vector2(x, Layout.AVENUE + Layout.AVENUE_HALF + 2.5)
		var origin: Vector3 = _ground.surface_point(site)
		var yaw := PI * 0.5
		_city.add_box(origin + Vector3.UP * 1.27, Vector3(0.12, 2.54, 0.12), "steel_plate", true)
		_city.add_box(origin + Vector3.UP * 2.46, Vector3(3.74, 0.57, 0.12), "awning_green", false, yaw)
		_city.add_label("MERCADO", origin + Vector3(0.074, 2.46, 0), yaw, 0.0125)
		_city.add_label("MERCADO  →", origin + Vector3(-0.074, 2.46, 0), yaw + PI, 0.0115)


func _canopy(road: Route, span: Vector2) -> void:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	const BAYS := 5
	var length := span.y - span.x
	for index in BAYS:
		var a := lerpf(span.x, span.y, float(index) / BAYS)
		var b := lerpf(span.x, span.y, float(index + 1) / BAYS)
		var ridge_a := _at(road, a, 0, CANOPY_EAVE + 1.38)
		var ridge_b := _at(road, b, 0, CANOPY_EAVE + 1.38)
		_beam(ridge_a, ridge_b, 0.16, 0.18, "steel_plate")
		for side: float in [-1.0, 1.0]:
			var eave_a := _at(road, a, CANOPY_HALF * side, CANOPY_EAVE)
			var eave_b := _at(road, b, CANOPY_HALF * side, CANOPY_EAVE)
			var vertices := [ridge_a, eave_a, ridge_b, eave_a, eave_b, ridge_b]
			if side > 0.0:
				vertices.reverse()
			for point: Vector3 in vertices:
				top.set_uv(Vector2(point.x, point.z) * 0.38)
				top.add_vertex(point)
			_beam(eave_a, eave_b, 0.17, 0.19, "trim")
	_frame(road, span.x, true)
	for index in range(1, BAYS):
		_frame(road, span.x + length * float(index) / BAYS, false)
	_frame(road, span.y, true)
	top.generate_normals()
	top.generate_tangents()
	var roof := MeshInstance3D.new()
	roof.name = "CoberturaMercado"
	roof.mesh = top.commit()
	var finish := (_city.materials["roof_gray"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	finish.resource_name = "market_roof"
	finish.albedo_color = Color("717a71")
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof.material_override = finish
	_city.scene_root.add_child(roof)
	var upper := StaticBody3D.new()
	upper.name = "CoberturaMercadoSolid"
	roof.add_child(upper)
	var shape := CollisionShape3D.new()
	var shell := roof.mesh.create_trimesh_shape()
	shell.backface_collision = true
	shape.shape = shell
	upper.add_child(shape)
	for station: float in [span.x + 2.0, span.y - 2.0]:
		var marker := Marker3D.new()
		marker.name = "MarketLight_%d" % roundi(station)
		marker.position = _at(road, station, 0.0, 4.88)
		_city.scene_root.add_child(marker)


func _frame(road: Route, station: float, entrance: bool) -> void:
	var axis := road.direction_at(station)
	var height := CANOPY_EAVE - 0.36
	var ridge := _at(road, station, 0.0, CANOPY_EAVE + 1.38)
	var left := _at(road, station, -CANOPY_HALF, CANOPY_EAVE)
	var right := _at(road, station, CANOPY_HALF, CANOPY_EAVE)
	for side: float in [-1.0, 1.0]:
		var lateral := side * (CANOPY_HALF - 0.29)
		var base := _at(road, station, lateral, -0.12)
		var top := _at(road, station, lateral, CANOPY_EAVE)
		var yaw := atan2(axis.x, axis.y)
		var size := 0.58 if entrance else 0.29
		_city.add_box((top + base) * 0.5, Vector3(size, top.y - base.y, size), "retaining_oxide" if entrance else "steel_plate", true, yaw)
		_city.add_box(base + Vector3.UP * 0.37, Vector3(size + 0.24, 0.92, size + 0.24), "stone", true, yaw)
		_beam(left if side < 0.0 else right, ridge, 0.18, 0.24, "steel_plate")
		_beam(_at(road, station, lateral, 3.77), _at(road, station, lateral * 0.72, height), 0.12, 0.14, "steel_plate")
	_beam(_at(road, station, -CANOPY_HALF, height), _at(road, station, CANOPY_HALF, height), 0.22, 0.23, "steel_plate", true)
	for lateral: float in [-2.9, 2.9]:
		var fixture := _at(road, station, lateral, height - 0.19)
		var yaw := atan2(axis.x, axis.y)
		_city.add_box(fixture + Vector3.UP * 0.063, Vector3(0.23, 0.16, 0.70), "metal", false, yaw)
		_city.add_box(fixture - Vector3.UP * 0.032, Vector3(0.16, 0.07, 0.66), "light", false, yaw)
	if entrance:
		var sign := _at(road, station, 0.0, 5.35)
		_city.add_box(sign, Vector3(4.1, 0.44, 0.14), "awning_green", false, atan2(axis.x, axis.y))
		for side: float in [-1.0, 1.0]:
			var facing := axis * side
			Openings.lettering(_city, "MERCADO MUNICIPAL", sign + Vector3(facing.x, 0, facing.y) * 0.079,
				atan2(facing.x, facing.y), 3.74, 0.32, Color("e5d8ba"))


func _loading_yard(road: Route, span: Vector2) -> void:
	for index in 11:
		var a := lerpf(span.x, span.y, float(index) / 11.0)
		var b := lerpf(span.x, span.y, float(index + 1) / 11.0)
		for side: float in [-1.0, 1.0]:
			_strip(road, a, b, side * 5.0, side * 10.35, "cobbles", 0.037)
	for side: float in [-1.0, 1.0]:
		var station := (span.x + span.y) * 0.5 + side * 3.2
		var facing := road.direction_at(station).orthogonal() * -side
		var yaw := atan2(facing.x, facing.y)
		var site := road.offset_at(station, side * 13.6)
		var ground: Vector3 = _ground.surface_point(site, 0.2)
		var basis := Basis(Vector3.UP, yaw)
		var bottom := ground.y
		for x: float in [-6.60, 6.60]:
			for z: float in [-3.0, 3.0]:
				var point := basis * Vector3(x, 0.0, z)
				var foot: Vector3 = _ground.surface_point(site + Vector2(point.x, point.z))
				bottom = minf(bottom, foot.y - 0.37)
		var foundation := maxf(0.64, ground.y - bottom)
		_city.add_part(ground, Vector3(0.0, -foundation * 0.5, 0.0), Vector3(13.6, foundation, 6.4), "stone", yaw, true)
		_city.add_part(ground, Vector3(0.0, 1.57, 0.0), Vector3(13.4, 3.14, 6.1), "brick", yaw, true)
		_city.add_part(ground, Vector3(0.0, 3.5, 0.0), Vector3(14.0, 0.91, 7.0), "roof_gray", yaw, false, "hip_roof")
		for bay: float in [-1.0, 1.0]:
			var panel := Vector3(bay * 3.32, 1.43, 3.12)
			_city.add_part(ground, panel, Vector3(4.46, 2.57, 0.18), "plaster_dark", yaw)
			for slat in 9:
				_city.add_part(ground, panel + Vector3(0, -1.05 + slat * 0.26, 0.10), Vector3(4.26, 0.08, 0.04), "steel_plate", yaw)
			var pad := ground + basis * Vector3(bay * 3.34, 0.27, 4.15)
			_city.add_box(pad, Vector3(1.18, 0.56, 0.80), "bench", false, yaw)
		_city.add_label("CARGA E DESCARGA", ground + basis * Vector3(0, 3.12, 3.13), yaw, 0.0105)
		var parking := station - side * 3.9
		_city._park(road.offset_at(parking, side * 8.95), side, road.direction_at(parking))


func _landscape(road: Route, span: Vector2) -> void:
	for side: float in [-1.0, 1.0]:
		for station: float in [span.x - 26.0, span.x - 19.0, span.x - 12.0, span.y + 14.0, span.y + 21.0]:
			var a := _at(road, station, side * 8.8, 0.47)
			var b := _at(road, station + 7.10, side * 8.8, 0.47)
			_beam(a, b, 0.53, 1.01, "retaining_oxide", true)
			_beam(a + Vector3.UP * 0.49, b + Vector3.UP * 0.49, 0.68, 0.13, "stone")
			var site := road.offset_at(station + 3.9, side * 10.7)
			if station < span.x - 12.0 or side > 0.0:
				_city._garden(site, 1.65, 8)
		for station: float in [span.x - 17.0, span.y + 22.0, span.y + 34.0]:
			if station > road.length - 19.0:
				continue
			var site := road.offset_at(station, side * 12.5)
			_city._tree(site, 4.6 + absf(sin(station)) * 1.75, 1 if side > 0.0 else 3, false, false)


func _tower() -> void:
	var origin: Vector3 = _ground.surface_point(TOWER)
	for x: float in [-2.14, 2.14]:
		for z: float in [-2.14, 2.14]:
			var foot: Vector3 = _ground.surface_point(TOWER + Vector2(x, z), -0.35)
			var top := origin + Vector3(x * 0.91, 10.9, z * 0.91)
			_beam(foot, top, 0.54, 0.54, "retaining_oxide", true)
	for step: float in [3.1, 6.3, 9.6]:
		for edge: float in [-2.0, 2.0]:
			_beam(origin + Vector3(-2.0, step, edge), origin + Vector3(2.0, step + 2.5, edge), 0.16, 0.14, "steel_plate")
			_beam(origin + Vector3(edge, step + 2.5, -2.0), origin + Vector3(edge, step, 2.0), 0.16, 0.14, "steel_plate")
	_city.add_instance("cylinder", "stone", origin + Vector3.UP * 10.95, Vector3(6.98, 0.46, 6.98), 0)
	_city.add_instance("cylinder", "reservoir_blue", origin + Vector3.UP * 12.66, Vector3(6.20, 3.0, 6.20), 0)
	_city.add_instance("cylinder", "trim", origin + Vector3.UP * 14.23, Vector3(6.54, 0.27, 6.54), 0)
	_city.add_instance("cylinder", "steel_plate", origin + Vector3.UP * 14.46, Vector3(1.1, 0.28, 1.1), 0)


func _at(road: Route, station: float, side: float, lift: float) -> Vector3:
	return _ground.surface_point(road.offset_at(station, side), lift)


func _beam(a: Vector3, b: Vector3, width: float, depth: float, finish: String, solid := false) -> void:
	var axis := (b - a).normalized()
	var up := Vector3.FORWARD if absf(axis.dot(Vector3.UP)) > 0.93 else Vector3.UP
	_city._add_tilted_box((a + b) * 0.5, Basis.looking_at(axis, up), Vector3(width, depth, a.distance_to(b) + 0.07), finish, solid)


func _strip(road: Route, a: float, b: float, left: float, right: float, finish: String, lift := 0.032) -> void:
	var polygon := PackedVector2Array([road.offset_at(a, left), road.offset_at(b, left), road.offset_at(b, right), road.offset_at(a, right)])
	if (polygon[1] - polygon[0]).cross(polygon[2] - polygon[0]) < 0.0:
		polygon.reverse()
	_ground.patch_polygon(polygon, finish, lift)
