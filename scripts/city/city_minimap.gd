extends Control

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const MAP_RECT := Rect2(10, 10, 190, 152)
var trip: Node
var car: Node3D
var roads: Array[PackedVector2Array] = []
var timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in Layout.edges():
		var line := PackedVector2Array()
		var points := Layout.edge_points(edge.a, edge.b)
		for index in range(0, points.size(), 10):
			line.append(project(Vector2(points[index].x, points[index].z)))
		line.append(project(Vector2(points[-1].x, points[-1].z)))
		roads.append(line)

	# Bake the static 430-street map once; driving draws one cached texture.
	var cache := SubViewport.new()
	cache.name = "StaticMapCache"
	cache.size = Vector2i(210, 203)
	cache.disable_3d = true
	cache.transparent_bg = true
	cache.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(cache)
	var background := preload("res://scripts/city/city_minimap_background.gd").new()
	background.roads = roads
	cache.add_child(background)
	var texture := TextureRect.new()
	texture.texture = cache.get_texture()
	texture.size = Vector2(210, 203)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.show_behind_parent = true
	add_child(texture)


func project(point: Vector2) -> Vector2:
	return MAP_RECT.position + (point + Vector2(Layout.HALF_WIDTH, Layout.HALF_DEPTH)) / Vector2(Layout.HALF_WIDTH * 2, Layout.HALF_DEPTH * 2) * MAP_RECT.size


func _process(delta: float) -> void:
	timer += delta
	if timer >= 0.1:
		timer = 0.0
		queue_redraw()


func _draw() -> void:
	if trip != null and not trip.route.is_empty():
		var path := PackedVector2Array()
		for index in range(trip.route_cursor, trip.route.size(), 8):
			var point: Vector3 = trip.route[index]
			path.append(project(Vector2(point.x, point.z)))
		path.append(project(Vector2(trip.destination.x, trip.destination.z)))
		if path.size() > 1:
			draw_polyline(path, Color("69d6ca"), 2.0, true)
		draw_circle(project(Vector2(trip.destination.x, trip.destination.z)), 3.0, Color("69d6ca"))
	var position := project(Vector2(car.global_position.x, car.global_position.z))
	var heading := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
	var right := Vector2(-heading.y, heading.x)
	draw_circle(position, 5, Color(0.02, 0.03, 0.04, 0.8))
	draw_colored_polygon(PackedVector2Array([position + heading * 6, position - heading * 3 + right * 3.5, position - heading * 3 - right * 3.5]), Color("fff0ac"))
