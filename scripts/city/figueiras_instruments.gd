extends Control

const INK := Color("e9eee6")
const SOFT_INK := Color("a7bcb8")
const ACCENT := Color("77d3b5")
const WARNING := Color("e9a26c")
var car: PlayerCar
var clock: Node
var speed := 0
var gear := 0
var revs := 0.0
var caption := ""
var _refresh := 0.0
var _panel := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.bg_color = Color("111f23e9")
	_panel.border_color = Color("516768a8")
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(11)


func _process(delta: float) -> void:
	visible = not get_tree().paused
	if not visible:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.04
	var value := roundi(car.get_speed_kmh())
	var selected := -1 if car.drive_speed < -0.32 else (car.gearbox.gear if value > 1 else 0)
	var rate := clampf(car.gearbox.rpm / 6350.0, 0.0, 1.0)
	var ground := car.surface_name.capitalize()
	if car.surface_water > 0.5 and car.surface_name == "asfalto":
		ground = "Asfalto molhado"
	var context: String = "%s  ·  %s" % [clock.clock_text(), ground] if clock != null else ground
	if value != speed or selected != gear or absf(rate - revs) > 0.022 or context != caption:
		speed = value
		gear = selected
		revs = rate
		caption = context
		queue_redraw()


func _draw() -> void:
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	var acceleration_color := WARNING if revs > 0.84 else ACCENT
	for index in 18:
		var mark := Rect2(Vector2(14.0 + index * 10.65, 12.0), Vector2(7.2, 3.55))
		draw_rect(mark, acceleration_color if (index + 1.0) / 18.0 <= revs else Color("425659"))
	draw_string(font, Vector2(13, 61), "%03d" % speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 39, INK)
	draw_string(font, Vector2(98, 60), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SOFT_INK)
	draw_rect(Rect2(167, 27, 35, 39), Color("2d4446"))
	var text := "R" if gear < 0 else ("N" if gear == 0 else str(gear))
	draw_string(font, Vector2(167, 55), text, HORIZONTAL_ALIGNMENT_CENTER, 35, 23, INK)
	draw_string(font, Vector2(14, 85), caption, HORIZONTAL_ALIGNMENT_LEFT, 190, 14, SOFT_INK)
