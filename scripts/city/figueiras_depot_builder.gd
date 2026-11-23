extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Openings = preload("res://scripts/city/figueiras_openings.gd")


func build(city, ground) -> void:
	var block := Layout.DEPOT
	ground.patch(block.grow(-0.6), "cobbles", 0.024)
	var drive := Rect2(Layout.DEPOT_AXIS - 4.65, -173, 9.30, 116)
	ground.patch(drive, "asphalt_repair", 0.031)
	for side: float in [-1, 1]:
		var x := Layout.DEPOT_AXIS + side * 11.9
		var z := -111.0 if side < 0.0 else -136.0
		_workshop(city, Vector2(x, z), side)
		for pocket in 4:
			var park_z := -150.5 + pocket * 3.0 if side < 0.0 else -91.5 + pocket * 3.0
			var site := Vector2(Layout.DEPOT_AXIS + side * 8.7, park_z)
			ground.patch(Rect2(site - Vector2(2.0, 0.048), Vector2(4.0, 0.096)), "white", 0.038)
			ground.patch(Rect2(site + Vector2(-2.0 if side > 0 else 2.0, 0.0) - Vector2(0.06, 0), Vector2(0.12, 3.0)), "white", 0.038)
		for post_z: float in [-163.0, -67.0]:
			city._lamp(Vector2(Layout.DEPOT_AXIS + side * 5.8, post_z), Vector2(-side, 0.0))
	for entrance: float in [-164.0, -66.0]:
		_entrance(city, entrance)
	_water_tower(city, Vector2(Layout.DEPOT_AXIS + 12.6, -106.0))


func _workshop(city, site: Vector2, side: float) -> void:
	var y := maxf(Layout.height_at(site + Vector2(4.4, -13.0)), Layout.height_at(site + Vector2(-4.4, 13.0)))
	var origin := Vector3(site.x, y, site.y)
	var yaw := -side * PI * 0.5
	city.add_part(origin, Vector3(0, -1.35, 0), Vector3(26.0, 2.7, 9.0), "stone", yaw, true)
	city.add_part(origin, Vector3(0, 2.12, 0), Vector3(26.0, 4.25, 9.0), "brick", yaw, true)
	city.add_part(origin, Vector3(0, 4.3, 0), Vector3(27.0, 0.24, 9.9), "metal", yaw)
	for bay in 4:
		var x := (bay - 1.5) * 6.5
		city.add_part(origin, Vector3(x, 4.99, -0.7), Vector3(6.46, 1.69, 7.2), "roof_gray", yaw, false, "roof")
		city._window(origin, Vector3(x, 4.76, 2.18), Vector2(5.73, 0.49), yaw, "glass", "iron")
		city.add_part(origin, Vector3(x, 1.76, 4.56), Vector3(4.35, 3.76, 0.15), "steel_plate", yaw)
		city.add_part(origin, Vector3(x, 1.76, 4.648), Vector3(4.26, 3.62, 1.0), "metal", yaw, false, "shutter_grooves")
		city.add_part(origin, Vector3(x, 3.55, 4.99), Vector3(4.91, 0.14, 1.13), "metal", yaw)
		city.add_part(origin, Vector3(x, 3.40, 4.96), Vector3(0.65, 0.12, 0.24), "light", yaw)
		Openings.lettering(city, str(bay + 1), origin + Basis(Vector3.UP, yaw) * Vector3(x - 2.64, 2.93, 4.521),
			yaw, 0.28, 0.35, Color("e5d8be"))
	var title := "MECÂNICA" if side < 0.0 else "REPAROS E REVISÃO"
	var width := 2.67 if side < 0.0 else 4.53
	city.add_part(origin, Vector3(0, 4.0, 4.56), Vector3(width, 0.39, 0.083), "trim", yaw)
	Openings.lettering(city, title, origin + Basis(Vector3.UP, yaw) * Vector3(0, 4.0, 4.607), yaw, width - 0.24, 0.29, Color("3c443b"))


func _entrance(city, z: float) -> void:
	var site := Vector2(Layout.DEPOT_AXIS, z)
	var origin := Layout.surface_point(site)
	var yaw := PI if z < -100 else 0.0
	for side: float in [-1, 1]:
		var foot := Layout.surface_point(site + Vector2(side * 5.75, 0))
		var height := origin.y + 6.15 - foot.y
		city.add_box(foot + Vector3.UP * height * 0.5, Vector3(0.46, height, 0.48), "steel_plate", true)
		city.add_box(foot + Vector3.UP * 0.44, Vector3(0.85, 0.88, 0.87), "stone", true)
	city.add_box(origin + Vector3.UP * 5.96, Vector3(11.85, 0.62, 0.50), "metal", true)
	city.add_box(origin + Vector3.UP * 5.56, Vector3(6.7, 0.52, 0.38), "trim")
	for face: float in [-1, 1]:
		city.add_label("OFICINAS DA VILA", origin + Vector3(0, 5.56, face * 0.28), yaw if face == (1.0 if z >= -100 else -1.0) else yaw + PI, 0.018)


func _water_tower(city, site: Vector2) -> void:
	var origin := Layout.surface_point(site)
	for x: float in [-1.56, 1.56]:
		for z: float in [-1.56, 1.56]:
			city.add_part(origin, Vector3(x, 4.8, z), Vector3(0.27, 10.2, 0.27), "metal", 0.0, true)
	for y: float in [1.0, 4.1, 7.6]:
		for side: float in [-1, 1]:
			city.add_part(origin, Vector3(0, y, side * 1.56), Vector3(3.4, 0.18, 0.18), "steel_plate", 0.0)
			city.add_part(origin, Vector3(side * 1.56, y, 0), Vector3(0.18, 0.18, 3.4), "steel_plate", 0.0)
	city.add_part(origin, Vector3(0, 10.2, 0), Vector3(2.65, 3.5, 2.65), "reservoir_blue", 0.0, false, "cylinder")
	city.add_part(origin, Vector3(0, 12.1, 0), Vector3(2.82, 0.32, 2.82), "metal", 0.0, false, "cylinder")
	city.add_part(origin, Vector3(0, 9.05, 0), Vector3(2.70, 0.16, 2.70), "trim", 0.0, false, "cylinder")
