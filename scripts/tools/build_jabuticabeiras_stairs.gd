extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const F = preload("res://scripts/tools/build_jabuticabeiras_facades.gd").Facade
const Masonry = preload("res://scripts/tools/build_jabuticabeiras_masonry.gd")
const M = Masonry.Finish
const STATION := 32.5
const STEP_DEPTH := 0.43
const STEP_RISE := 0.164
const STEPS := 14
const HALF_WIDTH := 1.83

var _street
var _masonry: Masonry
var _frame := Transform3D.IDENTITY
var _yaw := 0.0


func _init(street, masonry: Masonry) -> void:
	_street = street
	_masonry = masonry


func build(facades: RefCounted) -> void:
	var inward := -Layout.right(STATION)
	_yaw = atan2(inward.x, inward.y)
	var origin := Layout.position_at(STATION, Layout.half_width(STATION) + Layout.SIDEWALK_WIDTH + 0.34, 0.158)
	_frame = Transform3D(Basis(Vector3.UP, _yaw), origin)
	_masonry.begin(_frame)
	_box(Vector3(0, -0.06, 0.05), Vector3(4.1, 0.15, 1.42), "basalt_wall")
	for index in STEPS:
		var z := -0.64 - index * STEP_DEPTH
		var y := (index + 1) * STEP_RISE
		_box(Vector3(0, y * 0.5 - 0.13, z), Vector3(HALF_WIDTH * 2.0, y + 0.24, STEP_DEPTH), "basalt_wall", true)
		_treads(index, y, z)
		for side: float in [-1.0, 1.0]:
			var x := side * (HALF_WIDTH + 0.22)
			_box(Vector3(x, y * 0.5 + 0.17, z), Vector3(0.43, y + 0.74, STEP_DEPTH + 0.014), "basalt_wall", true)
			_box(Vector3(x, y + 0.57, z), Vector3(0.51, 0.066, STEP_DEPTH + 0.018), "coping")
			if index % 3 == 0:
				_post(Vector3(x, y + 0.60, z))
	for direction: float in [-1.0, 1.0]:
		var x := direction * (HALF_WIDTH + 0.22)
		_street.beam(_frame * Vector3(x, 0.98, -0.34), _frame * Vector3(x, STEPS * STEP_RISE + 0.91, -6.44),
			0.035, "dark_iron")
		_box(Vector3(x, 0.64, 0.34), Vector3(0.59, 1.46, 0.61), "basalt_wall", true)
		_box(Vector3(x, 1.38, 0.34), Vector3(0.67, 0.12, 0.72), "coping")
		_box(Vector3(x, 1.53, 0.34), Vector3(0.24, 0.20, 0.25), "amber_light")
		_box(Vector3(x, 1.65, 0.34), Vector3(0.32, 0.055, 0.32), "dark_iron")
		_street.add_lamp(_frame * Vector3(x, 1.52, 0.49), 2.5, 0.74, 0.53)
		_planting(direction)
	_upper_trellis()
	_stairs_sign()
	_courtyard(facades)


func _treads(index: int, y: float, z: float) -> void:
	var breaks := [-1.85, -0.99 + 0.08 * sin(index * 2.2), 0.073 + 0.11 * cos(index * 1.8),
		0.92 + 0.13 * sin(index * 1.3), 1.85]
	for block in breaks.size() - 1:
		var left: float = breaks[block] + 0.006
		var right: float = breaks[block + 1] - 0.006
		var face := z + STEP_DEPTH * 0.526
		var lift := 0.021 + 0.008 * sin(block * 1.98 + index * 2.4)
		var tone := Color("a9a496").darkened(0.027 * ((block * 6 + index * 3) % 7))
		_masonry.box(Vector3((left + right) * 0.5, y + 0.011, z + 0.012),
			Vector3(right - left, 0.049, STEP_DEPTH + 0.029), M.STONE, tone)
		_masonry.quad(Vector3(left, y - 0.018, face + 0.033), Vector3(right, y - 0.018, face + 0.033),
			Vector3(right, y + lift, face + 0.017), Vector3(left, y + lift, face + 0.017), M.STONE, tone.darkened(0.12))


func _planting(direction: float) -> void:
	var edge := direction * (HALF_WIDTH + 0.60)
	for branch in 5:
		var site := Vector3(edge + 0.13 * direction, 0.08 + branch * 0.112, -0.38 - 0.71 * branch)
		if branch in [0, 3]:
			_street.planter(_frame * site, 0.91 + 0.12 * branch, _yaw + direction * 0.5)
		else:
			_street.understory(_frame * site, 1.10 + 0.12 * (branch % 2), _yaw + branch * 1.73, branch == 2)


func _upper_trellis() -> void:
	var level := STEPS * STEP_RISE
	var rear := -7.91
	var near := -6.96
	var upper := level + 2.35
	var timber := Color("8d7054")
	for x: float in [-2.33, 2.33]:
		_masonry.box(Vector3(x, level + 1.16, rear), Vector3(0.15, 2.37, 0.16), M.WOOD, timber)
		_masonry.box(Vector3(x, level + 0.21, rear), Vector3(0.29, 0.406, 0.28), M.STONE, Color("a19c89"))
		_street.beam(_frame * Vector3(x, upper - 0.48, rear), _frame * Vector3(x * 0.77, upper - 0.10, near),
			0.027, "steel_gate")
	_masonry.box(Vector3(0, upper, rear), Vector3(5.09, 0.142, 0.125), M.WOOD, timber)
	_masonry.box(Vector3(0, upper - 0.08, near), Vector3(5.19, 0.12, 0.13), M.WOOD, timber)
	for slat in 13:
		var x := (slat - 6.0) * 0.38
		_masonry.box(Vector3(x, upper + 0.031, (near + rear) * 0.5), Vector3(0.062, 0.073, 1.20), M.WOOD, timber)
	for site: Vector3 in [Vector3(-1.91, upper - 0.24, rear), Vector3(-1.44, upper - 0.19, near),
			Vector3(1.87, upper - 0.21, rear), Vector3(2.29, upper - 0.42, near)]:
		_street.understory(_frame * site, 0.89, site.x * 1.37, absf(site.x) > 2.0)
	var lantern := Vector3(0.0, upper - 0.25, rear + 0.42)
	_masonry.box(lantern, Vector3(0.29, 0.093, 0.18), M.LIGHT, Color("ebbc7a"))
	_street.add_lamp(_frame * lantern, 2.60, 0.75, 0.48)


func _stairs_sign() -> void:
	var plaque := Vector3(-1.99, 1.16, 0.675)
	_masonry.box(plaque, Vector3(0.84, 0.28, 0.053), M.WOOD, Color("6d6451"))
	_masonry.box(plaque + Vector3.BACK * 0.035, Vector3(0.78, 0.234, 0.031), M.METAL, Color("546779"))
	for x: float in [-0.39, 0.39]:
		_masonry.box(plaque + Vector3(x, 0.0, 0.049), Vector3(0.017, 0.24, 0.015), M.STONE, Color("bdb697"))
	_street.lettering("ESCADARIA\nDAS FIGUEIRAS", _frame * (plaque + Vector3.BACK * 0.055),
		_yaw, 0.00365, Color("ebdcac"), true)


func _courtyard(facades: RefCounted) -> void:
	var level := STEPS * STEP_RISE
	_box(Vector3(0, level * 0.5 - 0.065, -8.10), Vector3(5.66, level + 0.18, 3.70), "basalt_wall", true)
	_box(Vector3(0, level + 0.018, -8.10), Vector3(5.71, 0.081, 3.74), "window_sill")
	for side: float in [-1.0, 1.0]:
		var x := side * 2.55
		_box(Vector3(x, level + 0.31, -8.34), Vector3(0.51, 0.62, 3.08), "basalt_wall")
		_box(Vector3(x, level + 0.644, -8.34), Vector3(0.60, 0.075, 3.18), "coping")
		for z: float in [-7.52, -9.04]:
			_street.planter(_frame * Vector3(x * 0.91, level + 0.70, z), 0.81, _yaw)
	facades.add(_frame * Vector3(0, level + 0.056, -9.72), 5.48, 3.52, 4.18, _yaw, F.IVORY, true, 118)


func _post(base: Vector3) -> void:
	_box(base + Vector3.UP * 0.31, Vector3(0.047, 0.62, 0.047), "dark_iron")


func _box(center: Vector3, size: Vector3, material: String, solid := false) -> void:
	_street.add_box(_frame * center, size, material, solid, _yaw)
