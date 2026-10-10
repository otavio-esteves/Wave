extends Node2D

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var roads: Array[PackedVector2Array] = []
var lots: Array = []


func _draw() -> void:
	var divisions := [-Layout.HALF_WIDTH, -424.0, 676.0, Layout.HALF_WIDTH]
	for district in 3:
		draw_rect(Rect2(divisions[district], -Layout.HALF_DEPTH, divisions[district + 1] - divisions[district], Layout.HALF_DEPTH * 2), [Color("324b3a"), Color("5b5142"), Color("314657")][district])
	for lot in lots:
		var polygon := PackedVector2Array()
		var basis := Transform2D(-float(lot.yaw), Vector2(lot.center))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			polygon.append(basis * (corner * Vector2(lot.size) / 2))
		draw_colored_polygon(polygon, Color("82a775") if lot.get("kind", "") in ["park", "garden"] else Color("b1a58c"))
	for road in roads:
		draw_polyline(road, Color("bec9c8"), 10.0, true)
