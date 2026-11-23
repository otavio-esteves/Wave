extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Route = preload("res://scripts/city/figueiras_route.gd")
const GNEISS = preload("res://assets/textures/figueiras/gnaisse-vale.png")
const PAVEMENT = preload("res://assets/textures/figueiras/pedra-do-horto.png")
const MURAL_ASSET := "res://assets/textures/figueiras/azulejos-do-horto.png"
var _city: RefCounted
var _ground: RefCounted


func build(city: RefCounted, ground: RefCounted) -> void:
	_city = city
	_ground = ground
	var tile := StandardMaterial3D.new()
	tile.resource_name = "horto_azulejos"
	tile.albedo_texture = load(MURAL_ASSET)
	tile.roughness = 0.57
	_city.materials["horto_azulejos"] = tile
	var cut := StandardMaterial3D.new()
	cut.resource_name = "horto_gneiss"
	cut.albedo_color = Color("a39989")
	cut.albedo_texture = GNEISS
	cut.roughness = 0.96
	_city.materials["horto_gneiss"] = cut
	var pavement := StandardMaterial3D.new()
	pavement.resource_name = "horto_paving"
	pavement.albedo_texture = PAVEMENT
	pavement.albedo_color = Color("c3c0b4")
	pavement.roughness = 0.87
	pavement.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_city.materials["horto_paving"] = pavement
	var road := Layout.urban_routes()[Layout.HORTO_ROUTE]
	_road_details(road)
	_wayfinding()
	_square(road)
	var stops: Array[float] = [43.0, 63.0, 85.0, 107.0, road.length - 55.0, road.length - 35.0]
	for index in stops.size():
		_house(road, stops[index], index)
	_city.scene_root.set_meta("horto_length", road.length)
	_city.scene_root.set_meta("horto_station", road.stop_station)
	_city = null
	_ground = null


func _wayfinding() -> void:
	for exit_z: float in [-54.0, -176.0]:
		var foot := Layout.surface_point(Vector2(-200.7, exit_z + 12.4))
		_city.add_box(foot + Vector3.UP * 1.26, Vector3(0.11, 2.55, 0.10), "steel_plate")
		var panel := foot + Vector3.UP * 2.33
		_city.add_box(panel, Vector3(4.3, 0.53, 0.12), "awning_green")
		_city.add_label("←  HORTO", panel + Vector3.BACK * 0.067, 0.0, 0.014)
		_city.add_label("HORTO  →", panel + Vector3.FORWARD * 0.067, PI, 0.014)


func _road_details(road: Route) -> void:
	for station in range(16, floori(road.length) - 17, 6):
		_strip(road, station, station + 3.1, -0.065, 0.065, "yellow")
		for side: float in [-1.0, 1.0]:
			if Layout.passo_junction_near(road, station + 3.0, 23.0):
				continue
			if side < 0.0 and absf(station - road.stop_station) < 29.0:
				continue
			var edge := side * (road.half_width - 0.32)
			_strip(road, station, station + 6.0, edge - 0.053, edge + 0.053, "white")
			if station % 18 == 16 and station > 20:
				var site := road.offset_at(station, side * (road.edge_at(station, side) + 1.52))
				var outward := road.direction_at(station).orthogonal() * side
				if side < 0.0 and station % 36 == 16:
					_city._lamp(site, -outward)
				else:
					_city._tree(site + outward * 0.87, 5.1 + sin(station * 0.17) * 1.35, 1 if station % 5 < 3 else 3, true, false)
	for station in range(roundi(road.length * 0.36), roundi(road.length * 0.74), 6):
		if Layout.passo_junction_near(road, station, 26.0):
			continue
		_retaining_wall(road, float(station), 6.0)
		var start := float(station) - 3.0
		var finish := float(station) + 3.0
		var bank := PackedVector2Array([
			road.offset_at(start, 7.38), road.offset_at(finish, 7.38),
			road.offset_at(finish, 13.1 + sin(finish * 0.10) * 2.6),
			road.offset_at(start, 13.1 + sin(start * 0.10) * 2.6)])
		if (bank[1] - bank[0]).cross(bank[2] - bank[0]) < 0.0:
			bank.reverse()
		_ground.patch_polygon(bank, "horto_gneiss", 0.021)


func _retaining_wall(road: Route, station: float, span: float) -> void:
	var a := road.offset_at(station - span * 0.5, 7.05)
	var b := road.offset_at(station + span * 0.5, 7.05)
	var height := lerpf(0.94, 2.65, absf(sin(station * 0.043)))
	var low := Layout.surface_point(a)
	var high := Layout.surface_point(b)
	var pose := Basis.looking_at((high - low).normalized())
	var foot := (low + high) * 0.5
	var length := low.distance_to(high) + 0.10
	_city._add_tilted_box(foot + pose.y * (height * 0.43 - 0.12), pose, Vector3(0.63, height * 0.86 + 0.28, length), "retaining_oxide", true)
	_city._add_tilted_box(foot + pose.y * (height * 0.84), pose, Vector3(0.78, 0.21, length), "parapet", false)
	_city.add_box(low + Vector3.UP * height * 0.37, Vector3(0.75, height * 1.06, 0.51), "stone", true)


func _strip(road: Route, start: float, end: float, left: float, right: float, material: String, lift := 0.031) -> void:
	var polygon := PackedVector2Array([road.offset_at(start, left), road.offset_at(end, left), road.offset_at(end, right), road.offset_at(start, right)])
	if (polygon[1] - polygon[0]).cross(polygon[2] - polygon[0]) < 0.0:
		polygon.reverse()
	_ground.patch_polygon(polygon, material, lift)


func _square(road: Route) -> void:
	var station := road.stop_station
	for offset in range(-26, 26, 2):
		_strip(road, station + offset, station + offset + 2.0, -17.2, -6.55, "horto_paving", 0.024)
	for slot: float in [-2.0, 0.0, 2.0, 4.0]:
		var marker := station + slot * 1.35
		_strip(road, marker - 0.047, marker + 0.047, -15.05, -11.6, "white", 0.033)
	for offset: float in [-21, 21]:
		var site := road.offset_at(station + offset, -14.82)
		_city._garden(site, 2.0, 14)
		_city._park_lantern(site)
		_city._bench(road.offset_at(station + offset * 0.76, -16.25), -road.direction_at(station).angle())
	_pavilion(road, station)
	_viewing_rail(road, station + 16.0, station + 29.0)
	_viewing_rail(road, station - 29.0, station - 15.0)
	var sign_site := road.offset_at(station - 24.4, -16.0)
	var facing := road.direction_at(station - 22.0)
	var yaw := atan2(facing.x, facing.y)
	var sign := Layout.surface_point(sign_site)
	_city.add_part(sign, Vector3(0, 0.89, 0), Vector3(0.15, 1.78, 0.16), "wood", yaw, true)
	_city.add_part(sign, Vector3(0, 1.65, 0), Vector3(5.68, 0.49, 0.18), "awning_green", yaw)
	_city.add_label("HORTO MUNICIPAL", sign + Basis(Vector3.UP, yaw) * Vector3(0, 1.66, 0.105), yaw, 0.012)


func _viewing_rail(road: Route, start: float, end: float) -> void:
	var last := road.offset_at(start, -17.52)
	for distance in range(ceili(start) + 3, floori(end), 3):
		var next := road.offset_at(float(distance), -17.52)
		_city._rail(last, next, 0.52, 0.27, "stone", true)
		_city._rail(last, next, 1.08, 0.11, "steel_plate", true)
		_city.add_box(Layout.surface_point(next, 0.69), Vector3(0.18, 1.4, 0.16), "steel_plate", true)
		last = next


func _pavilion(road: Route, station: float) -> void:
	var inward := road.direction_at(station).orthogonal()
	var yaw := atan2(inward.x, inward.y)
	var site := road.offset_at(station, -22.2)
	var floor := Layout.surface_point(site, 0.57)
	var frame := Basis(Vector3.UP, yaw)
	_city.add_part(floor, Vector3(0, -1.24, -1.25), Vector3(18.0, 2.51, 8.5), "stone", yaw, true)
	_city.add_part(floor, Vector3(0, 1.51, -1.15), Vector3(17.6, 3.06, 5.5), "brick", yaw, true)
	_city.add_part(floor, Vector3(0, 3.07, -0.60), Vector3(18.7, 0.24, 8.24), "trim", yaw)
	_city.add_part(floor, Vector3(0, 3.82, -0.80), Vector3(19.0, 1.39, 8.0), "roof_gray", yaw, false, "hip_roof")
	_city.add_part(floor, Vector3(0, 2.72, 2.15), Vector3(18.4, 0.12, 3.32), "awning_green", yaw)
	for index in 4:
		var x := (float(index) - 1.5) * 5.59
		_city.add_part(floor, Vector3(x, 1.28, 3.56), Vector3(0.21, 2.68, 0.21), "steel_plate", yaw, true)
		_city.add_part(floor, Vector3(x, 0.18, 3.56), Vector3(0.40, 0.36, 0.41), "stone", yaw)
	for index in 3:
		var x := (float(index) - 1.0) * 5.54
		if index == 1:
			_city.add_part(floor, Vector3(x, 1.59, 1.64), Vector3(5.24, 1.58, 0.12), "trim", yaw)
			_city.add_part(floor, Vector3(x, 1.59, 1.709), Vector3(5.03, 1.47, 1.0), "horto_azulejos", yaw, false, "pane")
		else:
			_city._window(floor, Vector3(x, 1.61, 1.61), Vector2(3.46, 1.39), yaw, "residential_glass_lit")
		_city.add_part(floor, Vector3(x, 2.59, 3.19), Vector3(0.58, 0.11, 0.27), "light", yaw)
	for step in 3:
		_city.add_part(floor, Vector3(0, -0.14 - step * 0.16, 3.65 + step * 0.39), Vector3(5.9, 0.27, 0.47), "stone", yaw, true)
	_city.add_label("CASA DAS SEMENTES", floor + frame * Vector3(0, 2.99, 3.64), yaw, 0.017)
	var marker := Marker3D.new()
	marker.name = "CasaDasSementes"
	marker.position = floor
	_city.scene_root.add_child(marker)


func _house(road: Route, station: float, index: int) -> void:
	var side := 1.0 if index < 4 and index % 2 == 0 else -1.0
	var across := road.direction_at(station).orthogonal() * side
	var frontage := road.offset_at(station, 7.4 * side)
	var site := road.offset_at(station, 15.4 * side)
	var facing := -across
	var yaw := atan2(facing.x, facing.y)
	var finish: String = ["plaster", "sage", "terracotta", "blue", "cream", "brick"][index]
	_city._facade(site, frontage, yaw, 9.4 + index % 2 * 1.85, 1 if index % 3 == 0 else 2, 9.4, finish, "")
	var garden := road.offset_at(station + 4.0, 8.8 * side)
	_city._garden(garden, 1.65, 10)
