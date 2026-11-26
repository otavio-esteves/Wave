extends RefCounted

const ATLAS_SIZE := Vector2(543.0, 724.0)
const ASSETS := "res://assets/textures/jabuticabeiras/"
const FACADE_SHADER = preload("res://assets/shaders/jabuticabeiras/facade.gdshader")
const STUCCO_NORMAL = preload("res://assets/textures/neighborhood/stucco-normal.res")

enum Facade { BAKERY, WORKSHOP, GARAGE, HARDWARE, OLIVE, IVORY, BRICK, BLUE }

# The rectangles follow the photographed frames in each atlas cell. The glass
# panels and shutters sit behind the wall with geometry closing each reveal.
const OPENINGS := [
	[[Rect2(70, 126, 152, 138), true], [Rect2(323, 126, 152, 138), true],
		[Rect2(57, 424, 288, 202), true], [Rect2(375, 423, 108, 289), true]],
	[[Rect2(60, 125, 179, 141), true], [Rect2(318, 125, 178, 141), true],
		[Rect2(40, 431, 86, 281), true], [Rect2(155, 395, 354, 319), false]],
	[[Rect2(50, 116, 110, 155), true], [Rect2(202, 114, 145, 157), true],
		[Rect2(388, 115, 116, 157), true], [Rect2(27, 432, 80, 282), false], [Rect2(159, 422, 352, 291), false]],
	[[Rect2(78, 136, 136, 86), true], [Rect2(338, 136, 137, 86), true],
		[Rect2(29, 383, 247, 245), true], [Rect2(308, 382, 203, 332), false]],
	[[Rect2(62, 120, 154, 161), true], [Rect2(326, 119, 154, 162), true],
		[Rect2(27, 431, 337, 288), false], [Rect2(402, 432, 109, 287), false]],
	[[Rect2(127, 120, 283, 163), false], [Rect2(28, 434, 338, 285), false],
		[Rect2(402, 435, 109, 284), false]],
	[[Rect2(58, 126, 170, 153), true], [Rect2(317, 126, 169, 153), true],
		[Rect2(51, 438, 319, 280), false], [Rect2(409, 437, 104, 282), false]],
	[[Rect2(56, 94, 439, 197), true], [Rect2(27, 434, 129, 283), false], [Rect2(240, 435, 256, 167), true]],
]
const SIDE_COLORS := ["8e8171", "91805d", "786d60", "88817a", "7e8368", "918474", "986e57", "697782"]
const WALL = preload("res://assets/textures/neighborhood/stucco-albedo.res")
const BRICK = preload("res://assets/textures/neighborhood/brickwork-albedo.res")
const BRICK_NORMAL = preload("res://assets/textures/neighborhood/brickwork-normal.res")
var street
var _plates: Array[ShaderMaterial] = []
var _sectors: Dictionary[Vector2i, SurfaceTool] = {}


func _init(builder) -> void:
	street = builder
	for name: String in ["comercio", "sobrados"]:
		var material := ShaderMaterial.new()
		material.resource_name = "jabuticabeiras_" + name
		material.shader = FACADE_SHADER
		material.set_shader_parameter("elevation", load(ASSETS.path_join(name + ".png")))
		material.set_shader_parameter("fine_normal", STUCCO_NORMAL)
		_plates.append(material)
	for facade in SIDE_COLORS.size():
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(SIDE_COLORS[facade])
		material.albedo_texture = BRICK if facade == Facade.BRICK else WALL
		material.normal_enabled = true
		material.normal_texture = BRICK_NORMAL if facade == Facade.BRICK else STUCCO_NORMAL
		material.normal_scale = 0.60
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * (0.60 if facade == Facade.BRICK else 0.47)
		material.roughness = 0.92
		street.materials["side_%d" % facade] = material
	var pane := StandardMaterial3D.new()
	pane.albedo_color = Color("4a6265")
	pane.metallic = 0.28
	pane.roughness = 0.28
	street.materials["side_glass"] = pane


func add(origin: Vector3, width: float, height: float, depth: float, yaw: float, facade: int, roof: bool, number: int) -> void:
	var side_material := "side_%d" % facade
	var axis := Basis(Vector3.UP, yaw)
	var frame := Transform3D(axis, origin)
	var single_floor := height < 4.0
	var crop := 0.46 if single_floor else 0.0
	var key := Vector2i(int(facade >= Facade.OLIVE), floori(origin.z / 34.0))
	if not _sectors.has(key):
		var batch := SurfaceTool.new()
		batch.begin(Mesh.PRIMITIVE_TRIANGLES)
		batch.set_material(_plates[key.x])
		_sectors[key] = batch
	var surface := _sectors[key]
	var wall: Array[Rect2] = [Rect2(0.0, crop, 1.0, 1.0 - crop)]
	var facade_area := wall[0]
	for spec: Array in OPENINGS[facade]:
		var px: Rect2 = spec[0]
		var opening := Rect2(px.position / ATLAS_SIZE, px.size / ATLAS_SIZE)
		if not facade_area.encloses(opening):
			continue
		var glass: bool = spec[1]
		var inset := 0.25 if px.size.y > 220 else 0.13
		var display_window := glass and opening.position.y > 0.45 and facade in [Facade.BAKERY, Facade.HARDWARE]
		var glazing := (1.0 if display_window else 0.65) if glass else 0.0
		wall = _cut_opening(wall, opening)
		_panel(surface, frame, opening, width, height, crop, -inset, facade, glazing, 0.90)
		_jamb(surface, frame, opening, width, height, crop, inset, facade)
		if facade == Facade.BAKERY and display_window:
			_bakery_frame(origin, opening, width, height, crop, inset, yaw)
		if px.end.y < 660.0 and (glass or px.size.x > 200.0):
			var sill := _corner(Vector2(opening.get_center().x, opening.end.y + 0.002), width, height, crop, 0.014)
			street.add_part(origin, sill, Vector3(opening.size.x * width + 0.09, 0.044, 0.17), "window_sill", yaw)
	for panel: Rect2 in wall:
		_panel(surface, frame, panel, width, height, crop, 0.0, facade, 0.0, 1.0)
	street.add_part(origin, Vector3(0.0, height * 0.5 - 0.16, -depth * 0.5 - 0.19),
		Vector3(width - 0.037, height + 0.29, depth - 0.38), side_material, yaw)
	for side: float in [-1.0, 1.0]:
		street.add_part(origin, Vector3(side * (width * 0.5 - 0.043), height * 0.50 - 0.18, -0.23),
			Vector3(0.082, height + 0.31, 0.441), side_material, yaw)
	# The volume starts behind the door and glazing. A wheel can reach the threshold.
	street.add_collision(frame * Vector3(0.0, height * 0.5 - 0.10, -depth * 0.5 - 0.12),
		Vector3(width - 0.018, height + 0.36, depth - 0.24), yaw)
	street.add_part(origin, Vector3(0.0, -0.075, -0.025), Vector3(width + 0.04, 0.15, 0.18), "window_sill", yaw)
	street.add_part(origin, Vector3(0.0, height, -depth * 0.5 + 0.02),
		Vector3(width + 0.18, 0.096, depth + 0.23), "coping", yaw)
	if roof:
		street.add_part(origin, Vector3(0.0, height + 0.54, -depth * 0.5 + 0.17),
			Vector3(width + 0.52, 1.02, depth + 0.49), "roof_tile", yaw, false, "tiled_hip")
		street.add_part(origin, Vector3(0.0, height + 0.012, 0.30),
			Vector3(width + 0.50, 0.093, 0.105), "zinc", yaw)
	else:
		_roof_details(origin, axis, width, height, depth, yaw, number)
	_service_details(origin, width, height, yaw, facade, crop, number)
	_architecture(origin, width, height, depth, yaw, facade, number)


func finish(parent: Node3D) -> void:
	for key: Vector2i in _sectors:
		var surface := _sectors[key]
		surface.generate_tangents()
		surface.index()
		var mesh := MeshInstance3D.new()
		mesh.name = "Facades_%d_%d" % [key.x, -key.y]
		mesh.mesh = surface.commit()
		parent.add_child(mesh)


func _cut_opening(wall: Array[Rect2], opening: Rect2) -> Array[Rect2]:
	var remaining: Array[Rect2] = []
	for section in wall:
		var cut := section.intersection(opening)
		if not cut.has_area():
			remaining.append(section)
			continue
		for strip in [
			Rect2(section.position, Vector2(section.size.x, cut.position.y - section.position.y)),
			Rect2(section.position.x, cut.end.y, section.size.x, section.end.y - cut.end.y),
			Rect2(section.position.x, cut.position.y, cut.position.x - section.position.x, cut.size.y),
			Rect2(cut.end.x, cut.position.y, section.end.x - cut.end.x, cut.size.y),
		]:
			if strip.has_area():
				remaining.append(strip)
	return remaining


func _corner(uv: Vector2, width: float, height: float, crop: float, depth: float) -> Vector3:
	return Vector3((uv.x - 0.5) * width, (1.0 - uv.y) * height / (1.0 - crop), depth)


func _atlas(uv: Vector2, index: int) -> Vector2:
	var margin := Vector2(3.0, 2.0) / ATLAS_SIZE
	var within := margin + uv * (Vector2.ONE - 2.0 * margin)
	return Vector2((float(index % 4) + within.x) * 0.25, within.y)


func _panel(surface: SurfaceTool, frame: Transform3D, area: Rect2, width: float, height: float,
		crop: float, inset: float, facade: int, glazing: float, shade: float) -> void:
	for uv: Vector2 in [area.position, Vector2(area.end.x, area.position.y), area.end,
			area.position, area.end, Vector2(area.position.x, area.end.y)]:
		var point := _corner(uv, width, height, crop, inset)
		var ao := lerpf(0.69, 1.0, smoothstep(0.0, 1.22, point.y)) * shade
		surface.set_color(Color(ao, ao, ao, glazing))
		surface.set_normal(frame.basis.z)
		surface.set_uv(_atlas(uv, facade))
		surface.set_uv2(Vector2(point.x, point.y))
		surface.add_vertex(frame * point)


func _jamb(surface: SurfaceTool, frame: Transform3D, opening: Rect2, width: float,
		height: float, crop: float, recess: float, facade: int) -> void:
	var ring := [opening.position, Vector2(opening.position.x, opening.end.y), opening.end,
		Vector2(opening.end.x, opening.position.y)]
	for side in 4:
		var a: Vector2 = ring[side]
		var b: Vector2 = ring[(side + 1) % 4]
		var front_a := _corner(a, width, height, crop, 0.0)
		var front_b := _corner(b, width, height, crop, 0.0)
		var outside := (a + b) * 0.5 - opening.get_center()
		var across := Vector2(signf(outside.x), 0.0) if side % 2 == 0 else Vector2(0.0, signf(outside.y))
		var texel_offset := across * (Vector2(12.0, 13.0) / ATLAS_SIZE)
		var depth := Vector3.FORWARD * recess
		var normal := (front_b - front_a).cross(Vector3.FORWARD).normalized()
		var corners := [front_a, front_b, front_b + depth, front_a + depth]
		var uvs := [a, b, b + texel_offset, a + texel_offset]
		for index: int in [0, 2, 1, 0, 3, 2]:
			var point: Vector3 = corners[index]
			var shade := 0.73 if index < 2 else 0.47
			surface.set_color(Color(shade, shade, shade, 0.0))
			surface.set_normal(frame.basis * normal)
			surface.set_uv(_atlas(uvs[index], facade))
			surface.set_uv2(Vector2(point.x + point.z, point.y))
			surface.add_vertex(frame * point)


func _roof_details(origin: Vector3, axis: Basis, width: float, height: float, depth: float, yaw: float, number: int) -> void:
	if number % 4 == 0:
		street.add_part(origin, Vector3(width * 0.22, height + 0.49, -depth + 1.25),
			Vector3(0.94, 0.87, 0.94), "water_tank", yaw, false, "tank")
		street.add_part(origin, Vector3(width * 0.22, height + 0.91, -depth + 1.25),
			Vector3(1.00, 0.11, 1.00), "water_tank", yaw, false, "tank")
	if number % 3 == 1:
		var foot := origin + axis * Vector3(-width * 0.23, height + 0.06, -depth * 0.42)
		var top := foot + Vector3.UP * 1.84
		street.beam(foot, top, 0.020, "zinc")
		street.beam(top - axis.z * 0.48, top + axis.z * 0.48, 0.012, "zinc")
		for offset: float in [-0.40, -0.18, 0.05, 0.29]:
			var element := top + axis.z * offset
			street.beam(element - axis.x * 0.26, element + axis.x * 0.26, 0.010, "zinc")


func _bakery_frame(origin: Vector3, opening: Rect2, width: float, height: float, crop: float, inset: float, yaw: float) -> void:
	var upper := _corner(opening.position, width, height, crop, -inset + 0.025)
	var lower := _corner(opening.end, width, height, crop, -inset + 0.025)
	var middle := (upper + lower) * 0.5
	for x: float in [upper.x + 0.016, lower.x - 0.016]:
		street.add_part(origin, Vector3(x, middle.y, middle.z), Vector3(0.038, upper.y - lower.y, 0.049), "zinc", yaw)
	for y: float in [upper.y - 0.012, lerpf(upper.y, lower.y, 0.195), lower.y + 0.013]:
		street.add_part(origin, Vector3(middle.x, y, middle.z), Vector3(lower.x - upper.x, 0.041, 0.044), "zinc", yaw)
	if opening.size.x > 0.3:
		var transom := lerpf(upper.y, lower.y, 0.195)
		street.add_part(origin, Vector3(middle.x, (transom + lower.y) * 0.5, middle.z),
			Vector3(0.052, transom - lower.y, 0.041), "zinc", yaw)


func _service_details(origin: Vector3, width: float, height: float, yaw: float, facade: int, crop: float, number: int) -> void:
	var axis := Basis(Vector3.UP, yaw)
	var pipe_x := width * (0.475 if number % 3 == 1 else -0.474)
	var pipe := origin + axis * Vector3(pipe_x, 0.12, 0.044)
	street.beam(pipe, pipe + Vector3.UP * (height - 0.23), 0.027, "zinc")
	if facade == Facade.BAKERY or facade == Facade.HARDWARE or facade == Facade.WORKSHOP:
		var band := (1.0 - (0.49 if facade == Facade.BAKERY else 0.495)) * height / (1.0 - crop)
		var shop_name := {Facade.BAKERY: "PADARIA IPÊ", Facade.HARDWARE: "CASA DO PARAFUSO", Facade.WORKSHOP: "AUTO ELÉTRICA"}[facade] as String
		if facade == Facade.WORKSHOP:
			var sign := Vector3(width * 0.10, band + 0.07, 0.071)
			street.add_part(origin, sign, Vector3(width * 0.70, 0.39, 0.13), "shop_sign_gray", yaw)
			street.lettering(shop_name, origin + axis * (sign + Vector3.BACK * 0.074), yaw, 0.0087, Color("f0d9aa"))
			street.add_part(origin, Vector3(width * 0.10, band - 0.28, 0.52),
				Vector3(width * 0.78, 0.12, 1.14), "awning_metal", yaw)
			street.add_part(origin, Vector3(width * 0.10, band - 0.26, 1.11),
				Vector3(width * 0.785, 0.12, 0.065), "zinc", yaw)
			for x: float in [-0.25, 0.45]:
				street.beam(origin + axis * Vector3(width * x, band - 0.80, 0.04),
					origin + axis * Vector3(width * x, band - 0.34, 0.84), 0.023, "dark_iron")
		else:
			street.add_part(origin, Vector3(0.0, band - 0.21, 0.026),
				Vector3(width * 0.72, 0.39, 0.072), "shop_sign_green" if facade == Facade.BAKERY else "shop_sign_gray", yaw)
			street.lettering(shop_name, origin + Vector3.UP * (band - 0.21) + axis.z * 0.066, yaw, 0.0070, Color("e1d9bc"))
		if facade == Facade.BAKERY:
			street.add_part(origin, Vector3(0.0, band - 0.59, 0.57),
				Vector3(width * 0.87, 0.50, 1.23), "awning_cloth", yaw, false, "striped_canvas")
			for line_y: float in [band - 0.388, band - 0.032]:
				street.add_part(origin, Vector3(0, line_y, 0.063),
					Vector3(width * 0.721, 0.023, 0.028), "window_sill", yaw)
			for direction: float in [-1.0, 1.0]:
				var bracket := origin + axis * Vector3(direction * width * 0.409, band - 0.92, 0.03)
				street.beam(bracket, bracket + axis.z * 1.04 + Vector3.UP * 0.063, 0.019, "dark_iron")
			_bakery_front(origin, axis, width, yaw)
	else:
		var plate := Vector3(width * 0.41, 1.65, 0.030)
		street.add_part(origin, plate, Vector3(0.26, 0.16, 0.044), "address_plate", yaw)
		street.lettering(str(number), origin + axis * (plate + Vector3.BACK * 0.025), yaw, 0.00265, Color("dfddd0"))
		var box_x := width * (0.37 if facade == Facade.BLUE or facade == Facade.GARAGE else -0.43)
		street.add_part(origin, Vector3(box_x, 1.34, 0.072), Vector3(0.23, 0.32, 0.12), "zinc", yaw)


func _architecture(origin: Vector3, width: float, height: float, depth: float, yaw: float, facade: int, number: int) -> void:
	if height < 4.0:
		return
	if number in [21, 33, 38, 56, 63, 68, 80, 93]:
		var lower_sill := 1.0 - float((OPENINGS[facade][0][0] as Rect2).end.y) / ATLAS_SIZE.y
		var x := width * (0.13 if number in [38, 56, 68, 93] else -0.06)
		var span := width * (0.78 if number in [21, 56, 80] else 0.59)
		_balcony(origin, width, x, height * lower_sill, span, yaw, number)
	elif number in [20, 32, 39, 57, 62, 69]:
		var y := height * 0.83
		street.add_part(origin, Vector3(0.0, y, 0.17), Vector3(width + 0.13, 0.15, 0.44), "plaster_trim", yaw)
		for x: float in [-0.29, 0.28]:
			street.add_part(origin, Vector3(width * x, y - 0.13, 0.10),
				Vector3(0.15, 0.22, 0.21), "coping", yaw)
	if number in [26, 32, 33, 39, 45, 56, 63, 75, 81, 86, 93]:
		var side := -1.0 if number in [26, 39, 45, 63, 86] else 1.0
		_side_elevation(origin, side * width * 0.5, height, depth, yaw, side)


func _balcony(origin: Vector3, width: float, x: float, sill: float, span: float, yaw: float, number: int) -> void:
	var base := sill - (0.46 if number == 21 else 0.40)
	var projection := 0.70 if number in [21, 38, 56, 80] else 0.45
	var slab := "window_sill" if number in [21, 33, 63, 80] else "plaster_trim"
	street.add_part(origin, Vector3(x, base, projection * 0.50),
		Vector3(span + 0.13, 0.18, projection + 0.14), slab, yaw)
	street.add_part(origin, Vector3(x, base - 0.105, projection + 0.034),
		Vector3(span + 0.08, 0.066, 0.10), "coping", yaw)
	for side: float in [-1.0, 1.0]:
		street.add_part(origin, Vector3(x + side * span * 0.33, base - 0.22, projection * 0.22),
			Vector3(0.23, 0.27, projection * 0.58), slab, yaw)
		street.add_part(origin, Vector3(x + side * span * 0.5, base + 0.47, projection * 0.55),
			Vector3(0.059, 0.12, projection * 0.87), "dark_iron", yaw)
	for rail_y: float in [base + 0.19, base + 0.49]:
		street.add_part(origin, Vector3(x, rail_y, projection),
			Vector3(span + 0.045, 0.037, 0.051), "dark_iron", yaw)
	var count := roundi(span / 0.205)
	for bar in count + 1:
		var bar_x := x + span * (float(bar) / count - 0.5)
		street.add_part(origin, Vector3(bar_x, base + 0.33, projection),
			Vector3(0.026, 0.31, 0.029), "dark_iron", yaw)
	if number in [21, 33, 38, 63, 93]:
		var frame := Basis(Vector3.UP, yaw)
		for box_x: float in [x - span * 0.29, x + span * 0.25]:
			var box := Vector3(box_x, base + 0.21, projection - 0.19)
			street.add_part(origin, box, Vector3(width * 0.16, 0.26, 0.32), "ceramic", yaw)
			street.add_instance("shrub", "tree_leaves", origin + frame * (box + Vector3.UP * 0.24),
				Vector3(width * 0.13, 0.42, 0.62), yaw + box_x, false)


func _side_elevation(origin: Vector3, outer: float, height: float, depth: float, yaw: float, side: float) -> void:
	var ledge := Vector3(outer + side * 0.04, height * 0.70, -depth * 0.29)
	street.add_part(origin, ledge, Vector3(0.10, 0.77, 1.44), "plaster_trim", yaw)
	street.add_part(origin, ledge + Vector3(side * 0.050, 0.015, 0.0),
		Vector3(0.035, 0.65, 1.27), "side_glass", yaw)
	street.add_part(origin, ledge + Vector3(side * 0.062, -0.40, 0.0),
		Vector3(0.20, 0.078, 1.56), "window_sill", yaw)
	for z: float in [-0.39, 0.0, 0.39]:
		street.add_part(origin, ledge + Vector3(side * 0.073, 0.015, z),
			Vector3(0.037, 0.69, 0.034), "zinc", yaw)
	var frame := Basis(Vector3.UP, yaw)
	var pipe := origin + frame * Vector3(outer + side * 0.050, 0.27, -depth * 0.65)
	street.beam(pipe, pipe + Vector3.UP * (height - 0.27), 0.031, "zinc")


func _bakery_front(origin: Vector3, axis: Basis, width: float, yaw: float) -> void:
	var trim := Vector3(-width * 0.128, 0.29, 0.049)
	street.add_part(origin, trim, Vector3(width * 0.57, 0.40, 0.12), "basalt_wall", yaw)
	street.add_part(origin, trim + Vector3(0.0, 0.23, 0.016), Vector3(width * 0.57, 0.048, 0.16), "tile_green", yaw)
	for x: float in [-0.391, 0.176]:
		street.add_part(origin, Vector3(width * x, 1.43, 0.066),
			Vector3(0.14, 2.54, 0.16), "tile_green", yaw)
	for x: float in [-0.40, 0.36]:
		var sconce := Vector3(width * x, 2.28, 0.21)
		street.add_part(origin, sconce, Vector3(0.147, 0.24, 0.14), "dark_iron", yaw)
		street.add_part(origin, sconce + Vector3(0, -0.03, 0.072), Vector3(0.086, 0.12, 0.016), "lens", yaw)
	var address := Vector3(-width * 0.48, 1.62, 0.061)
	street.add_part(origin, address, Vector3(0.21, 0.20, 0.07), "ceramic", yaw)
	street.lettering("21", origin + axis * (address + Vector3.BACK * 0.04), yaw, 0.00295, Color("efe0b9"))
