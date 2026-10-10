extends Node2D

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const MAP_RECT := Rect2(10, 10, 190, 152)
var roads: Array[PackedVector2Array] = []


func project(point: Vector2) -> Vector2:
	return MAP_RECT.position + (point + Vector2(Layout.HALF_WIDTH, Layout.HALF_DEPTH)) / Vector2(Layout.HALF_WIDTH * 2, Layout.HALF_DEPTH * 2) * MAP_RECT.size


func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.065, 0.88)
	style.set_corner_radius_all(7)
	draw_style_box(style, Rect2(Vector2.ZERO, Vector2(210, 203)))
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
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, 178), "Jardins · Aurora · Horizonte", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eee6d4"))
	draw_string(font, Vector2(10, 194), "N ↑   ·   Parques em verde", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b6c9b3"))
