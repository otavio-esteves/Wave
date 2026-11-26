extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const F = preload("res://scripts/tools/build_jabuticabeiras_facades.gd").Facade

var _street


func _init(street) -> void:
	_street = street


func build(facades: RefCounted) -> void:
	var upper_yaw: float = _street.rotation_for_cross(155.0)
	var upper := Layout.position_at(155.0, 0.0)
	_overlook(upper, upper_yaw)
	facades.add(_point(upper, upper_yaw, Vector3(-9.8, 0.34, -8.1)),
		7.6, 3.4, 6.5, upper_yaw - 0.22, F.OLIVE, true, 104)
	facades.add(_point(upper, upper_yaw, Vector3(12.2, 0.85, -14.8)),
		7.3, 5.1, 6.2, upper_yaw + 0.28, F.BRICK, true, 107)

	var lower_yaw: float = _street.rotation_for_cross(0.8) + PI
	var lower := Layout.position_at(0.8, 0.0)
	_nursery(lower, lower_yaw)
	facades.add(_point(lower, lower_yaw, Vector3(-1.8, -0.10, -7.1)),
		7.8, 3.23, 6.0, lower_yaw + 0.16, F.BLUE, true, 102)
	facades.add(_point(lower, lower_yaw, Vector3(10.6, 0.36, -9.7)),
		6.2, 4.7, 6.4, lower_yaw - 0.19, F.IVORY, true, 109)


func _overlook(origin: Vector3, yaw: float) -> void:
	_part(origin, yaw, Vector3(0.0, 0.52, 0.0), Vector3(34.0, 1.14, 0.72), "basalt_wall", true)
	_part(origin, yaw, Vector3(0.0, 1.10, 0.0), Vector3(34.2, 0.13, 0.86), "coping")
	for x: float in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		_pier(origin, yaw, x, 1.69, 0.67)
	for x: float in [-7.5, -2.5, 2.5, 7.5]:
		_rail(origin, yaw, x, 1.17, 4.45, 0.46, 13)
	_part(origin, yaw, Vector3(-5.0, 1.62, 0.43), Vector3(2.12, 0.32, 0.13), "sign_green")
	_street.lettering("LARGO DO IPÊ", _point(origin, yaw, Vector3(-5.0, 1.62, 0.50)),
		yaw, 0.0068, Color("e5dec8"))
	# Seats and planting sit on the far side of the vehicle barrier.
	for x: float in [-6.4, 5.9]:
		_part(origin, yaw, Vector3(x, 0.37, -2.21), Vector3(4.8, 0.93, 3.20), "basalt_wall")
		_part(origin, yaw, Vector3(x, 0.85, -2.54), Vector3(4.45, 0.10, 1.89), "soil")
		for index in 4:
			var plant := _point(origin, yaw, Vector3(x - 1.47 + index * 0.95, 1.26, -2.52))
			_street.add_instance("shrub", "tree_leaves", plant,
				Vector3(1.55, 0.97 + 0.09 * index, 1.3), yaw + index, false)
	for x: float in [-2.8, 2.3]:
		for y: float in [0.64, 0.81, 0.98]:
			_part(origin, yaw, Vector3(x, y, -3.8), Vector3(1.91, 0.095, 0.045), "wood")
		_part(origin, yaw, Vector3(x, 0.53, -3.56), Vector3(1.91, 0.085, 0.50), "wood")
		for leg: float in [-0.69, 0.69]:
			_part(origin, yaw, Vector3(x + leg, 0.28, -3.59), Vector3(0.08, 0.57, 0.41), "dark_iron")


func _nursery(origin: Vector3, yaw: float) -> void:
	_part(origin, yaw, Vector3(0.0, 0.16, 0.0), Vector3(34.1, 0.47, 0.64), "basalt_wall", true)
	for side: float in [-1.0, 1.0]:
		_part(origin, yaw, Vector3(side * 9.45, 0.64, 0.0), Vector3(12.25, 1.39, 0.51), "basalt_wall", true)
		_part(origin, yaw, Vector3(side * 9.45, 1.32, 0.0), Vector3(12.35, 0.12, 0.64), "coping")
		for x: float in [3.14, 7.40, 11.67]:
			_pier(origin, yaw, side * x, 2.65, 0.51)
		for x: float in [5.27, 9.54]:
			_rail(origin, yaw, side * x, 1.36, 3.72, 1.0, 15)
		_rail(origin, yaw, side * 1.43, 0.32, 2.77, 1.83, 13)
		_part(origin, yaw, Vector3(side * 1.43, 0.61, 0.19), Vector3(2.75, 0.55, 0.12), "steel_gate")
		_street.beam(_point(origin, yaw, Vector3(side * 0.23, 0.84, 0.24)),
			_point(origin, yaw, Vector3(side * 2.67, 2.04, 0.24)), 0.023, "steel_gate")
		_street.planter(_point(origin, yaw, Vector3(side * 3.85, 0.38, -1.6)), 1.18, yaw)
	_street.add_collision(_point(origin, yaw, Vector3(0.0, 1.12, 0.0)), Vector3(5.78, 2.16, 0.32), yaw)
	_part(origin, yaw, Vector3(0.0, 2.48, 0.08), Vector3(6.72, 0.24, 0.48), "wood")
	_part(origin, yaw, Vector3(0.0, 2.69, 0.07), Vector3(7.14, 0.47, 1.52), "roof_tile", false, "tiled_hip")
	_part(origin, yaw, Vector3(0.0, 2.48, 0.35), Vector3(2.55, 0.34, 0.09), "shop_sign_green")
	_street.lettering("VIVEIRO MUNICIPAL", _point(origin, yaw, Vector3(0.0, 2.48, 0.40)),
		yaw, 0.0062, Color("eaddbb"))


func _pier(origin: Vector3, yaw: float, x: float, height: float, width: float) -> void:
	_part(origin, yaw, Vector3(x, height * 0.49, 0.04), Vector3(width, height, 0.76), "plaster_trim")
	_part(origin, yaw, Vector3(x, height, 0.04), Vector3(width + 0.14, 0.10, 0.88), "coping")


func _rail(origin: Vector3, yaw: float, center: float, base: float, width: float, height: float, bars: int) -> void:
	for y: float in [base + 0.04, base + height]:
		_part(origin, yaw, Vector3(center, y, 0.16), Vector3(width, 0.046, 0.061), "steel_gate")
	for index in bars:
		var x := center + (float(index) / (bars - 1) - 0.5) * (width - 0.06)
		_part(origin, yaw, Vector3(x, base + height * 0.50, 0.16),
			Vector3(0.027, height - 0.018, 0.038), "steel_gate")


func _part(origin: Vector3, yaw: float, offset: Vector3, size: Vector3, material: String,
		solid := false, mesh := "box") -> void:
	_street.add_part(origin, offset, size, material, yaw, solid, mesh)


func _point(origin: Vector3, yaw: float, local: Vector3) -> Vector3:
	return origin + Basis(Vector3.UP, yaw) * local
