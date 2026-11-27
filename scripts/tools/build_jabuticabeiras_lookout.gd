extends RefCounted

const Masonry = preload("res://scripts/tools/build_jabuticabeiras_masonry.gd")
const M = Masonry.Finish
const STONE := Color("a8a195")
const BASALT := Color("817e72")
const TRIM := Color("6d8b78")
const TIMBER := Color("8c694e")

var _street
var _masonry: Masonry
var _frame: Transform3D


func _init(street, masonry: Masonry) -> void:
	_street = street
	_masonry = masonry


func build(point: Vector3, yaw: float) -> void:
	_frame = Transform3D(Basis(Vector3.UP, yaw), point)
	_masonry.begin(_frame)
	_terrace()
	_pavilion(Vector3(5.42, 0.33, -4.20))
	_garden()


func _terrace() -> void:
	# Follow the old vehicle boundary with a low wall and a light railing. The
	# middle parapet stays low enough to see the hamlet from the road.
	_street.add_collision(_frame * Vector3(0.0, 0.46, 0.0), Vector3(34.0, 1.03, 0.68), _frame.basis.get_euler().y)
	for wing: float in [-1.0, 1.0]:
		_masonry.box(Vector3(wing * 11.2, 0.39, 0.0), Vector3(11.6, 0.93, 0.71), M.STONE, BASALT)
		_masonry.box(Vector3(wing * 11.2, 0.88, 0.0), Vector3(11.65, 0.14, 0.83), M.STONE, STONE)
	_masonry.box(Vector3(0.0, 0.28, 0.0), Vector3(11.0, 0.75, 0.71), M.STONE, BASALT)
	_masonry.box(Vector3(0.0, 0.69, 0.0), Vector3(10.7, 0.13, 0.85), M.STONE, STONE)
	for index in 6:
		var x := [-13.1, -8.94, -5.18, 5.18, 8.94, 13.1][index] as float
		var high := 1.28 if index in [2, 3] else 1.54
		_pier(Vector3(x, 0.0, 0.0), high, index in [1, 2, 3, 4])
		for side: float in [-1.0, 1.0]:
			_masonry.box(Vector3(x + side * 0.07, 0.74, 0.35), Vector3(0.018, 0.42, 0.026), M.STONE, BASALT)
	_railing(-13.1, -8.94, 0.92, 0.48, 12)
	_railing(-8.94, -5.18, 0.92, 0.38, 11)
	_railing(-5.18, 0.0, 0.74, 0.46, 17)
	_railing(0.0, 5.18, 0.74, 0.46, 17)
	_railing(5.18, 8.94, 0.92, 0.39, 11)
	_railing(8.94, 13.1, 0.92, 0.49, 12)
	var plaque := Vector3(-4.37, 0.97, 0.389)
	_masonry.box(plaque, Vector3(1.81, 0.33, 0.06), M.METAL, Color("9d8762"))
	_masonry.box(plaque + Vector3.BACK * 0.037, Vector3(1.75, 0.277, 0.028), M.METAL, Color("384c44"))
	_street.lettering("LARGO DO IPÊ", _frame * (plaque + Vector3.BACK * 0.064),
		_frame.basis.get_euler().y, 0.0054, Color("e2d4ad"), true)
	_masonry.box(Vector3(0.0, 0.08, -3.22), Vector3(25.4, 0.28, 5.47), M.STONE, BASALT)
	_masonry.box(Vector3(0.0, 0.226, -3.19), Vector3(24.3, 0.056, 5.25), M.STONE, Color("a69b86"))
	for x: float in [-10.9, -7.92, -4.91, -1.87, 1.26, 4.25, 7.21, 10.27]:
		_masonry.box(Vector3(x, 0.259, -3.17), Vector3(0.048, 0.021, 5.16), M.STONE, BASALT)
	_masonry.box(Vector3(0, 0.065, -1.26), Vector3(5.55, 0.16, 1.77), M.STONE, BASALT)
	_masonry.box(Vector3(0, 0.149, -1.61), Vector3(5.15, 0.17, 1.55), M.STONE, Color("9e9384"))


func _railing(left: float, right: float, y: float, height: float, bars: int) -> void:
	var inset := 0.27
	var depth := 0.038
	var run := right - left - inset * 2.0
	var middle := (left + right) * 0.5
	for rail: float in [y + 0.027, y + height]:
		_masonry.box(Vector3(middle, rail, depth), Vector3(run + 0.09, 0.039, 0.069), M.METAL, TRIM)
	for index in bars:
		var x := left + inset + run * index / (bars - 1.0)
		_masonry.box(Vector3(x, y + height * 0.53, depth), Vector3(0.021, height * 0.91, 0.029), M.METAL, TRIM)
		if index % 3 == 1:
			var site := Vector3(x, y + height * 0.57, depth)
			_iron_ring(site, 0.067, 0.098, 8, 0.0075)


func _pier(pos: Vector3, height: float, illuminated: bool) -> void:
	_masonry.box(pos + Vector3.UP * (height * 0.48), Vector3(0.45, height * 0.96, 0.63), M.STONE, STONE)
	_masonry.box(pos + Vector3.UP * (height - 0.10), Vector3(0.51, 0.075, 0.69), M.STONE, STONE.darkened(0.14))
	_masonry.box(pos + Vector3.UP * height, Vector3(0.57, 0.082, 0.75), M.STONE, STONE)
	if illuminated:
		_lantern(pos + Vector3(0, height + 0.17, 0.23), 0.98)


func _pavilion(center: Vector3) -> void:
	var rim := PackedVector3Array()
	for index in 8:
		var angle := PI / 8.0 + TAU * index / 8.0
		rim.append(Vector3(cos(angle), 0, sin(angle)))
	_octagon(center, rim, 2.24, 0.021, 0.34, M.STONE, BASALT)
	_octagon(center, rim, 2.15, 0.36, 0.092, M.STONE, STONE)
	var column_radius := 1.98
	var shoulder := 2.94
	for index in 8:
		var corner := rim[index] * column_radius
		var next := rim[(index + 1) % 8] * column_radius
		_masonry.box(center + corner + Vector3.UP * 0.64, Vector3(0.34, 0.57, 0.33), M.STONE, STONE)
		_beam(center + corner + Vector3.UP * 0.93, center + corner + Vector3.UP * 3.02, 0.053, "steel_gate")
		_masonry.box(center + corner + Vector3.UP * 2.88, Vector3(0.205, 0.12, 0.205), M.WOOD, TIMBER)
		_masonry.box(center + corner + Vector3.UP * 0.95, Vector3(0.191, 0.13, 0.187), M.METAL, TRIM)
		_beam(center + corner + Vector3.UP * shoulder, center + next + Vector3.UP * shoulder, 0.071, "steel_gate")
		var last := center + corner + Vector3.UP * 2.36
		for division in 8:
			var progress := float(division + 1) / 8.0
			var arch := center + corner.lerp(next, progress) + Vector3.UP * (2.36 + sin(PI * progress) * 0.46)
			_beam(last, arch, 0.022, "steel_gate")
			if division < 7 and division in [1, 3, 5]:
				_beam(arch, Vector3(arch.x, center.y + shoulder, arch.z), 0.012, "steel_gate")
			last = arch
		if index not in [0, 1, 2]:
			var rail := center + (corner + next) * 0.5
			_beam(center + corner + Vector3.UP * 1.25, center + next + Vector3.UP * 1.25, 0.030, "steel_gate")
			for bar in 7:
				var site := center + corner.lerp(next, (bar + 1.0) / 8.0)
				_beam(site + Vector3.UP * 0.43, site + Vector3.UP * 1.24, 0.013, "steel_gate")
			_masonry.box(rail + Vector3.UP * 0.71, Vector3(0.45, 0.098, 0.36), M.WOOD, TIMBER)
	_roof(center, rim)
	var interior := center + Vector3(0, 2.60, 0.29)
	_beam(interior, interior + Vector3.UP * 0.52, 0.019, "dark_iron")
	_lantern(interior, 1.36)
	_street.add_lamp(_frame * interior, 4.15, 0.99, 0.87)


func _roof(center: Vector3, rim: PackedVector3Array) -> void:
	var radii := [2.32, 2.20, 1.78, 1.28, 0.76, 0.36, 0.13]
	var heights := [3.03, 3.10, 3.29, 3.56, 3.84, 4.12, 4.32]
	var color := Color("b5a095")
	for index in rim.size():
		var next := (index + 1) % rim.size()
		for strip in radii.size() - 1:
			var lower: float = radii[strip]
			var upper: float = radii[strip + 1]
			var low := center + Vector3.UP * float(heights[strip])
			var high := center + Vector3.UP * float(heights[strip + 1])
			var tone := color.darkened(0.045 * (index % 4) + 0.014 * strip)
			_masonry.quad(low + rim[index] * lower, high + rim[index] * upper,
				high + rim[next] * upper, low + rim[next] * lower, M.TILE, tone)
			if strip == 0:
				_beam(low + rim[index] * lower, low + rim[next] * lower, 0.052, "dark_iron")
			_beam(low + rim[index] * lower, high + rim[index] * upper, 0.029, "ceramic")
	_octagon(center, rim, 0.235, 4.24, 0.21, M.METAL, TRIM)
	_octagon(center, rim, 0.119, 4.43, 0.19, M.METAL, TRIM)
	_beam(center + Vector3.UP * 4.59, center + Vector3.UP * 4.86, 0.034, "steel_gate")


func _octagon(center: Vector3, rim: PackedVector3Array, radius: float, bottom: float,
		height: float, finish: int, tone: Color) -> void:
	for index in rim.size():
		var next := (index + 1) % rim.size()
		var a := center + rim[index] * radius + Vector3.UP * bottom
		var b := center + rim[next] * radius + Vector3.UP * bottom
		var top := Vector3.UP * height
		_masonry.quad(b, a, a + top, b + top, finish, tone.darkened(0.13))
		_masonry.triangle(a + top, center + Vector3.UP * (bottom + height), b + top, finish, tone)


func _lantern(site: Vector3, scale: float) -> void:
	_masonry.box(site, Vector3(0.165, 0.207, 0.165) * scale, M.LIGHT, Color("e1ae6d"))
	for y: float in [-0.118, 0.12]:
		_masonry.box(site + Vector3.UP * y * scale, Vector3(0.254, 0.044, 0.253) * scale, M.METAL, TRIM)
	for x: float in [-0.105, 0.105]:
		for z: float in [-0.105, 0.105]:
			_masonry.box(site + Vector3(x, 0.0, z) * scale, Vector3(0.022, 0.27, 0.022) * scale, M.METAL, TRIM)


func _garden() -> void:
	for x: float in [-9.54, 10.31]:
		_masonry.box(Vector3(x, 0.55, -2.42), Vector3(4.28, 0.69, 2.31), M.STONE, BASALT)
		_masonry.box(Vector3(x, 0.91, -2.41), Vector3(4.40, 0.089, 2.40), M.STONE, STONE)
		_masonry.box(Vector3(x, 0.96, -2.42), Vector3(4.07, 0.032, 2.07), M.WOOD, Color("645446"))
		for plant in 7:
			var stagger := float(plant % 2) * 0.39
			var site := Vector3(x - 1.73 + plant * 0.57, 0.96, -2.03 - stagger)
			_street.understory(_frame * site, 1.09 + 0.15 * (plant % 3), plant * 1.2, plant % 4 == 0)
	for x: float in [-2.67, 2.19]:
		_masonry.box(Vector3(x, 0.59, -3.67), Vector3(2.05, 0.10, 0.48), M.WOOD, TIMBER)
		for y: float in [0.75, 0.87, 1.00]:
			_masonry.box(Vector3(x, y, -3.88), Vector3(2.06, 0.089, 0.044), M.WOOD, TIMBER)
		for leg: float in [-0.76, 0.76]:
			_masonry.box(Vector3(x + leg, 0.43, -3.70), Vector3(0.074, 0.33, 0.41), M.METAL, TRIM)


func _iron_ring(center: Vector3, width: float, height: float, segments: int, thickness: float) -> void:
	var prior := center + Vector3.RIGHT * width
	for index in segments:
		var angle := (index + 1.0) * TAU / segments
		var next := center + Vector3(cos(angle) * width, sin(angle) * height, 0.0)
		_beam(prior, next, thickness, "steel_gate")
		prior = next


func _beam(from: Vector3, to: Vector3, radius: float, material: String) -> void:
	_street.beam(_frame * from, _frame * to, radius, material)
