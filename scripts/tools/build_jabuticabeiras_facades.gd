extends RefCounted

const Masonry = preload("res://scripts/tools/build_jabuticabeiras_masonry.gd")
const M = Masonry.Finish
const BAKERY_INTERIOR = preload("res://assets/textures/jabuticabeiras/interior-padaria.png")
const SHOP_GLASS = preload("res://assets/shaders/jabuticabeiras/shop_glass.gdshader")
const SKY = preload("res://assets/textures/jabuticabeiras/ceu-apos-garoa.png")

enum Facade { BAKERY, WORKSHOP, GARAGE, HARDWARE, OLIVE, IVORY, BRICK, BLUE }

const WALL := ["d7c5a5", "9b9b8b", "a1aaa8", "a78c78", "a0a383", "dfcbb0", "b18c7c", "91a8b0"]
const JOINERY := ["33504a", "394746", "435155", "5e4d3f", "3d5042", "695042", "483d35", "3a4d5b"]
const LIGHT_INK := Color("f2e1b5")
const BLACK_STEEL := Color("353f41")
const STONE := Color("969089")
const MORTAR := Color("c0b398")
const LIGHT := Color("ffd092")

var _street
var _mass: Masonry
var _shop_glass := ShaderMaterial.new()
var _shop_back := StandardMaterial3D.new()


func _init(street, masonry: Masonry) -> void:
	_street = street
	_mass = masonry
	_shop_glass.shader = SHOP_GLASS
	_shop_glass.set_shader_parameter("sky_panorama", SKY)
	_shop_back.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shop_back.albedo_color = Color("bda182")
	_shop_back.albedo_texture = BAKERY_INTERIOR
	_shop_back.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func add(origin: Vector3, width: float, height: float, depth: float, yaw: float, facade: int, pitched: bool, number: int) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), origin)
	_mass.begin(frame)
	var pattern := floori(float(number) / 6.0) + (number % 2) * 3
	var wall := Color(WALL[facade])
	var joinery := Color(JOINERY[facade])
	var finish := M.BRICK if facade == Facade.BRICK else M.PLASTER
	var store := facade in [Facade.BAKERY, Facade.WORKSHOP, Facade.HARDWARE]
	_shell(frame, width, height, depth, finish, wall)
	if facade == Facade.BAKERY:
		_bakery(frame, width, height, wall, joinery)
	elif facade == Facade.WORKSHOP:
		_workshop(frame, width, height, wall, joinery)
	elif facade == Facade.HARDWARE and height >= 4.0:
		_hardware(frame, width, height, wall, joinery)
	else:
		_residence(frame, width, height, finish, wall, joinery, facade, number, pattern)
	if pitched or facade in [Facade.BAKERY, Facade.HARDWARE]:
		_roof(width, height, depth, wall, joinery, pattern, store)
	else:
		_parapet(frame, width, height, depth, wall, joinery, pattern)
	_side_openings(frame, width, height, depth, wall, joinery, store, pattern)
	if pitched and pattern % 3 == 1:
		_downspout(frame, width * (0.463 if pattern % 2 == 0 else -0.463), height, joinery)


func finish(parent: Node3D) -> void:
	_mass.finish(parent)


func _shell(frame: Transform3D, width: float, height: float, depth: float, finish: int, wall: Color) -> void:
	var edge := width * 0.5
	for x: float in [-edge + 0.16, edge - 0.16]:
		_mass.box(Vector3(x, height * 0.5 - 0.30, -depth * 0.5 - 0.015),
			Vector3(0.32, height + 0.60, depth - 0.03), finish, wall.darkened(0.10))
	_mass.box(Vector3(0, height * 0.5 - 0.28, -depth + 0.14),
		Vector3(width, height + 0.56, 0.28), finish, wall.darkened(0.12))
	_mass.box(Vector3(0, height - 0.09, -depth * 0.5), Vector3(width, 0.18, depth), M.PLASTER, wall.darkened(0.17))
	_street.add_collision(frame * Vector3(0, height * 0.5 - 0.20, -depth * 0.5 - 0.26),
		Vector3(width - 0.025, height + 0.40, depth - 0.52), frame.basis.get_euler().y)


func _front(width: float, height: float, openings: Array[Rect2], finish: int, tone: Color, depth := 0.0) -> void:
	var solid: Array[Rect2] = [Rect2(-width * 0.5, -0.56, width, height + 0.56)]
	for opening in openings:
		var remainder: Array[Rect2] = []
		for piece in solid:
			var hole := piece.intersection(opening)
			if not hole.has_area():
				remainder.append(piece)
				continue
			for strip in [
				Rect2(piece.position, Vector2(piece.size.x, hole.position.y - piece.position.y)),
				Rect2(piece.position.x, hole.end.y, piece.size.x, piece.end.y - hole.end.y),
				Rect2(piece.position.x, hole.position.y, hole.position.x - piece.position.x, hole.size.y),
				Rect2(hole.end.x, hole.position.y, piece.end.x - hole.end.x, hole.size.y),
			]:
				if strip.has_area():
					remainder.append(strip)
		solid = remainder
	for piece in solid:
		_mass.box(Vector3(piece.get_center().x, piece.get_center().y, depth - 0.13),
			Vector3(piece.size.x, piece.size.y, 0.26), finish, tone)


func _window(opening: Rect2, trim: Color, pane: Color, arch := 0.0, shutter := false) -> void:
	var left := opening.position.x
	var right := opening.end.x
	var bottom := opening.position.y
	var top := opening.end.y
	var center := opening.get_center()
	var inset := -0.245
	_mass.box(Vector3(center.x, center.y, inset), Vector3(opening.size.x, opening.size.y, 0.055), M.GLASS, pane, 0.56)
	for x: float in [left + 0.025, right - 0.025]:
		_mass.box(Vector3(x, center.y, -0.10), Vector3(0.066, opening.size.y, 0.27), M.WOOD, trim, 0.65)
	for y: float in [bottom + 0.025, top - arch, bottom + opening.size.y * 0.56]:
		_mass.box(Vector3(center.x, y, -0.13), Vector3(opening.size.x, 0.061, 0.15), M.WOOD, trim)
	_mass.box(Vector3(center.x, center.y, -0.15), Vector3(0.055, opening.size.y - 0.09, 0.14), M.WOOD, trim)
	_mass.box(Vector3(center.x, bottom - 0.029, 0.082), Vector3(opening.size.x + 0.19, 0.091, 0.39), M.STONE, MORTAR)
	if shutter:
		for direction: float in [-1.0, 1.0]:
			var x := center.x + direction * (opening.size.x * 0.5 + 0.158)
			_mass.box(Vector3(x, center.y, 0.070), Vector3(0.31, opening.size.y * 0.95, 0.135), M.WOOD, trim)
			for index in 8:
				var board_y := bottom + (index + 0.7) * opening.size.y / 8.4
				_mass.box(Vector3(x, board_y, 0.148), Vector3(0.26, 0.039, 0.048), M.WOOD, trim.lightened(0.11))


func _arch(opening: Rect2, rise: float, wall: Color, rim: Color, finish: int) -> void:
	var center := Vector2(opening.get_center().x, opening.end.y - rise - 0.075)
	var half := opening.size.x * 0.5
	for segment in 14:
		var first := float(segment) * PI / 14.0
		var next := float(segment + 1) * PI / 14.0
		var a := center + Vector2(-cos(first) * half, sin(first) * rise)
		var b := center + Vector2(-cos(next) * half, sin(next) * rise)
		var edge_a := a + Vector2(-cos(first), sin(first)) * 0.118
		var edge_b := b + Vector2(-cos(next), sin(next)) * 0.118
		_mass.quad(Vector3(a.x, a.y, 0.079), Vector3(b.x, b.y, 0.079),
			Vector3(edge_b.x, edge_b.y, 0.079), Vector3(edge_a.x, edge_a.y, 0.079), M.STONE, rim.darkened(0.09 * (segment % 3)))
		_mass.quad(Vector3(edge_a.x, edge_a.y, 0.006), Vector3(edge_b.x, edge_b.y, 0.006),
			Vector3(b.x, opening.end.y + 0.064, 0.006), Vector3(a.x, opening.end.y + 0.064, 0.006), finish, wall)
		_mass.quad(Vector3(b.x, b.y, -0.25), Vector3(a.x, a.y, -0.25),
			Vector3(a.x, a.y, 0.079), Vector3(b.x, b.y, 0.079), finish, wall, 0.53)
	for x: float in [opening.position.x, opening.end.x]:
		_mass.box(Vector3(x, (center.y + opening.position.y) * 0.5, 0.052),
			Vector3(0.125, center.y - opening.position.y, 0.28), M.STONE, rim)


func _bakery(frame: Transform3D, width: float, height: float, wall: Color, green: Color) -> void:
	var display := Rect2(-width * 0.396, 0.69, width * 0.56, 2.05)
	var door := Rect2(width * 0.235, 0.12, width * 0.172, 2.62)
	var upper_left := Rect2(-width * 0.36, height - 2.39, width * 0.26, 1.67)
	var upper_right := Rect2(width * 0.095, height - 2.39, width * 0.26, 1.67)
	_front(width, height, [display, door, upper_left, upper_right], M.PLASTER, wall)
	_window(upper_left, green, Color("a77b58"), 0.29, true)
	_window(upper_right, green, Color("6a7569"), 0.29, true)
	_arch(upper_left, 0.33, wall, MORTAR, M.PLASTER)
	_arch(upper_right, 0.33, wall, MORTAR, M.PLASTER)
	_arch(display, 0.39, wall, MORTAR, M.PLASTER)
	_window(door, green, Color("aa7045"), 0.23)
	_arch(door, 0.29, wall, MORTAR, M.PLASTER)
	_threshold(door.get_center().x, door.size.x + 0.24, 0.115)
	_mass.box(Vector3(display.get_center().x, 0.35, 0.070), Vector3(display.size.x + 0.15, 0.66, 0.25), M.CERAMIC, green)
	_mass.box(Vector3(display.get_center().x, 0.685, 0.156), Vector3(display.size.x + 0.19, 0.09, 0.44), M.STONE, MORTAR)
	_display(frame, display, green)
	_balcony(width, height - 2.62, width * 0.80, green, 0.93)
	_bakery_awning(frame, width * 0.91, green)
	_sign(frame, "PADARIA IPÊ", Vector3(0, 3.55, 0.091), width * 0.77, green, 0.0075)
	_blade_sign(frame, Vector3(width * 0.405, 3.66, 1.57), "PÃO\n& CAFÉ", green)
	for x: float in [-width * 0.465, width * 0.189, width * 0.465]:
		_mass.box(Vector3(x, 1.52, 0.097), Vector3(0.19, 2.92, 0.31), M.CERAMIC, green)
	_mass.box(Vector3(0, 0.10, 0.64), Vector3(width * 0.94, 0.12, 1.29), M.CERAMIC, MORTAR, 0.83)
	for x: float in [-width * 0.32, width * 0.26]:
		_fixture(frame, Vector3(x, 2.79, 0.91), 3.5, 0.87)
	_street.planter(frame * Vector3(-width * 0.42, 0.16, 1.15), 0.82, 0.4)
	_street.planter(frame * Vector3(width * 0.465, 0.17, 0.86), 0.62, 1.1)


func _bakery_awning(frame: Transform3D, span: float, green: Color) -> void:
	var reach := 1.64
	var site := Vector3(0.0, 3.01, reach * 0.49)
	_street.add_instance("striped_canvas", "awning_cloth", frame * site, Vector3(span, 0.83, reach),
		frame.basis.get_euler().y)
	_mass.box(Vector3(0, 3.33, 0.029), Vector3(span + 0.11, 0.071, 0.17), M.METAL, green)
	_mass.box(Vector3(0, 2.68, reach - 0.085), Vector3(span + 0.04, 0.048, 0.066), M.METAL, green)
	for fraction: float in [-0.44, -0.17, 0.17, 0.44]:
		var x := span * fraction
		var anchor := Vector3(x, 2.59, 0.079)
		var elbow := Vector3(x, 2.66, reach * 0.51)
		var tip := Vector3(x, 2.71, reach - 0.097)
		_mass.box(anchor + Vector3.UP * 0.067, Vector3(0.094, 0.27, 0.111), M.METAL, green)
		_street.beam(frame * anchor, frame * elbow, 0.022, "awning_metal")
		_street.beam(frame * elbow, frame * tip, 0.018, "awning_metal")


func _display(frame: Transform3D, opening: Rect2, green: Color) -> void:
	var center := opening.get_center()
	var width := opening.size.x
	var depth := 1.30
	_panel("PadariaVitrine", frame, Vector3(center.x, center.y, -0.115), opening.size + Vector2(-0.06, 0), _shop_glass)
	_panel("PadariaPrateleiras", frame, Vector3(center.x, center.y, -depth), opening.size + Vector2(0.30, 0), _shop_back)
	for x: float in [opening.position.x - 0.08, opening.end.x + 0.08]:
		_mass.box(Vector3(x, center.y, -0.66), Vector3(0.17, opening.size.y, depth), M.PLASTER, Color("b7a888"), 0.70)
	for y: float in [opening.position.y, opening.end.y]:
		_mass.box(Vector3(center.x, y, -0.66), Vector3(width + 0.27, 0.07, depth), M.WOOD, Color("81705c"), 0.68)
	for x: float in [center.x - width / 6.0, center.x + width / 6.0]:
		_mass.box(Vector3(x, center.y, -0.066), Vector3(0.041, opening.size.y, 0.095), M.METAL, green)
	_mass.box(Vector3(center.x - 0.28, 0.89, -0.67), Vector3(width * 0.73, 0.44, 0.45), M.WOOD, Color("886340"))
	_mass.box(Vector3(center.x - 0.28, 1.15, -0.67), Vector3(width * 0.77, 0.053, 0.54), M.STONE, Color("ead7ad"))
	for x: float in [center.x - 0.81, center.x + 0.66]:
		_mass.box(Vector3(x, 2.39, -0.54), Vector3(0.32, 0.07, 0.29), M.LIGHT, LIGHT)
		_mass.box(Vector3(x, 2.51, -0.54), Vector3(0.031, 0.23, 0.037), M.METAL, BLACK_STEEL)


func _panel(name: String, frame: Transform3D, site: Vector3, size: Vector2, material: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = name
	mesh.mesh = quad
	mesh.transform = Transform3D(frame.basis, frame * site)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_street.scene_root.add_child(mesh)


func _workshop(frame: Transform3D, width: float, height: float, wall: Color, steel: Color) -> void:
	var bay := Rect2(-width * 0.38, 0.04, width * 0.66, 2.98)
	var office := Rect2(width * 0.326, 0.11, width * 0.114, 2.36)
	var loft := Rect2(-width * 0.37, height - 2.0, width * 0.74, 1.18)
	_front(width, height, [bay, office, loft], M.BRICK, wall)
	_window(loft, steel, Color("879595"))
	_window(office, steel, Color("a2724c"))
	_threshold(office.get_center().x, office.size.x, 0.115)
	_mass.box(Vector3(bay.get_center().x, 0.035, -1.58), Vector3(bay.size.x, 0.12, 3.72), M.STONE, Color("a59b82"))
	_mass.box(Vector3(bay.get_center().x, 1.49, -3.22), Vector3(bay.size.x + 0.09, 2.98, 0.15), M.PLASTER, Color("8f8e77"), 0.54)
	for x: float in [bay.position.x, bay.end.x]:
		_mass.box(Vector3(x, 1.60, -1.62), Vector3(0.17, 3.14, 3.25), M.BRICK, wall, 0.57)
		_mass.box(Vector3(x, 1.54, 0.052), Vector3(0.17, 3.03, 0.24), M.METAL, steel)
	_mass.box(Vector3(bay.get_center().x, 2.95, -1.63), Vector3(bay.size.x, 0.16, 3.18), M.PLASTER, wall, 0.57)
	for x: float in [bay.position.x + 0.57, bay.get_center().x, bay.end.x - 0.53]:
		_mass.box(Vector3(x, 2.85, -0.93), Vector3(0.82, 0.045, 0.105), M.LIGHT, Color("ece2bd"))
	_workbench(bay.get_center().x, bay.size.x)
	_workshop_equipment(bay.position.x + 0.52, bay.end.x - 0.51)
	_workshop_lift(frame, bay.get_center().x, bay.size.x)
	_roller(Rect2(bay.position.x, 2.44, bay.size.x, 0.57), -0.14, steel)
	_canopy(width * 0.93, 3.33, 1.21, steel)
	_sign(frame, "AUTO ELÉTRICA", Vector3(0, 3.45, 1.23), width * 0.83, Color("67684f"), 0.0076)
	_fixture(frame, Vector3(bay.get_center().x, 2.78, 0.55), 4.25, 0.94)
	_street.add_lamp(frame * Vector3(bay.get_center().x, 2.70, -2.18), 3.20, 0.76, 0.36)


func _workbench(x: float, width: float) -> void:
	_mass.box(Vector3(x + 0.32, 0.51, -2.67), Vector3(width * 0.62, 0.92, 0.56), M.METAL, Color("924c37"), 0.74)
	_mass.box(Vector3(x + 0.32, 0.99, -2.66), Vector3(width * 0.67, 0.085, 0.65), M.WOOD, Color("9f7f58"), 0.83)
	for row in 4:
		_mass.box(Vector3(x + 0.32, 0.34 + row * 0.176, -2.37),
			Vector3(width * 0.59, 0.021, 0.05), M.METAL, Color("c2a790"))
	for index in 8:
		var item_x := x + (float(index) - 3.5) * width * 0.081
		var size := 0.10 + 0.049 * (index % 3)
		var ink := Color("ceaa64") if index % 3 == 0 else Color("6f827e")
		_mass.box(Vector3(item_x, 1.07, -2.68), Vector3(size, 0.22, size), M.METAL, ink)
	_mass.box(Vector3(x - width * 0.33, 1.51, -3.04), Vector3(0.78, 0.75, 0.27), M.WOOD, Color("5c706a"))
	for y: float in [1.25, 1.52, 1.76]:
		_mass.box(Vector3(x - width * 0.33, y, -2.81), Vector3(0.84, 0.042, 0.44), M.WOOD, Color("9a7552"))
	var board := Vector3(x + 0.63, 1.74, -3.102)
	_mass.box(board, Vector3(width * 0.42, 0.91, 0.064), M.WOOD, Color("89806b"), 0.81)
	_mass.box(board + Vector3.UP * 0.46, Vector3(width * 0.43, 0.050, 0.084), M.METAL, BLACK_STEEL)
	for index in 13:
		var handle := 0.17 + 0.05 * (index % 5)
		var tool := board + Vector3((index - 6.0) * width * 0.028, 0.09 - 0.26 * (index % 2), 0.061)
		_mass.box(tool, Vector3(0.025, handle, 0.020), M.METAL, Color("a1a495"))
		_mass.box(tool + Vector3.UP * handle * 0.51, Vector3(0.060, 0.064, 0.025), M.METAL, Color("a1a495"))
		_mass.box(tool + Vector3.DOWN * handle * 0.36, Vector3(0.045, 0.084, 0.031), M.METAL,
			Color("89523c") if index % 3 == 0 else BLACK_STEEL)


func _workshop_lift(frame: Transform3D, center: float, width: float) -> void:
	var paint := Color("45666a")
	var safety := Color("af8a49")
	for side: float in [-1.0, 1.0]:
		var x := center + side * width * 0.211
		var foot := Vector3(x, 0.123, -1.69)
		_mass.box(foot, Vector3(0.42, 0.078, 0.45), M.METAL, BLACK_STEEL)
		_mass.box(foot + Vector3.UP * 1.16, Vector3(0.184, 2.33, 0.235), M.METAL, paint)
		_mass.box(foot + Vector3(0, 1.21, 0.122), Vector3(0.105, 1.83, 0.019), M.METAL, BLACK_STEEL)
		_mass.box(foot + Vector3(0, 0.42, 0.140), Vector3(0.262, 0.27, 0.063), M.METAL, safety)
		_mass.box(foot + Vector3(side * 0.11, 1.17, 0.13), Vector3(0.078, 0.27, 0.154), M.METAL, BLACK_STEEL)
		var hinge := foot + Vector3(-side * 0.085, 0.12, 0.0)
		var tip := hinge + Vector3(-side * 0.56, 0, 0.45)
		_street.beam(frame * hinge, frame * tip, 0.057, "awning_metal")
		_mass.box(tip + Vector3.UP * 0.037, Vector3(0.196, 0.065, 0.215), M.METAL, BLACK_STEEL)
		for stripe in 3:
			_mass.box(foot + Vector3(0, 0.315 + stripe * 0.083, 0.174),
				Vector3(0.238, 0.028, 0.013), M.METAL, BLACK_STEEL)


func _workshop_equipment(left: float, right: float) -> void:
	for height: float in [0.10, 0.73, 1.36]:
		_mass.box(Vector3(left, height, -1.02), Vector3(0.91, 0.069, 0.49), M.METAL, BLACK_STEEL)
	for side: float in [-1.0, 1.0]:
		_mass.box(Vector3(left + side * 0.423, 0.79, -0.80), Vector3(0.048, 1.57, 0.052), M.METAL, BLACK_STEEL)
	for y: float in [0.395, 1.025]:
		_tire(Vector3(left - 0.078, y, -0.91), 0.285, 0.159, 0.163)
		_tire(Vector3(left + 0.105, y, -1.083), 0.274, 0.154, 0.149)
	_mass.box(Vector3(right, 0.39, -1.25), Vector3(0.42, 0.65, 0.47), M.METAL, Color("94643c"))
	_mass.box(Vector3(right, 0.744, -1.25), Vector3(0.51, 0.066, 0.57), M.METAL, Color("a48d56"))
	_mass.box(Vector3(right, 0.399, -0.998), Vector3(0.23, 0.038, 0.057), M.METAL, Color("bdb29f"))
	for x: float in [left + 1.48, right - 1.44]:
		_mass.box(Vector3(x, 0.106, -1.73), Vector3(0.21, 0.033, 2.21), M.METAL, Color("b9994d"))


func _tire(site: Vector3, outer: float, inner: float, depth: float) -> void:
	var front := site + Vector3.BACK * depth * 0.5
	var back := site - Vector3.BACK * depth * 0.5
	for section in 14:
		var first := TAU * section / 14.0
		var next := TAU * (section + 1) / 14.0
		var a := Vector3(cos(first), sin(first), 0)
		var b := Vector3(cos(next), sin(next), 0)
		_mass.quad(front + a * outer, front + b * outer, front + b * inner, front + a * inner,
			M.METAL, Color("383b38"))
		_mass.quad(back + a * outer, back + b * outer, front + b * outer, front + a * outer,
			M.METAL, Color("343633"))
		_mass.quad(back + b * inner, back + a * inner, front + a * inner, front + b * inner,
			M.METAL, Color("242927"), 0.73)


func _hardware(frame: Transform3D, width: float, height: float, wall: Color, wood: Color) -> void:
	var display := Rect2(-width * 0.40, 0.67, width * 0.53, 1.95)
	var slider := Rect2(width * 0.17, 0.04, width * 0.27, 2.59)
	var upstairs := Rect2(-width * 0.31, height - 1.76, width * 0.62, 1.12)
	_front(width, height, [display, slider, upstairs], M.BRICK, wall)
	_window(upstairs, wood, Color("7e6952"), 0.0, true)
	_window(display, wood, Color("bc8754"), 0.27)
	_arch(display, 0.33, wall, MORTAR, M.BRICK)
	for shelf in 3:
		_mass.box(Vector3(display.get_center().x, 0.97 + shelf * 0.43, -0.055),
			Vector3(display.size.x * 0.88, 0.035, 0.18), M.WOOD, wood)
	for index in 7:
		var x := display.position.x + (index + 0.7) * display.size.x / 7.5
		_mass.box(Vector3(x, 1.11 + (index % 3) * 0.43, -0.095),
			Vector3(0.19, 0.21, 0.056), M.METAL, Color("b88c57").darkened((index % 3) * 0.13), 0.72)
	_roller(slider, -0.10, wood)
	_canopy(width * 0.90, 2.94, 1.11, wood)
	_sign(frame, "CASA DO PARAFUSO", Vector3(0, 3.08, 1.13), width * 0.83, wood, 0.0068)
	_fixture(frame, Vector3(display.get_center().x, 2.76, 0.51), 3.1, 0.73)


func _residence(frame: Transform3D, width: float, height: float, finish: int, wall: Color, joinery: Color, facade: int,
		number: int, pattern: int) -> void:
	var style := pattern % 7
	var entry_left := pattern % 3 == 1
	var side := -1.0 if entry_left else 1.0
	var door := Rect2(-0.57 + width * side * 0.32, 0.18, 1.14, 2.21)
	var garage := Rect2(-width * side * 0.16 - width * 0.265, 0.055, width * 0.53, 2.36)
	var porch := facade == Facade.OLIVE or (facade == Facade.IVORY and style in [0, 2, 4, 5])
	if porch:
		garage = Rect2(garage.position.x + 0.11, 0.80, garage.size.x - 0.26, 1.56)
	var upper: Array[Rect2] = []
	if height >= 4.3:
		var window_height := minf(1.65, height - 3.11)
		var rhythm := [-0.238, 0.238]
		var sash := 0.236
		if style in [1, 5]:
			rhythm = [-0.282, 0.0, 0.282]
			sash = 0.174
		elif style in [3, 6]:
			rhythm = [-0.176, 0.275]
			sash = 0.287
		for center: float in rhythm:
			upper.append(Rect2(width * (center - sash * 0.5), height - window_height - 0.56, width * sash, window_height))
	var openings: Array[Rect2] = [door, garage]
	openings.append_array(upper)
	_front(width, height, openings, finish, wall)
	_mass.box(Vector3(0, -0.05, 0.084), Vector3(width + 0.03, 0.27, 0.28), M.STONE, STONE)
	if porch:
		_window(garage, joinery, Color("b18a64"), 0.22)
		_arch(garage, 0.28, wall, MORTAR, finish)
		var window_center := garage.get_center().x
		_mass.box(Vector3(window_center, 0.23, 0.29), Vector3(garage.size.x + 0.19, 0.44, 0.49), M.STONE, STONE)
		_mass.box(Vector3(window_center, 0.47, 0.29), Vector3(garage.size.x + 0.26, 0.08, 0.56), M.CERAMIC, MORTAR)
		for x: float in [garage.position.x + 0.23, window_center, garage.end.x - 0.23]:
			_street.add_instance("shrub", "tree_leaves", frame * Vector3(x, 0.80, 0.31), Vector3(0.72, 0.48, 0.43),
				frame.basis.get_euler().y + x, false)
	elif style in [2, 3, 5]:
		_louver_gate(garage, joinery, style == 3)
	else:
		_roller(garage, -0.133, joinery)
	_wood_door(door, joinery)
	_threshold(door.get_center().x, door.size.x + 0.12, 0.18)
	for index in upper.size():
		var pane := Color("966f52") if (number + index * 3) % 7 < 3 else Color("546369")
		var arch := 0.22 if facade in [Facade.IVORY, Facade.BRICK] else 0.0
		_window(upper[index], joinery, pane, arch, height > 4.75 and facade != Facade.BLUE)
		if arch > 0.0:
			_arch(upper[index], arch + 0.04, wall, MORTAR, finish)
	if not upper.is_empty() and style in [0, 2, 6]:
		var level := upper[0].position.y - 0.29
		_balcony(width, level, width * (0.60 if style == 2 else 0.77), joinery, 0.69)
		if style in [0, 6]:
			_balcony_planting(frame, width * 0.205, level, style)
	elif not upper.is_empty() and style in [1, 5]:
		_window_brows(upper, wall.lightened(0.09), joinery, style)
	elif facade == Facade.GARAGE or height < 4.3:
		_canopy(width * 0.66, 2.56, 0.92, joinery)
	else:
		var x := door.get_center().x
		_mass.box(Vector3(x, 2.57, 0.25), Vector3(door.size.x + 0.44, 0.13, 0.75), M.STONE, MORTAR)
	var sign_site := Vector3(door.get_center().x + side * 0.76, 1.64, 0.083)
	_mass.box(sign_site, Vector3(0.25, 0.18, 0.052), M.METAL, joinery)
	_street.lettering(str(number), frame * (sign_site + Vector3.BACK * 0.031),
		frame.basis.get_euler().y, 0.00255, LIGHT_INK)
	if style in [2, 4, 6]:
		var porch_lamp := Vector3(door.get_center().x, 2.51, 0.39)
		_fixture(frame, porch_lamp, 1.68, 0.53)
	if pattern % 5 in [0, 1]:
		_street.planter(frame * Vector3(width * 0.43 * side, 0.143, 0.52), 0.69, number)


func _louver_gate(opening: Rect2, joinery: Color, ventilated: bool) -> void:
	var center := opening.get_center()
	var width := opening.size.x
	var height := opening.size.y
	var z := -0.107
	_mass.box(Vector3(center.x, center.y, z - 0.102), Vector3(width, height, 0.086),
		M.METAL, joinery.darkened(0.47), 0.64)
	for y: float in [opening.position.y + 0.11, opening.end.y - 0.08]:
		_mass.box(Vector3(center.x, y, z), Vector3(width, 0.154, 0.11), M.METAL, joinery)
	var fins := ceili(width / 0.17)
	for index in fins:
		var x := opening.position.x + (index + 0.5) * width / fins
		var shade := joinery.darkened((index % 5) * 0.029)
		var lift := -0.16 if ventilated else 0.0
		_mass.box(Vector3(x, center.y + lift * 0.49, z - 0.036), Vector3(width / fins * 0.79, height + lift - 0.14, 0.041),
			M.METAL, shade, 0.88)
		_mass.box(Vector3(x + 0.022, center.y + lift * 0.49, z - 0.005), Vector3(0.021, height + lift - 0.17, 0.027),
			M.METAL, joinery.lightened(0.052))
	for x: float in [opening.position.x + 0.034, center.x, opening.end.x - 0.034]:
		_mass.box(Vector3(x, center.y, z + 0.031), Vector3(0.097, height, 0.127), M.METAL, joinery.darkened(0.18))
	for x: float in [center.x - 0.151, center.x + 0.151]:
		_mass.box(Vector3(x, center.y - 0.06, z + 0.069), Vector3(0.032, 0.217, 0.042), M.METAL, Color("8c8d7d"))


func _window_brows(upper: Array[Rect2], stone: Color, metal: Color, style: int) -> void:
	for window: Rect2 in upper:
		var x := window.get_center().x
		var h := window.end.y + 0.125
		var size := window.size.x
		if style == 1:
			_mass.quad(Vector3(x - size * 0.60, h, 0.31), Vector3(x + size * 0.60, h, 0.31),
				Vector3(x + size * 0.57, h + 0.16, 0.031), Vector3(x - size * 0.57, h + 0.16, 0.031),
				M.TILE, stone)
			_mass.box(Vector3(x, h - 0.018, 0.306), Vector3(size * 1.24, 0.054, 0.071), M.WOOD, metal)
		else:
			_mass.box(Vector3(x, h, 0.082), Vector3(size * 1.29, 0.137, 0.26), M.STONE, stone)
			for flank: float in [-1.0, 1.0]:
				_mass.box(Vector3(x + size * flank * 0.53, h - 0.23, 0.066),
					Vector3(0.091, 0.44, 0.20), M.STONE, stone.darkened(0.12))


func _balcony_planting(frame: Transform3D, spacing: float, level: float, style: int) -> void:
	var yaw := frame.basis.get_euler().y
	for side: float in [-1.0, 1.0]:
		var x := side * spacing
		_mass.box(Vector3(x, level + 0.27, 0.47), Vector3(0.78, 0.25, 0.34), M.CERAMIC, Color("996d55"))
		_mass.box(Vector3(x, level + 0.408, 0.47), Vector3(0.75, 0.04, 0.32), M.WOOD, Color("67594a"))
		var spot := frame * Vector3(x, level + 0.41, 0.49)
		_street.understory(spot, 0.70 if side < 0.0 else 0.61, yaw + x, style == 0 and side > 0.0)


func _downspout(frame: Transform3D, x: float, height: float, tint: Color) -> void:
	var upper := Vector3(x, height - 0.031, 0.62)
	var elbow := Vector3(x, height - 0.32, 0.119)
	var ground := Vector3(x, 0.19, 0.119)
	var boot := Vector3(x, 0.094, 0.29)
	_street.beam(frame * upper, frame * elbow, 0.038, "zinc")
	_street.beam(frame * elbow, frame * ground, 0.037, "zinc")
	_street.beam(frame * ground, frame * boot, 0.037, "zinc")
	for fraction: float in [0.19, 0.48, 0.77]:
		_mass.box(Vector3(x, height * fraction, 0.075), Vector3(0.107, 0.042, 0.137), M.METAL, tint)


func _roller(opening: Rect2, depth: float, tint: Color) -> void:
	var center := opening.get_center()
	_mass.box(Vector3(center.x, center.y, depth - 0.053), Vector3(opening.size.x, opening.size.y, 0.12), M.METAL, tint.darkened(0.13), 0.72)
	var rows := ceili(opening.size.y / 0.101)
	var step := opening.size.y / rows
	for index in rows:
		var y := opening.position.y + (index + 0.5) * step
		_mass.box(Vector3(center.x, y, depth + 0.018), Vector3(opening.size.x - 0.08, step * 0.79, 0.051),
			M.METAL, tint.darkened((index % 7) * 0.021), 0.82 + float(index) / rows * 0.14)
	for x: float in [opening.position.x, opening.end.x]:
		_mass.box(Vector3(x, center.y, 0.03), Vector3(0.117, opening.size.y, 0.24), M.METAL, tint.darkened(0.16))
	_mass.box(Vector3(center.x, opening.end.y, 0.031), Vector3(opening.size.x + 0.17, 0.127, 0.27), M.STONE, STONE)


func _wood_door(opening: Rect2, tint: Color) -> void:
	var center := opening.get_center()
	_mass.box(Vector3(center.x, center.y, -0.166), Vector3(opening.size.x, opening.size.y, 0.07), M.WOOD, tint.darkened(0.14), 0.70)
	for x: float in [opening.position.x + 0.084, opening.end.x - 0.084]:
		_mass.box(Vector3(x, center.y, -0.015), Vector3(0.151, opening.size.y, 0.22), M.WOOD, tint)
	for y: float in [opening.position.y + 0.18, center.y - 0.11, opening.end.y - 0.084]:
		_mass.box(Vector3(center.x, y, -0.068), Vector3(opening.size.x - 0.19, 0.098, 0.125), M.WOOD, tint)
	_mass.box(Vector3(center.x, center.y + 0.45, -0.114), Vector3(opening.size.x * 0.56, 0.67, 0.031), M.GLASS, Color("7c6852"), 0.55)
	_mass.box(Vector3(center.x + 0.27, center.y - 0.16, -0.062), Vector3(0.13, 0.043, 0.09), M.METAL, Color("af9063"))


func _threshold(x: float, width: float, rise: float) -> void:
	_mass.box(Vector3(x, rise * 0.23, 0.36), Vector3(width + 0.21, rise * 0.60, 0.60), M.STONE, MORTAR)
	_mass.box(Vector3(x, rise * 0.63, 0.20), Vector3(width, rise * 0.75, 0.41), M.CERAMIC, MORTAR)


func _balcony(width: float, base: float, span: float, metal: Color, reach: float) -> void:
	_mass.box(Vector3(0, base, reach * 0.44), Vector3(span + 0.12, 0.22, reach + 0.06), M.STONE, MORTAR)
	_mass.box(Vector3(0, base - 0.12, reach * 0.93), Vector3(span + 0.19, 0.093, 0.17), M.STONE, STONE)
	for x: float in [-span * 0.34, span * 0.34]:
		_mass.box(Vector3(x, base - 0.24, reach * 0.26), Vector3(0.22, 0.31, reach * 0.62), M.STONE, MORTAR)
	var bars := ceili(span / 0.205)
	for index in bars + 1:
		var x := span * (float(index) / bars - 0.5)
		_mass.box(Vector3(x, base + 0.52, reach * 0.94), Vector3(0.029, 0.80, 0.035), M.METAL, metal)
		if index % 4 == 1:
			_mass.box(Vector3(x + 0.073, base + 0.49, reach * 0.94), Vector3(0.113, 0.056, 0.045), M.METAL, metal)
	for y: float in [base + 0.24, base + 0.93]:
		_mass.box(Vector3(0, y, reach * 0.94), Vector3(span + 0.10, 0.049, 0.079), M.METAL, metal)
		for x: float in [-span * 0.5, span * 0.5]:
			_mass.box(Vector3(x, y, reach * 0.47), Vector3(0.055, 0.05, reach), M.METAL, metal)
	for x: float in [-width * 0.19, width * 0.19]:
		_mass.box(Vector3(x, base + 0.30, reach * 0.68), Vector3(width * 0.16, 0.25, 0.26), M.CERAMIC, Color("926b59"))


func _canopy(span: float, y: float, reach: float, tint: Color) -> void:
	var half := span * 0.5
	_mass.quad(Vector3(-half, y, reach), Vector3(half, y, reach),
		Vector3(half, y + 0.20, -0.03), Vector3(-half, y + 0.20, -0.03), M.METAL, tint)
	_mass.box(Vector3(0, y - 0.012, reach), Vector3(span + 0.08, 0.148, 0.124), M.METAL, tint)
	var bays := ceili(span / 0.49)
	for index in range(1, bays):
		var x := span * (float(index) / bays - 0.5)
		_mass.box(Vector3(x, y + 0.097, reach * 0.49), Vector3(0.033, 0.102, reach + 0.04), M.METAL, tint.lightened(0.13))
	for x: float in [-half * 0.84, half * 0.84]:
		_mass.box(Vector3(x, y - 0.20, 0.05), Vector3(0.08, 0.39, 0.25), M.METAL, tint)
		_mass.box(Vector3(x, y - 0.08, reach * 0.43), Vector3(0.08, 0.081, reach * 0.86), M.METAL, tint)


func _sign(frame: Transform3D, title: String, center: Vector3, width: float, tint: Color, size: float) -> void:
	var yaw := frame.basis.get_euler().y
	_mass.box(center, Vector3(width, 0.47, 0.19), M.METAL, tint)
	for y: float in [-0.217, 0.217]:
		_mass.box(center + Vector3(0, y, 0.102), Vector3(width + 0.035, 0.026, 0.055), M.METAL, Color("9b835c"))
	_street.lettering(title, frame * (center + Vector3.BACK * 0.105), yaw, size, LIGHT_INK, true)


func _blade_sign(frame: Transform3D, center: Vector3, title: String, tint: Color) -> void:
	var yaw := frame.basis.get_euler().y
	_mass.box(center, Vector3(0.088, 0.58, 0.78), M.METAL, tint)
	for height: float in [-0.26, 0.26]:
		_mass.box(center + Vector3(0, height, -0.66), Vector3(0.059, 0.062, 1.74), M.METAL, BLACK_STEEL)
	for side: float in [-1.0, 1.0]:
		_street.lettering(title, frame * (center + Vector3.RIGHT * side * 0.047), yaw + PI * side * 0.5,
			0.0031, LIGHT_INK, true)


func _fixture(frame: Transform3D, site: Vector3, radius: float, power: float) -> void:
	_mass.box(site + Vector3.UP * 0.073, Vector3(0.28, 0.105, 0.19), M.METAL, BLACK_STEEL)
	_mass.box(site, Vector3(0.22, 0.041, 0.133), M.LIGHT, LIGHT)
	_street.add_lamp(frame * site, radius, power)


func _roof(width: float, height: float, depth: float, wall: Color, timber: Color, number: int, tiled_front: bool) -> void:
	var edge := width * 0.5 + 0.27
	var front := 0.75
	var back := -depth - 0.45
	var ridge := -depth * 0.49
	var rise := 1.16 + float(number % 5) * 0.154
	var tile := Color("a87457").lerp(Color("765a4c"), float(number % 6) * 0.13)
	_mass.quad(Vector3(edge, height, back), Vector3(-edge, height, back),
		Vector3(-edge, height + rise, ridge), Vector3(edge, height + rise, ridge), M.TILE, tile.darkened(0.10))
	if tiled_front:
		_tile_courses(edge, height, front, ridge, rise, tile)
	else:
		_mass.quad(Vector3(-edge, height, front), Vector3(edge, height, front),
			Vector3(edge, height + rise, ridge), Vector3(-edge, height + rise, ridge), M.TILE, tile)
	for side: float in [-1.0, 1.0]:
		var x := (edge - 0.27) * side
		if side < 0.0:
			_mass.quad(Vector3(x, height, back), Vector3(x, height, front),
				Vector3(x, height + rise, ridge), Vector3(x, height + rise, ridge - 0.02), M.PLASTER, wall, 0.88)
		else:
			_mass.quad(Vector3(x, height, front), Vector3(x, height, back),
				Vector3(x, height + rise, ridge - 0.02), Vector3(x, height + rise, ridge), M.PLASTER, wall, 0.88)
	_mass.box(Vector3(0, height + rise, ridge), Vector3(edge * 2.04, 0.112, 0.22), M.TILE, tile)
	_mass.box(Vector3(0, height - 0.14, 0.36), Vector3(edge * 2.0, 0.18, 0.88), M.WOOD, timber)
	_mass.box(Vector3(0, height - 0.015, front), Vector3(edge * 2.0 + 0.13, 0.109, 0.19), M.METAL, timber)
	var count := ceili(edge * 2.0 / 0.63)
	for index in count:
		var x := edge * (2.0 * (index + 0.5) / count - 1.0)
		_mass.box(Vector3(x, height - 0.29, 0.22), Vector3(0.11, 0.27, 0.54), M.WOOD, timber)
	if number % 4 == 1:
		_mass.box(Vector3(edge * 0.47, height + rise * 0.74, ridge - 0.99), Vector3(0.58, 1.02, 0.53), M.BRICK, wall.darkened(0.21))
		_mass.box(Vector3(edge * 0.47, height + rise * 0.74 + 0.54, ridge - 0.99), Vector3(0.69, 0.12, 0.64), M.STONE, STONE)


func _tile_courses(edge: float, y: float, front: float, ridge: float, rise: float, tile: Color) -> void:
	var columns := ceili(edge * 2.0 / 0.23)
	var courses := ceili((front - ridge) / 0.38)
	for row in courses:
		var t := float(row) / courses
		var t_end := float(row + 1) / courses
		for column in columns:
			var start := -edge + 2.0 * edge * column / columns
			var width := 2.0 * edge / columns
			var shade := float((column * 17 + row * 7) % 9) / 70.0
			for segment in 3:
				var a := float(segment) / 3.0
				var b := float(segment + 1) / 3.0
				var lip_a := sin(a * PI) * 0.067
				var lip_b := sin(b * PI) * 0.067
				_mass.quad(Vector3(start + width * a, y + rise * t + lip_a + 0.028, lerpf(front, ridge, t)),
					Vector3(start + width * b, y + rise * t + lip_b + 0.028, lerpf(front, ridge, t)),
					Vector3(start + width * b, y + rise * t_end + lip_b, lerpf(front, ridge, t_end)),
					Vector3(start + width * a, y + rise * t_end + lip_a, lerpf(front, ridge, t_end)),
					M.TILE, tile.darkened(shade + (1.0 - lip_a / 0.067) * 0.08))


func _parapet(frame: Transform3D, width: float, height: float, depth: float, wall: Color, edge: Color, number: int) -> void:
	var edge_x := width * 0.5
	_mass.box(Vector3(0, height + 0.105, 0.025), Vector3(width + 0.18, 0.23, 0.32), M.PLASTER, wall)
	_mass.box(Vector3(0, height + 0.25, 0.065), Vector3(width + 0.27, 0.085, 0.43), M.STONE, MORTAR)
	for x: float in [-edge_x, edge_x]:
		_mass.box(Vector3(x, height + 0.126, -depth * 0.5), Vector3(0.29, 0.28, depth), M.PLASTER, wall)
	if number % 3 == 0:
		_mass.box(Vector3(width * 0.20, height + 0.53, -depth * 0.56),
			Vector3(2.05, 1.08, 1.65), M.PLASTER, wall.darkened(0.15))
		_mass.box(Vector3(width * 0.20, height + 1.11, -depth * 0.56),
			Vector3(2.24, 0.15, 1.91), M.METAL, edge)
	var mast := frame * Vector3(-width * 0.27, height + 0.12, -depth * 0.59)
	if number % 4 == 2:
		_street.beam(mast, mast + Vector3.UP * 1.62, 0.021, "zinc")
		_street.beam(mast + Vector3(-0.44, 1.49, 0), mast + Vector3(0.49, 1.49, 0), 0.014, "zinc")


func _side_openings(frame: Transform3D, width: float, height: float, depth: float, wall: Color, trim: Color, commercial: bool, number: int) -> void:
	var side := -1.0 if number % 2 == 0 else 1.0
	var x := width * 0.5 * side
	var y := height - (1.17 if height >= 4.0 else 0.92)
	_mass.box(Vector3(x + side * 0.017, y, -depth * 0.33), Vector3(0.11, 0.98, 1.54), M.STONE, wall)
	_mass.box(Vector3(x + side * 0.08, y, -depth * 0.33), Vector3(0.055, 0.82, 1.35), M.GLASS, Color("526165"), 0.62)
	for offset: float in [-0.43, 0.0, 0.43]:
		_mass.box(Vector3(x + side * 0.12, y, -depth * 0.33 + offset), Vector3(0.058, 0.89, 0.044), M.METAL, trim)
	_mass.box(Vector3(x + side * 0.08, y - 0.52, -depth * 0.33), Vector3(0.28, 0.09, 1.61), M.STONE, MORTAR)
	if commercial or number % 3 != 0:
		var base := frame * Vector3(x + side * 0.07, 0.24, -0.21)
		_street.beam(base, base + Vector3.UP * (height - 0.27), 0.038, "zinc")
