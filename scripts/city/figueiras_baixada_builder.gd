extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Baixada = Layout.Baixada
const Route = Layout.Route
const Paint = preload("res://scripts/city/figueiras_scenic_builder.gd")
const BRICK := "res://assets/textures/figueiras/tijolo-da-fabrica.png"
const CONCRETE := "res://assets/textures/figueiras/concreto-da-usina.png"
const PLASTER = preload("res://assets/shaders/figueiras/plaster.gdshader")
const HOME_WALLS := ["cream", "terracotta", "sage", "blue", "plaster", "brick"]
const BRIDGE_MATERIAL := "baixada_green_steel"
const INDUSTRIAL_BRICK := "baixada_brick"
const STEEL_PALETTE := {
	"baixada_green_steel": "416561",
	"baixada_oxide": "8d4a35",
	"baixada_galvanized": "797e79",
}

var _city: RefCounted
var _ground: RefCounted
var _paint := Paint.new()
var _lots := 0


func build(city: RefCounted, ground: RefCounted) -> void:
	_city = city
	_ground = ground
	_paint._city = city
	_paint._ground = ground
	_materials()
	var roads := Layout.district_routes()
	var avenue := roads[Baixada.AVENIDA]
	var canal := roads[Baixada.CANAL]
	var factory := roads[Baixada.FABRICA]
	var crossing := roads[Baixada.TRAVESSA]
	var vale := Layout.scenic_routes()[2]
	_loading_lane(crossing)
	for road in roads:
		_street(road, road == avenue)
	for road in Layout.district_bridges():
		_bridge(road, Layout.district_bridges()[road], road == avenue)
	_industrial(factory, crossing)
	_neighborhood(avenue, canal)
	_riverside(avenue, canal)
	_wooded_edges()
	_gateway(vale, avenue)
	_city.scene_root.set_meta("baixada_buildings", _lots)
	var length := 0.0
	for road in roads:
		length += road.length
	_city.scene_root.set_meta("baixada_road_length", length)
	_paint._city = null
	_paint._ground = null
	_city = null
	_ground = null


func _materials() -> void:
	for label: String in STEEL_PALETTE:
		var steel := StandardMaterial3D.new()
		steel.resource_name = label
		steel.albedo_color = Color(STEEL_PALETTE[label])
		steel.roughness = 0.74
		_city.materials[label] = steel
	var brick: StandardMaterial3D = _city.materials.brick.duplicate()
	brick.resource_name = INDUSTRIAL_BRICK
	brick.albedo_texture = load(BRICK)
	_city.materials[INDUSTRIAL_BRICK] = brick
	var visual := ShaderMaterial.new()
	visual.shader = PLASTER
	visual.resource_name = "figueiras_wall_brick_baixada"
	visual.set_shader_parameter("wall_color", Color("ded4c4"))
	visual.set_shader_parameter("color_texture", brick.albedo_texture)
	visual.set_shader_parameter("normal_texture", brick.normal_texture)
	visual.set_shader_parameter("masonry", true)
	visual.set_shader_parameter("masonry_repeat", Vector2(0.3125, 0.3125))
	_city._object_finishes[INDUSTRIAL_BRICK] = visual

	var loading: StandardMaterial3D = _city.materials.paving.duplicate()
	loading.resource_name = "loading_concrete"
	loading.albedo_color = Color("a8a9a1")
	loading.albedo_texture = load(CONCRETE)
	loading.normal_texture = preload("res://assets/textures/race/concrete_normal.png")
	_city.materials.loading_concrete = loading
	var finish: ShaderMaterial = _city._surface_finishes.paving.duplicate()
	finish.resource_name = "figueiras_surface_loading_concrete"
	finish.set_shader_parameter("base_color", loading.albedo_texture)
	finish.set_shader_parameter("aggregate_normal", loading.normal_texture)
	finish.set_shader_parameter("tint", loading.albedo_color)
	_city._surface_finishes.loading_concrete = finish

	var stack := CylinderMesh.new()
	stack.top_radius = 0.37
	stack.bottom_radius = 0.51
	stack.height = 1.0
	stack.radial_segments = 20
	stack.rings = 1
	_city.meshes["baixada_stack"] = stack


func _street(road: Route, arterial: bool) -> void:
	var start := 15
	var end := floori(road.length) - 15
	for station in range(start, end, 8):
		if Baixada.near_junction(road, station + 4.0, 13.0):
			continue
		var finish := minf(station + 7.96, end)
		if arterial:
			_paint._stripe(road, station, finish, -0.21, -0.09, "yellow", 0.036)
			_paint._stripe(road, station, finish, 0.09, 0.21, "yellow", 0.036)
		else:
			_paint._stripe(road, station, minf(station + 3.6, end), -0.06, 0.06, "yellow", 0.036)
		for side: float in [-1, 1]:
			var edge := side * (road.half_width - 0.39)
			if arterial:
				_paint._stripe(road, station, minf(station + 4.4, end), side * 3.42 - 0.052, side * 3.42 + 0.052, "white", 0.036)
			_paint._stripe(road, station, finish, edge - 0.064, edge + 0.064, "white", 0.036)
	for station in range(33, end - 15, 37 if arterial else 28):
		if Baixada.near_junction(road, station, 16.0):
			continue
		var bridges := Layout.district_bridges()
		if bridges.has(road) and absf(station - bridges[road]) < Baixada.BRIDGE_HALF_SPAN + 7.0:
			continue
		var side := 1.0 if station % 2 else -1.0
		var foot := road.offset_at(station, side * (road.half_width + 2.55))
		if Layout.road_distance(foot) > 1.7:
			_city._lamp(foot, -road.direction_at(station).orthogonal() * side)
	for station in Baixada.junctions(road):
		_junction_sign(road, station)


func _junction_sign(road: Route, at: float) -> void:
	var roads := Layout.district_routes()
	for branch in roads:
		if branch == road:
			continue
		var knot := road.point_at(at)
		var first := branch.points[0].distance_to(knot)
		var last := branch.points[-1].distance_to(knot)
		if minf(first, last) > 0.6:
			continue
		var along := branch.direction_at(6) if first < last else -branch.direction_at(branch.length - 6.0)
		var side := signf(along.dot(road.direction_at(at).orthogonal()))
		for travel: float in [-1.0, 1.0]:
			var station := at - travel * 26.0
			if station < 5.0 or station > road.length - 5.0:
				continue
			var arrow := "›" if travel * side < 0.0 else "‹"
			_sign(road.offset_at(station, -travel * (road.half_width + 2.10)),
				-road.direction_at(station) * travel, "%s  %s" % [branch.title.to_upper(), arrow], 4.72)
		break


func _sign(site: Vector2, face: Vector2, title: String, width: float) -> void:
	var yaw := atan2(face.x, face.y)
	var origin: Vector3 = _ground.surface_point(site)
	_city.add_part(origin, Vector3(0, 1.28, 0), Vector3(0.15, 2.56, 0.15), "baixada_galvanized", yaw)
	_city.add_part(origin, Vector3(0, 2.31, 0), Vector3(width + 0.10, 0.64, 0.13), "parapet", yaw)
	_city.add_part(origin, Vector3(0, 2.31, 0.08), Vector3(width, 0.55, 0.060), "sign_ink", yaw)
	var text := origin + Vector3(face.x * 0.12, 2.31, face.y * 0.12)
	_city.add_label(title, text, yaw, 0.0091)


func _loading_lane(road: Route) -> void:
	_paint._stripe(road, Baixada.LOADING_START, Baixada.LOADING_END, -3.96, 3.96, "loading_concrete", 0.018)
	for station in [Baixada.LOADING_START + 1.9, Baixada.LOADING_END - 1.9]:
		for side: float in [-1, 1]:
			for stripe in 4:
				var edge := side * (3.68 - stripe * 0.29)
				_paint._stripe(road, station + stripe * 0.21, station + stripe * 0.21 + 0.18,
					edge - 0.15, edge + 0.15, "yellow", 0.039)


func _bridge(road: Route, station: float, truss: bool) -> void:
	var span := Baixada.BRIDGE_HALF_SPAN
	var side_offset := road.half_width - 0.30
	for side: float in [-1, 1]:
		var offset := side * side_offset
		var feet := PackedVector3Array()
		var crowns := PackedVector3Array()
		for index in 7:
			var along := station - span + index * span / 3.0
			var foot := Layout.surface_point(road.offset_at(along, offset))
			feet.append(foot)
			crowns.append(foot + Vector3.UP * (5.85 if truss else 1.14))
		for index in feet.size() - 1:
			var a := feet[index]
			var b := feet[index + 1]
			_beam(a - Vector3.UP * 0.34, b - Vector3.UP * 0.34, 0.77, "baixada_galvanized")
			_beam(a + Vector3.UP * 0.87, b + Vector3.UP * 0.87, 0.18, BRIDGE_MATERIAL, true)
			_beam(a + Vector3.UP * 0.19, b + Vector3.UP * 0.19, 0.33, "gallery_concrete", true)
			_beam(a, crowns[index], 0.29, BRIDGE_MATERIAL)
			if truss:
				_beam(crowns[index], crowns[index + 1], 0.31, BRIDGE_MATERIAL)
				_beam(crowns[index] if index < 3 else a, b if index < 3 else crowns[index + 1],
					0.23, BRIDGE_MATERIAL)
				var along := station - span + index * span / 3.0
				var tangent := road.direction_at(along)
				var yaw := atan2(tangent.x, tangent.y)
				var facing := tangent.orthogonal() * side
				_city.add_box(a + Vector3(facing.x * 0.11, 0.97, facing.y * 0.11),
					Vector3(0.15, 0.39, 0.68), "baixada_galvanized", false, yaw)
		_beam(feet[-1], crowns[-1], 0.29, BRIDGE_MATERIAL)
	for index in range(1, 6):
		var along := station - span + index * span / 3.0
		_beam(Layout.surface_point(road.offset_at(along, side_offset), -0.48),
			Layout.surface_point(road.offset_at(along, -side_offset), -0.48), 0.45, "baixada_galvanized")
		if truss and index % 2 == 1:
			_beam(Layout.surface_point(road.offset_at(along, side_offset), 5.84),
				Layout.surface_point(road.offset_at(along, -side_offset), 5.84), 0.20, BRIDGE_MATERIAL)
	for side: float in [-1, 1]:
		var along := station + side * (span - 1.65)
		var face := road.direction_at(along) * side
		var center := Layout.surface_point(road.point_at(along))
		var bottom := Layout.CREEK_WATER_LEVEL - 1.05
		_city.add_box(Vector3(center.x, (center.y + bottom - 0.7) * 0.5, center.z),
			Vector3(road.half_width * 1.98, center.y - bottom - 0.7, 2.15), "gallery_concrete", false, atan2(face.x, face.y))
		if truss:
			_beam(Layout.surface_point(road.offset_at(along, side_offset), 5.78),
				Layout.surface_point(road.offset_at(along, -side_offset), 5.78), 0.29, BRIDGE_MATERIAL)
		_sign(road.offset_at(along + side * 10.5, side * (road.half_width + 1.85)),
			face, "PONTE DA BAIXADA" if truss else "PONTE DA USINA", 3.75)


func _beam(start: Vector3, finish: Vector3, size: float, material: String, solid := false) -> void:
	var axis := finish - start
	var up := Vector3.FORWARD if absf(axis.normalized().y) > 0.95 else Vector3.UP
	_city._add_tilted_box((start + finish) * 0.5, Basis.looking_at(axis, up),
		Vector3(size, size, axis.length() + 0.03), material, solid)


func _industrial(factory: Route, crossing: Route) -> void:
	# The roof sequence, red brick and hydraulic tower identify the block
	# from both exits. On the inside the loading canopy compresses the view.
	_warehouse(Vector2(-177, 426), PI, 41.0, 31.0, 7.2, 4, "FIAÇÃO DO ARROIO")
	_warehouse(Vector2(-148, 455), PI * 0.5, 22.0, 22.0, 5.6, 2, "EXPEDIÇÃO")
	_warehouse(Vector2(-157, 363), 0.0, 57.0, 32.0, 6.7, 5, "COOPERATIVA")
	_warehouse(Vector2(-182, 477), PI * 0.5, 32.0, 29.0, 6.0, 3, "ARMAZÉM 02")
	_warehouse(Vector2(-86, 445), -PI * 0.65, 18.0, 19.0, 5.9, 2, "CASA DE FORÇA")
	_warehouse(Vector2(-89, 385), 0.0, 25.0, 24.0, 5.2, 2, "OFICINA DA USINA")
	var dock := 31.0
	var dock_forward := crossing.direction_at(dock).orthogonal()
	_warehouse(crossing.offset_at(dock, -12.85), atan2(dock_forward.x, dock_forward.y), 26.6, 10.6, 6.2, 3, "ALMOXARIFADO")
	_landmark_tower()
	for station in [18.0, 28.0, 38.0, 48.0]:
		var direction := crossing.direction_at(station)
		var a: Vector3 = _ground.surface_point(crossing.offset_at(station, -5.83))
		var b: Vector3 = _ground.surface_point(crossing.offset_at(station, 5.83))
		var top := maxf(a.y, b.y) + 4.40
		var cross_a := Vector3(a.x, top, a.z)
		var cross_b := Vector3(b.x, top, b.z)
		_beam(a, cross_a, 0.30, "baixada_oxide", true)
		_beam(b, cross_b, 0.30, "baixada_oxide", true)
		_beam(cross_a, cross_b, 0.30, "baixada_oxide")
		var yaw := atan2(direction.x, direction.y)
		var site: Vector3 = _ground.surface_point(crossing.point_at(station))
		_city.add_box(Vector3(site.x, top + 0.25, site.z), Vector3(12.70, 0.18, 10.3), "baixada_galvanized", false, yaw)
		for offset: float in [-3.8, 3.8]:
			_city.add_part(Vector3(site.x, top + 0.14, site.z), Vector3(offset, 0.0, 0.0),
				Vector3(0.094, 0.14, 10.32), BRIDGE_MATERIAL, yaw)
			var column := cross_a if offset < 0.0 else cross_b
			_beam(column - Vector3.UP * 1.02, column.lerp((cross_a + cross_b) * 0.5, 0.19), 0.14, BRIDGE_MATERIAL)
		var marker := Marker3D.new()
		marker.name = "MarketLight_Baixada_%d" % int(station)
		marker.position = Vector3(site.x, top - 0.41, site.z)
		_city.scene_root.add_child(marker)
		_city.add_box(marker.position + Vector3.UP * 0.19, Vector3(1.4, 0.09, 0.25), "gallery_lamp", false, yaw, false)
	_sign(factory.offset_at(31.0, 7.4), -factory.direction_at(31.0), "FIAÇÃO DO ARROIO", 4.90)


func _warehouse(site: Vector2, yaw: float, width: float, depth: float, height: float, bays: int, title: String) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var facing := Vector2(basis.z.x, basis.z.z)
	var across := Vector2(basis.x.x, basis.x.z)
	for column: float in [-0.53, 0, 0.53]:
		for row: float in [-0.54, 0, 0.54]:
			if Layout.road_distance(site + across * column * width + facing * row * depth) < 2.05:
				return
	var origin: Vector3 = _ground.surface_point(site)
	var rim := depth * 0.5
	var low := origin.y
	for side: float in [-1, 1]:
		for end: float in [-1, 1]:
			low = minf(low, _ground.surface_point(site + across * side * width * 0.5 + facing * end * rim).y)
	var foundation := maxf(0.48, origin.y - low + 0.55)
	_city.add_part(origin, Vector3(0, -foundation * 0.47 + 0.12, 0), Vector3(width + 0.2, foundation, depth + 0.2), "gallery_concrete", yaw, true)
	_city._masonry_wall(origin, Vector3(width, height, depth), INDUSTRIAL_BRICK, yaw)
	_city.add_part(origin, Vector3(0, 0.8, rim + 0.14), Vector3(width, 1.65, 0.29), "gallery_concrete", yaw)
	var bay := width / bays
	for index in bays:
		var x := (index + 0.5) * bay - width * 0.5
		_city.add_part(origin, Vector3(x, height + 1.07, 0), Vector3(bay + 0.30, 2.14, depth + 0.65),
			"roof_gray", yaw, false, "shed_roof")
		_city.add_part(origin, Vector3(x + bay * 0.38, height + 0.39, rim + 0.10), Vector3(bay * 0.19, 0.91, 0.39), "baixada_galvanized", yaw)
		_city.add_part(origin, Vector3(x - bay * 0.5, height * 0.5, rim + 0.15), Vector3(0.48, height, 0.39), INDUSTRIAL_BRICK, yaw)
		_city._window(origin, Vector3(x, height - 1.50, rim + 0.044), Vector2(bay * 0.68, 1.68), yaw,
			"residential_glass_lit" if index % 3 == 0 else "glass", "iron")
		if index % 2 == 0:
			_city._garage_shutter(origin, Vector3(x, 1.46, rim + 0.20), bay * 0.49, yaw)
			_city.add_part(origin, Vector3(x, 3.0, rim + 0.85), Vector3(bay * 0.7, 0.23, 1.70), "baixada_oxide", yaw)
	for side: float in [-1.0, 1.0]:
		for unit in floori(depth / 4.4):
			var z := (unit + 0.80) * 4.4 - rim
			_city._window(origin + basis * Vector3(side * (width * 0.5 + 0.03), height - 1.50, z),
				Vector3.ZERO, Vector2(2.69, 1.52), yaw + side * PI * 0.5, "glass", "iron")
	var sign := Vector3(0, height - 3.05, rim + 0.26)
	_city.add_part(origin, sign, Vector3(minf(width * 0.61, 9.64), 0.72, 0.20), "sign_ink", yaw)
	_city.add_label(title, origin + basis * (sign + Vector3.FORWARD * -0.125), yaw, 0.014)
	var footprint := across.abs() * width + facing.abs() * depth + Vector2.ONE * 6.0
	_ground.patch(Rect2(site - footprint * 0.5, footprint), "shade_building", 0.023)
	_city._masonry.finish_lot()
	_city._lots += 1
	_lots += 1


func _landmark_tower() -> void:
	var tower: Vector3 = _ground.surface_point(Baixada.WATER_TOWER)
	for side: float in [-1.0, 1.0]:
		for depth: float in [-1.0, 1.0]:
			var offset := Vector3(side * 2.47, 0, depth * 2.47)
			var foot: Vector3 = _ground.surface_point(Baixada.WATER_TOWER + Vector2(offset.x, offset.z))
			var head := tower + Vector3.UP * 14.30 + offset * 0.87
			_beam(foot, head, 0.36, BRIDGE_MATERIAL, true)
			for index in 3:
				var a := foot.lerp(head, (index + 0.0) / 3.0)
				var b := foot.lerp(head, (index + 1.0) / 3.0) - Vector3(side * 4.50, 0, 0)
				_beam(a, b, 0.19, BRIDGE_MATERIAL)
	_city.add_instance("cylinder", "baixada_galvanized", tower + Vector3.UP * 16.95, Vector3(3.3, 5.45, 3.3))
	for y: float in [14.38, 17.02, 19.67]:
		_city.add_instance("cylinder", BRIDGE_MATERIAL, tower + Vector3.UP * y, Vector3(3.49, 0.16, 3.49))
	_city.add_label("FIAÇÃO", tower + Vector3(-3.37, 17.08, 0.0), -PI * 0.5, 0.030)
	var chimney_site := Vector2(-183, 444)
	var chimney: Vector3 = _ground.surface_point(chimney_site)
	_city.add_instance("baixada_stack", INDUSTRIAL_BRICK, chimney + Vector3.UP * 15.9, Vector3(4.8, 31.8, 4.8))
	_city.add_instance("cylinder", "baixada_oxide", chimney + Vector3.UP * 31.85, Vector3(1.97, 0.33, 1.97))
	_city.add_collision(chimney + Vector3.UP * 7.5, Vector3(3.2, 15.0, 3.2))


func _neighborhood(avenue: Route, canal: Route) -> void:
	var avenue_start := avenue.project(Vector2(5.0, 525.0)).x
	var avenue_end := avenue.project(Vector2(234.0, 466.0)).x
	for station in range(ceili(avenue_start), floori(avenue_end), 14):
		for side: float in [-1, 1]:
			if Baixada.near_junction(avenue, station, 20.0):
				continue
			_house(avenue, float(station) + side * 1.7, side, station % 4 == 0)
	for station in range(35, floori(canal.length) - 26, 14):
		if not Baixada.near_junction(canal, station, 23.0):
			_house(canal, station, 1.0, station % 3 == 0)
	var hill := avenue.project(Vector2(241.0, 373.0)).x
	for station in range(roundi(hill - 74.0), roundi(hill + 30.0), 16):
		_house(avenue, station, -1.0, true)
	for station in range(ceili(avenue_start + 15.0), floori(avenue_end - 5.0), 27):
		for side: float in [-1.0, 1.0]:
			if not Baixada.near_junction(avenue, station, 15.0):
				_street_tree(avenue, station + side * 5.0, side)
	for station in range(65, floori(canal.length) - 26, 30):
		if not Baixada.near_junction(canal, station, 17.0):
			_street_tree(canal, station, -1.0)
	_hillside_homes(avenue, avenue_start, avenue_end)


func _street_tree(road: Route, station: float, side: float) -> void:
	var curb := road.offset_at(station, side * (road.half_width + 1.80))
	if Layout.road_distance(curb) < 1.6:
		return
	_ground.patch(Rect2(curb - Vector2(0.79, 0.79), Vector2(1.58, 1.58)), "mulch", 0.029)
	_city._tree(curb, 6.2 + 1.9 * absf(sin(station * 0.121)), int(station) % 4, true, true)


func _hillside_homes(road: Route, start: float, end: float) -> void:
	for station in range(ceili(start + 32.0), floori(end - 8.0), 19):
		var outward := road.direction_at(station).orthogonal() * -1.0
		var face := -outward
		var setback := 32.0 + cos(station * 0.091) * 3.6
		var plot := road.point_at(station) + outward * setback
		if Layout.road_distance(plot) < 13.0 or Layout.creek_weight(plot) > 0.17:
			continue
		var width := 10.3 + cos(station * 0.49) * 1.5
		var front := plot + face * 8.0
		var wall: String = HOME_WALLS[_lots % HOME_WALLS.size()]
		var profile: int = [2, 0, 3, 2, 4][posmod(floori(station / 19.0), 5)]
		_city._facade(plot, front, atan2(face.x, face.y), width, 2 if station % 3 else 3,
			13.2, wall, "", profile)
		_lots += 1


func _house(road: Route, station: float, side: float, two_stories: bool) -> void:
	var forward := -road.direction_at(station).orthogonal() * side
	var across := Vector2(forward.y, -forward.x)
	var curb := road.offset_at(station, side * (road.half_width + 2.57))
	var depth := 10.65 + sin(station * 0.38) * 1.27
	var site := curb - forward * (depth * 0.5 + 3.0)
	if Layout.creek_weight(site) > 0.14:
		return
	var width := 10.08 + 1.24 * cos(station * 0.22)
	for edge: float in [-0.60, 0, 0.60]:
		var corner := curb + across * edge * width
		if Layout.road_distance(corner) < 1.48 or Layout.road_distance(corner - forward * (depth + 4.0)) < 3.0:
			return
	var index := _lots % HOME_WALLS.size()
	var shop := "PADARIA DO ARROIO" if _lots % 14 == 0 else ""
	_city._facade(site, curb, atan2(forward.x, forward.y), width, 2 if two_stories else 1, depth, HOME_WALLS[index], shop, (index + 1) % 5)
	if _lots % 4 == 1:
		_city._tree(curb - forward * 1.0 + across * width * 0.56, 6.9, 1)
	_lots += 1


func _riverside(avenue: Route, canal: Route) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1732
	for index in 94:
		var z := rng.randf_range(335.0, 604.0)
		var side := -1.0 if index % 2 == 0 else 1.0
		var site := Vector2(Layout.creek_axis(z) + side * rng.randf_range(10.0, 23.0), z)
		if Layout.road_distance(site) < 4.6:
			continue
		if index % 3 == 0:
			_city._tree(site, rng.randf_range(4.3, 8.7), 3 if index % 4 else 0, false, false)
		_city._garden(site, 2.25, 6)
	for station in [51.0, 81.0, 147.0, 182.0]:
		var foot := canal.offset_at(station, -canal.half_width - 4.3)
		if Layout.road_distance(foot) > 3.4:
			var axis := canal.direction_at(station)
			_city._bench(foot, atan2(axis.x, axis.y) + PI * 0.5)
			_city._park_lantern(foot + axis * 2.0)
	for station in [avenue.length * 0.29, avenue.length * 0.65, avenue.length * 0.83]:
		var site := avenue.offset_at(station, 10.3)
		if Layout.road_distance(site) > 2.6:
			_city._bus_stop(site, 1.0)


func _wooded_edges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11932
	var groves := [
		[Vector2(-278, 467), Vector2(50, 91), 64],
		[Vector2(-187, 586), Vector2(109, 40), 104],
		[Vector2(111, 588), Vector2(136, 51), 124],
		[Vector2(271, 521), Vector2(82, 69), 88],
		[Vector2(335, 393), Vector2(64, 65), 83],
		[Vector2(373, 248), Vector2(49, 83), 69],
		[Vector2(384, -30), Vector2(42, 103), 79],
		[Vector2(-308, 534), Vector2(45, 82), 72],
		[Vector2(305, 581), Vector2(71, 53), 64],
	]
	for grove: Array in groves:
		for index in grove[2]:
			var site: Vector2 = grove[0] + Vector2.from_angle(rng.randf() * TAU) * grove[1] * sqrt(rng.randf())
			if not Layout.TERRAIN.has_point(site) or Layout.road_distance(site) < 27.5 or Layout.creek_weight(site) > 0.21:
				continue
			var cover := Layout.canopy_cover(site)
			var height := rng.randf_range(4.9, 10.7) * lerpf(0.82, 1.16, cover)
			var pose: Vector3 = _ground.surface_point(site, -0.045)
			var canopy := Vector3(height * rng.randf_range(0.71, 0.99), height, height * 0.91)
			_city.add_instance("horizon_tree", "forest", pose, canopy, rng.randf() * TAU, false)


func _gateway(vale: Route, avenue: Route) -> void:
	for junction in Baixada.junctions(vale):
		_junction_sign(vale, junction)
	for station in [37.0, avenue.length - 34.0]:
		var travel := 1.0 if station < avenue.length * 0.5 else -1.0
		_sign(avenue.offset_at(station, -travel * (avenue.half_width + 2.22)), -avenue.direction_at(station) * travel,
			"BAIXADA DO ARROIO", 4.85)
	_sign(Vector2(189.0, Layout.AVENUE + Layout.AVENUE_HALF + 3.0), Vector2.LEFT,
		"VALE  ·  BAIXADA  ›", 4.45)
