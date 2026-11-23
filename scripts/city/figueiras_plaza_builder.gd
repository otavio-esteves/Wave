extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Parts = preload("res://scripts/city/figueiras_building_parts.gd")
const Openings = preload("res://scripts/city/figueiras_openings.gd")
const COVER := Vector2(22.0, 45.0)

var _city: RefCounted
var _ground: RefCounted


func build(city: RefCounted, ground: RefCounted) -> void:
	_city = city
	_ground = ground
	var route := Layout.urban_routes()[Layout.GALERIA_ROUTE]
	_gallery(route)
	_reading_garden()
	_bandstand(Vector2(31.0, -21.0))
	_fountain_court(Vector2(3.0, 20.0))
	_ground.patch(Rect2(-8, -36, 5.8, 78.0), "cobbles", 0.034)
	_ground.patch(Rect2(-34.0, -9.9, 82.2, 5.75), "paving", 0.042)
	_ground.patch(Rect2(41.8, -32, 4.3, 68.0), "paving", 0.034)
	_ground.patch(Rect2(-31, -34.0, 67, 3.9), "paving", 0.032)
	for point: Vector2 in [Vector2(-7, 31), Vector2(23, 29), Vector2(39, 23), Vector2(42, -12), Vector2(7, -31)]:
		_city._park_lantern(point)
	for island: Vector2 in [Vector2(-21.0, 29.7), Vector2(17.0, 32.3), Vector2(28.9, 15.2)]:
		_court_island(island)
	_tree_row()
	_sign(Vector2(17.0, 36.0))
	_city.scene_root.set_meta("civic_passage_length", route.length)
	_city.scene_root.set_meta("civic_cover_length", COVER.y - COVER.x)


func _gallery(route: RefCounted) -> void:
	var station := (COVER.x + COVER.y) * 0.5
	var site: Vector2 = route.point_at(station)
	var direction: Vector2 = route.direction_at(station)
	var frame := Basis(Vector3.UP, atan2(direction.x, direction.y))
	var west := Vector2(maxf(site.x - 13.8, -54.3), site.y)
	var east: Vector2 = site + Vector2(12.5, 0)
	var deck := -INF
	for meter: float in [COVER.x - 0.8, station, COVER.y + 0.8]:
		for side: float in [-4.8, 4.8]:
			deck = maxf(deck, _ground.surface_point(route.offset_at(meter, side)).y)
	deck += 5.0
	var origin := Vector3(site.x, deck, site.y)
	var yaw := frame.get_euler().y
	_gallery_wing(west, Vector3(5.8, 5.7, 19.2), yaw, "terracotta", false)
	_gallery_wing(east, Vector3(9.7, 6.8, 21.8), yaw, "cream", true)
	var width := 19.5
	var depth := COVER.y - COVER.x
	_city.add_part(origin, Vector3(0, 0.27, 0), Vector3(width, 0.54, depth), "stone", yaw, true)
	_city.add_part(origin, Vector3(0, 3.28, 0), Vector3(width + 0.42, 0.26, depth + 0.66), "trim", yaw)
	_city.add_part(origin, Vector3(0, 4.12, 0), Vector3(width + 0.72, 1.75, depth + 0.93), "roof_gray", yaw, false, "hip_roof")
	for side: float in [-1.0, 1.0]:
		for offset: float in [-3.7, 3.7]:
			var base := origin + frame * Vector3(side * 8.9, 0, offset)
			_post(base, 0.74, yaw)
		_city.add_part(origin, Vector3(side * 9.5, 1.60, 0.0), Vector3(0.28, 2.80, depth), "plaster_dark", yaw)
		for bay in 5:
			var z := -9.1 + bay * 4.55
			_city._window(origin, Vector3(-side * z, 1.76, 9.7), Vector2(2.8, 1.62), yaw + side * PI * 0.5, "residential_glass_lit")
	for sign: float in [-1.0, 1.0]:
		var portal := origin + frame * Vector3(0, -2.70, sign * (depth * 0.5 + 0.03))
		_city.add_instance("masonry_arch", "brick", portal, Vector3(15.70, 3.42, 0.78), yaw)
		_city.add_instance("masonry_arch", "stone", portal + frame.z * sign * 0.39, Vector3(15.49, 3.16, 0.16), yaw)
		for side: float in [-1.0, 1.0]:
			var stone := portal + frame.x * side * 8.59
			_post(stone, 0.93, yaw)
			_city.add_box(stone + Vector3.UP * 0.10, Vector3(1.08, 0.22, 0.99), "trim", false, yaw)
		_gallery_end(origin, sign, width, depth, yaw)
	for offset: float in [-7.2, -1.5, 4.8]:
		var lamp := origin + frame * Vector3(0, -0.11, offset)
		_city.add_part(lamp, Vector3.ZERO, Vector3(1.4, 0.14, 0.25), "light", yaw, false)
		_city._lamp_marker(lamp - Vector3.UP * 0.13)
	var marker := Marker3D.new()
	marker.name = "GaleriaDaPraca"
	marker.position = _ground.surface_point(site)
	_city.scene_root.add_child(marker)


func _gallery_end(origin: Vector3, sign: float, width: float, depth: float, yaw: float) -> void:
	var facing := yaw if sign > 0.0 else yaw + PI
	var frame := Basis(Vector3.UP, facing)
	var wall := depth * 0.5
	_city.add_part(origin, Vector3(0, 1.90, wall - 0.06), Vector3(width, 2.71, 0.32), "plaster", facing)
	_city.add_part(origin, Vector3(0, 0.74, wall + 0.14), Vector3(width, 0.18, 0.41), "stone", facing)
	for x: float in [-6.66, -3.33, 0.0, 3.33, 6.66]:
		_city._window(origin, Vector3(x, 1.79, wall + 0.105), Vector2(1.51, 1.49), facing, "glass", "timber")
	var label := origin + frame * Vector3(0, 2.84, wall + 0.109)
	Openings.lettering(_city, "GALERIA DA PRAÇA", label, facing, 4.36, 0.34, Color("3c4135"))


func _post(at: Vector3, width: float, yaw: float) -> void:
	var foot: Vector3 = _ground.surface_point(Vector2(at.x, at.z), -0.14)
	var height := at.y - foot.y
	_city.add_box(Vector3(at.x, foot.y + height * 0.50, at.z), Vector3(width, height, width), "brick", true, yaw)
	_city.add_box(foot + Vector3.UP * 0.33, Vector3(width + 0.22, 0.68, width + 0.2), "stone", false, yaw)


func _gallery_wing(site: Vector2, size: Vector3, yaw: float, finish: String, library: bool) -> void:
	var base := Parts.masonry_mass(_city, _ground, site, size, yaw, finish)
	var face := -size.z * 0.5
	var name := "BIBLIOTECA MUNICIPAL" if library else "ARQUIVO DA VILA"
	_city.add_part(base, Vector3(0, size.y + 0.72, 0), Vector3(size.x + 0.63, 1.50, size.z + 0.82), "roof", yaw, false, "hip_roof")
	_city.add_part(base, Vector3(0, size.y - 0.12, 0), Vector3(size.x + 0.36, 0.25, size.z + 0.36), "trim", yaw)
	_city.add_part(base, Vector3(0, 1.41, face - 0.075), Vector3(1.44, 2.82, 0.21), "door", yaw)
	var frame := Basis(Vector3.UP, yaw)
	Openings.lettering(_city, name, base + frame * Vector3(0, 3.36, face - 0.032), yaw + PI, size.x * 0.65, 0.28, Color("403b33"))
	var outward := Vector2(-frame.z.x, -frame.z.z)
	var entrance := site + outward * (-face + 0.18)
	_city._access(entrance + outward * 5.0, entrance, base.y, yaw + PI, 2.32)
	for sign: float in [-1.0, 1.0]:
		var x := sign * size.x * 0.31
		_city._window(base, Vector3(-x, 1.71, -face + 0.013), Vector2(size.x * 0.18, 1.62), yaw + PI, "residential_glass_lit", "timber")
		for bay in 4:
			var point := Vector3(-sign * (-1.5 + bay) * size.z * 0.20, 2.08, size.x * 0.5)
			_city._window(base, point, Vector2(1.52, 2.23), yaw + sign * PI * 0.5, "residential_glass_lit", "timber")
		_city.add_part(base, Vector3(x * 1.44, 2.55, face - 0.44), Vector3(0.27, 5.1, 0.35), "parapet", yaw)
	if library:
		var tower := base + Basis(Vector3.UP, yaw) * Vector3(size.x * -0.16, size.y, -size.z * 0.28)
		_city.add_box(tower + Vector3.UP * 2.21, Vector3(3.28, 4.42, 3.42), "plaster", false, yaw)
		_city.add_instance("hip_roof", "roof_gray", tower + Vector3.UP * 5.19, Vector3(3.92, 1.58, 4.01), yaw)
		for side: float in [-1.0, 1.0]:
			_city.add_part(tower, Vector3(side * 0.70, 2.93, -1.73), Vector3(0.35, 1.64, 0.10), "sign_ink", yaw)
			_city.add_part(tower, Vector3(side * 0.70, 2.93, 1.73), Vector3(0.35, 1.64, 0.10), "sign_ink", yaw)
	_city._lots += 1


func _reading_garden() -> void:
	var site := Vector2(-20.0, -18.0)
	_ground.patch(Rect2(-32.0, -24.0, 23.0, 19.0), "cobbles", 0.038)
	_ground.patch(Rect2(-28.4, -22.0, 14.0, 8.5), "mulch", 0.044)
	for x: float in [-27.0, -20.0, -13.0]:
		_city._bench(Vector2(x, -10.4), 0.0)
		_city._garden(Vector2(x, -18.7), 2.25, 16)
	_city._tree(site, 9.9, 2, true)
	_city._rail(Vector2(-31.0, -21.0), Vector2(-31.0, -12.0), 0.43, 0.60, "stone", true)
	_city._rail(Vector2(-31.0, -21.0), Vector2(-31.0, -12.0), 0.84, 0.10, "steel_plate")


func _fountain_court(site: Vector2) -> void:
	_ground.patch(Rect2(-11.0, 11.0, 45, 23.0), "paving", 0.043)
	_ground.patch(Rect2(-9.5, 16.0, 39.0, 7.8), "median_pavers", 0.050)
	var base: Vector3 = _ground.surface_point(site)
	_city.add_box(base + Vector3.UP * 0.24, Vector3(12.4, 0.55, 6.8), "stone", true)
	_city.add_box(base + Vector3.UP * 0.54, Vector3(11.8, 0.13, 6.22), "ceramic")
	_city.add_box(base + Vector3.UP * 0.63, Vector3(11.52, 0.04, 5.98), "water")
	for x: float in [-3.65, 0.0, 3.65]:
		var jet := base + Vector3(x, 0.83, 0)
		_city.add_instance("cylinder", "stone", jet, Vector3(0.18, 0.64, 0.18))
		_city.add_instance("cylinder", "water", jet + Vector3.UP * 0.24, Vector3(0.26, 0.022, 0.26))
	for x: float in [8.5, 17.0, 25.7]:
		_city._bench(Vector2(x, 29.3), PI)
		_city._garden(Vector2(x, 31.9), 1.7, 7)


func _court_island(site: Vector2) -> void:
	_ground.patch(Rect2(site - Vector2(3.78, 1.93), Vector2(7.56, 3.86)), "mulch", 0.049)
	for side: float in [-1.0, 1.0]:
		_city._rail(site + Vector2(-3.83, side * 1.92), site + Vector2(3.83, side * 1.92), 0.18, 0.46, "stone", true)
		_city._rail(site + Vector2(side * 3.82, -1.93), site + Vector2(side * 3.82, 1.93), 0.18, 0.46, "stone", true)
		_city._garden(site + Vector2(side * 2.18, 0.36), 1.46, 17)
	_city._tree(site, 7.6 + fposmod(site.x, 2.7), 1, true)


func _bandstand(site: Vector2) -> void:
	var base: Vector3 = _ground.surface_point(site)
	var foundation := Parts.floor_range(_ground, site, 10.0, 10.0, 0.0)
	base.y = foundation.y + 0.6
	var rear := site - Vector2(0, 5.0)
	_ground.patch(Rect2(site - Vector2(13.0, 11.0), Vector2(24.0, 21.0)), "cobbles", 0.034)
	var stage_center := base + Vector3.UP * (foundation.x - base.y) * 0.5
	var stage_height := base.y - foundation.x + 0.30
	_city.add_instance("bandstand_base", "stone", stage_center, Vector3(8.80, stage_height, 8.80))
	var support := CylinderShape3D.new()
	support.height = stage_height
	support.radius = 4.14
	var collider := CollisionShape3D.new()
	collider.name = "Coreto"
	collider.shape = support
	collider.position = stage_center
	_city._colliders.add_child(collider)
	_city.add_instance("bandstand_base", "ceramic", base + Vector3.UP * 0.08, Vector3(8.66, 0.20, 8.66))
	for index in 8:
		var angle := TAU * (index + 0.5) / 8.0
		var offset := Vector3(cos(angle) * 3.92, 0, sin(angle) * 3.92)
		_city.add_box(base + offset + Vector3.UP * 1.76, Vector3(0.28, 3.52, 0.27), "wood", false, -angle)
		_city.add_box(base + offset + Vector3.UP * 0.19, Vector3(0.42, 0.36, 0.42), "metal", false, -angle)
	_city.add_instance("bandstand_roof", "roof_gray", base + Vector3.UP * 4.58, Vector3(10.31, 2.28, 10.31))
	_city.add_instance("cylinder", "trim", base + Vector3.UP * 5.85, Vector3(0.11, 0.34, 0.11))
	_city._lamp_marker(base + Vector3.UP * 3.44)
	for x: float in [-6.3, 0.0, 6.3]:
		_city._bench(site + Vector2(x, 8.3), PI)
	var tread: Vector3 = _ground.surface_point(rear + Vector2(0, -3.2), 0.04)
	Parts.ramp(_city, tread, base + Vector3(0, 0.06, -3.7), 2.4, "stone")


func _tree_row() -> void:
	var fig := Vector2(-1.0, -14.0)
	var base: Vector3 = _ground.surface_point(fig)
	_city._tree(fig, 15.3, 0, true)
	_city.add_instance("bandstand_base", "stone", base + Vector3.UP * 0.24, Vector3(7.0, 0.50, 7.0))
	_city.add_instance("bandstand_base", "soil", base + Vector3.UP * 0.51, Vector3(6.69, 0.035, 6.69))
	_city.add_collision(base + Vector3.UP * 0.19, Vector3(5.6, 0.42, 5.6))
	for site: Vector2 in [Vector2(6.9, 37), Vector2(36, 34), Vector2(43, 14), Vector2(14, -30), Vector2(44, -29), Vector2(-27, -34), Vector2(-13, 33)]:
		_city._tree(site, 6.4 + fposmod(site.x, 3.0), 1, true)
		_city._garden(site, 1.6, 8)


func _sign(site: Vector2) -> void:
	var base: Vector3 = _ground.surface_point(site)
	_city.add_box(base + Vector3.UP * 0.63, Vector3(2.92, 1.26, 0.55), "stone")
	_city.add_box(base + Vector3(0, 0.94, 0.28), Vector3(2.50, 0.43, 0.055), "sign_ink")
	Openings.lettering(_city, "PRAÇA DA FIGUEIRA", base + Vector3(0, 0.94, 0.31), 0.0, 2.24, 0.26, Color("e5dac1"))
