extends Control

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const MAP_RECT := Rect2(10, 10, 190, 152)
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


func project(point: Vector2) -> Vector2:
	return MAP_RECT.position + (point + Vector2(Layout.HALF_WIDTH, Layout.HALF_DEPTH)) / Vector2(Layout.HALF_WIDTH * 2, Layout.HALF_DEPTH * 2) * MAP_RECT.size


func _process(delta: float) -> void:
	timer += delta
	if timer >= 0.1:
		timer = 0.0
		queue_redraw()


func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, Vector2(210, 203)))
	var colors := [Color("45604a"), Color("6e6250"), Color("455a70")]
	var divisions := [-Layout.HALF_WIDTH, -424.0, 676.0, Layout.HALF_WIDTH]
	for district in 3:
		var start := project(Vector2(divisions[district], -Layout.HALF_DEPTH))
		var end := project(Vector2(divisions[district + 1], Layout.HALF_DEPTH))
		draw_rect(Rect2(start, end - start), colors[district])
	for road in roads:
		draw_polyline(road, Color(0.77, 0.79, 0.75, 0.7), 1, true)
	for id in Layout.PARK_BLOCKS:
		var p := Layout.block_uv(id)
		var site := Layout.position(p.x, p.y)
		draw_circle(project(Vector2(site.x, site.z)), 2.2, Color("85bd77"))
	var position := project(Vector2(car.global_position.x, car.global_position.z))
	var heading := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
	var right := Vector2(-heading.y, heading.x)
	draw_circle(position, 5, Color(0.02, 0.03, 0.04, 0.8))
	draw_colored_polygon(PackedVector2Array([position + heading * 6, position - heading * 3 + right * 3.5, position - heading * 3 - right * 3.5]), Color("fff0ac"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, 178), "Jardins · Aurora · Horizonte", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eee6d4"))
	draw_string(font, Vector2(10, 194), "N ↑   ·   Parques em verde", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b6c9b3"))


func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.065, 0.88)
	style.set_corner_radius_all(7)
	return style
