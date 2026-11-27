extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const Masonry = preload("res://scripts/tools/build_jabuticabeiras_masonry.gd")
const Lookout = preload("res://scripts/tools/build_jabuticabeiras_lookout.gd")
const Nursery = preload("res://scripts/tools/build_jabuticabeiras_nursery.gd")
const F = preload("res://scripts/tools/build_jabuticabeiras_facades.gd").Facade

var _street


func _init(street) -> void:
	_street = street


func build(facades: RefCounted, masonry: Masonry) -> void:
	var upper_yaw: float = _street.rotation_for_cross(155.0)
	var upper := Layout.position_at(155.0, 0.0)
	Lookout.new(_street, masonry).build(upper, upper_yaw)
	facades.add(_point(upper, upper_yaw, Vector3(-9.8, 0.34, -8.1)),
		7.6, 3.4, 6.5, upper_yaw - 0.22, F.OLIVE, true, 104)
	facades.add(_point(upper, upper_yaw, Vector3(14.7, 0.74, -16.35)),
		7.3, 5.1, 6.2, upper_yaw + 0.28, F.BRICK, true, 107)

	var lower_yaw: float = _street.rotation_for_cross(0.8) + PI
	var lower := Layout.position_at(0.8, 0.0)
	Nursery.new(_street, masonry).build(lower, lower_yaw)
	facades.add(_point(lower, lower_yaw, Vector3(10.6, 0.36, -9.7)),
		6.2, 4.7, 6.4, lower_yaw - 0.19, F.IVORY, true, 109)


func _point(origin: Vector3, yaw: float, local: Vector3) -> Vector3:
	return origin + Basis(Vector3.UP, yaw) * local
