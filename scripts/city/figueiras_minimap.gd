extends Control

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const FRAME := Rect2(0, 0, 176, 146)
const MAP := Rect2(12, 11, 152, 124)
var car: PlayerCar
var _elapsed := 0.0
var _routes: Array[PackedVector2Array] = []
var _lake := PackedVector2Array()


func _ready() -> void:
	for route in Layout.scenic_routes():
		var projected := PackedVector2Array()
		for index in range(0, route.points.size() - 1, 3):
			projected.append(_project(route.points[index]))
		projected.append(_project(route.points[-1]))
		_routes.append(projected)
	for index in 32:
		_lake.append(_project(Layout.LAKE + Layout.lake_outline(TAU * index / 32.0) * 0.93))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.10:
		_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	draw_rect(FRAME, Color(0.038, 0.067, 0.080, 0.91))
	draw_rect(FRAME, Color("526162"), false, 1.0)
	var bounds := Layout.STREET_BOUNDS
	draw_colored_polygon(_lake, Color("47687e"))
	draw_rect(Rect2(_project(Layout.PLAZA.position), _project(Layout.PLAZA.end) - _project(Layout.PLAZA.position)), Color("456c55"))
	for x: float in Layout.COLUMNS:
		var collector := x == Layout.COLLECTOR
		draw_line(_project(Vector2(x, bounds.position.y)), _project(Vector2(x, bounds.end.y)), Color("c2c8bb"), 2.3 if collector else 1.5, true)
	for z: float in Layout.ROWS:
		var avenue := z == Layout.AVENUE
		draw_line(_project(Vector2(bounds.position.x, z)), _project(Vector2(bounds.end.x, z)), Color("e4c47e") if avenue else Color("c2c8bb"), 3.5 if avenue else 1.5, true)
	for route in _routes:
		draw_polyline(route, Color("9ac4bc"), 2.15, true)
	draw_circle(_project(Layout.MARKET), 3.3, Color("e4c47e"), true, -1, true)
	draw_circle(_project(Layout.PLAZA.get_center()), 3.3, Color("a7d99b"), true, -1, true)
	var point := _project(Vector2(car.global_position.x, car.global_position.z)).clamp(Vector2(5, 5), FRAME.end - Vector2(5, 5))
	var heading := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
	var right := heading.orthogonal()
	draw_circle(point, 5.4, Color("182325"), true, -1, true)
	draw_colored_polygon(PackedVector2Array([point + heading * 6.6, point - heading * 3.6 + right * 4.0, point - heading * 3.6 - right * 4.0]), Color("fff1c9"))


func _project(point: Vector2) -> Vector2:
	var scale := minf(MAP.size.x / Layout.MAP_BOUNDS.size.x, MAP.size.y / Layout.MAP_BOUNDS.size.y)
	return MAP.get_center() + (point - Layout.MAP_BOUNDS.get_center()) * scale
