extends Control

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var car: Node3D
var hud: CanvasLayer
var roads: Array[PackedVector2Array] = []
var lots: Array = []
var zoom := 1.0
var pan := Vector2.ZERO
var marker := Vector2.INF
var previously_paused := false
var previous_focus: Control
var dragging := false
var drag_distance := 0.0
var timer := 0.0
var title: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lots = car.get_parent().get_node("City").get_meta("parcel_footprints", [])
	for edge in Layout.edges():
		var line := PackedVector2Array()
		var points := Layout.edge_points(edge.a, edge.b)
		for index in range(0, points.size(), 8):
			line.append(Vector2(points[index].x, points[index].z))
		line.append(Vector2(points[-1].x, points[-1].z))
		roads.append(line)
	title = Label.new()
	title.position = Vector2(22, 15)
	title.text = "WAVE · MAPA DA CIDADE"
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	var bar := HBoxContainer.new()
	bar.position = Vector2(22, 52)
	add_child(bar)
	for item in [["Voltar", close_map], ["Seu carro", center_car], ["Praça", func(): locate(Layout.block_uv(Layout.SQUARE_BLOCK))], ["Oficina", func(): locate(Layout.block_uv(Layout.WORKSHOP_BLOCK))], ["Limpar marcador", func(): marker = Vector2.INF; queue_redraw()]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		bar.add_child(button)
	hide()


func open_map() -> void:
	previously_paused = get_tree().paused
	previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	zoom = 1.0
	pan = Vector2.ZERO
	show()
	grab_focus()
	queue_redraw()


func close_map() -> void:
	dragging = false
	hide()
	get_tree().paused = previously_paused
	if previously_paused:
		if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
			previous_focus.grab_focus()
		else:
			hud.resume_button.grab_focus()
	else:
		release_focus()
		car.get_parent().get_node("ChaseCamera")._capture_mouse()


func center_car() -> void:
	zoom = 2.0
	pan = -Vector2(car.position.x, car.position.z)
	queue_redraw()


func locate(uv: Vector2) -> void:
	var point := Layout.position(uv.x, uv.y)
	marker = Vector2(point.x, point.z)
	pan = -marker
	zoom = 2
	queue_redraw()


func map_scale() -> float:
	return minf((size.x - 70) / (Layout.HALF_WIDTH * 2), (size.y - 180) / (Layout.HALF_DEPTH * 2)) * zoom


func map_center() -> Vector2:
	return Vector2(size.x / 2, (size.y + 70) / 2)


func project(point: Vector2) -> Vector2:
	return map_center() + (point + pan) * map_scale()


func set_marker(screen_point: Vector2) -> void:
	marker = (screen_point - map_center()) / map_scale() - pan
	marker = marker.clamp(Vector2(-Layout.HALF_WIDTH, -Layout.HALF_DEPTH), Vector2(Layout.HALF_WIDTH, Layout.HALF_DEPTH))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not event.is_echo() and (event.is_action_pressed("city_map") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		car.suppress_reset_until_release()
		close_map()
		accept_event()
		return
	if event.is_action_pressed("camera_center"):
		center_car()
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.2), 1, 6)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				drag_distance = 0
			elif drag_distance < 5:
				set_marker(event.position)
	elif event is InputEventMouseMotion and dragging:
		pan += event.relative / map_scale()
		drag_distance += event.relative.length()
	elif event.is_action_pressed("ui_accept"):
		set_marker(map_center())
	pan = pan.clamp(Vector2(-Layout.HALF_WIDTH, -Layout.HALF_DEPTH), Vector2(Layout.HALF_WIDTH, Layout.HALF_DEPTH))
	queue_redraw()
	accept_event()


func _process(delta: float) -> void:
	if not visible:
		return
	var movement := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	pan -= movement * delta * 700 / zoom
	var zoom_input := Input.get_action_strength("map_zoom_in") - Input.get_action_strength("map_zoom_out")
	zoom = clampf(zoom + zoom_input * delta * 2, 1, 6)
	pan = pan.clamp(Vector2(-Layout.HALF_WIDTH, -Layout.HALF_DEPTH), Vector2(Layout.HALF_WIDTH, Layout.HALF_DEPTH))
	timer += delta
	if movement != Vector2.ZERO or zoom_input != 0.0 or timer > 0.1:
		timer = 0
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101c26"))
	for district in 3:
		var divisions := [-Layout.HALF_WIDTH, -424.0, 676.0, Layout.HALF_WIDTH]
		var start := project(Vector2(divisions[district], -Layout.HALF_DEPTH))
		var end := project(Vector2(divisions[district + 1], Layout.HALF_DEPTH))
		draw_rect(Rect2(start, end - start), [Color("324b3a"), Color("5b5142"), Color("314657")][district])
	for lot in lots:
		var polygon := PackedVector2Array()
		var basis := Transform2D(-float(lot.yaw), Vector2(lot.center))
		for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
			polygon.append(project(basis * (corner * Vector2(lot.size) / 2)))
		draw_colored_polygon(polygon, Color("82a775") if lot.get("kind", "") in ["park", "garden"] else Color("b1a58c"))
	for road in roads:
		var line := PackedVector2Array()
		for point in road:
			line.append(project(point))
		draw_polyline(line, Color("bec9c8"), maxf(1.0, map_scale() * 10), true)
	var font := ThemeDB.fallback_font
	for index in 3:
		var p := project(Vector2([-900, 150, 1050][index], -900))
		var label: String = Layout.DISTRICT_NAMES[index]
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, p - Vector2(width / 2, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("fff0c5"))
	for point in [Layout.block_uv(Layout.SQUARE_BLOCK), Layout.block_uv(Layout.WORKSHOP_BLOCK)]:
		var p := Layout.position(point.x, point.y)
		draw_circle(project(Vector2(p.x, p.z)), 5, Color("80d49b"))
	var car_point := project(Vector2(car.position.x, car.position.z))
	var forward := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
	var right := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([car_point + forward * 10, car_point - forward * 6 + right * 6, car_point - forward * 6 - right * 6]), Color("fff3b0"))
	if marker.is_finite():
		draw_circle(project(marker), 8, Color("ef9766"), false, 2, true)
		draw_line(car_point, project(marker), Color(0.94, 0.59, 0.4, 0.55), 1, true)
	# Opaque bars keep zoomed map geometry behind controls and instructions.
	draw_rect(Rect2(0, 0, size.x, 92), Color("101c26"))
	draw_rect(Rect2(0, size.y - 55, size.x, 55), Color("101c26"))
	draw_string(font, Vector2(22, size.y - 32), "Arrastar / direcional: mover · roda / + − / L2 R2: zoom · clique / X: marcador · R3: carro", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c6d1ce"))
	draw_string(font, Vector2(22, size.y - 12), "M / Share: mapa · Esc / círculo: voltar · amarelo: carro · verde: praça e oficina", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("98b4ac"))
