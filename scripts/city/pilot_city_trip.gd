extends Node

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const Navigation = preload("res://scripts/city/pilot_city_navigation.gd")
const PARK_SECONDS := 2.0
const ARRIVAL_RADIUS := 7.0
var state := "idle"
var parked_seconds := 0.0
var route := PackedVector3Array()
var route_cursor := 0
var remaining_metres := 0.0
var destination := Vector3.ZERO
var car: PlayerCar
var navigation: RefCounted
var panel: PanelContainer
var label: Label
var progress: ProgressBar
var _previous := Vector3.ZERO
var _readout_timer := 0.0
var _route_timer := 0.0


func _ready() -> void:
	process_physics_priority = 5
	car = get_parent().get_node("PlayerCar")
	car.car_reset.connect(_on_reset)
	_previous = car.global_position
	navigation = Navigation.new()
	_build_readout()


func start() -> void:
	state = "to_square"
	parked_seconds = 0.0
	_previous = car.global_position
	_set_destination()
	panel.show()
	_update_readout()


func cancel() -> void:
	state = "idle"
	parked_seconds = 0.0
	route.clear()
	panel.hide()


func _on_reset() -> void:
	if state in ["to_square", "to_workshop", "complete", "interrupted"]:
		start()
	else:
		_previous = car.global_position


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused and event.is_action_pressed("city_activity") and not event.is_echo():
		if state in ["to_square", "to_workshop"]:
			cancel()
		else:
			start()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var current := car.global_position
	if state in ["to_square", "to_workshop"]:
		if current.distance_to(_previous) > maxf(car.forward_speed, car.reverse_speed) * delta + 2.0:
			state = "interrupted"
			parked_seconds = 0.0
			route.clear()
		elif car.is_on_floor() and car.velocity.length() <= 2.0 / 3.6 and current.distance_to(destination) <= ARRIVAL_RADIUS:
			parked_seconds += delta
			if parked_seconds >= PARK_SECONDS:
				state = "to_workshop" if state == "to_square" else "complete"
				parked_seconds = 0.0
				if state == "to_workshop":
					_set_destination()
				else:
					route.clear()
		else:
			parked_seconds = 0.0
	_previous = current
	_readout_timer += delta
	_route_timer += delta
	if _readout_timer >= 0.2:
		_readout_timer = 0.0
		_update_route_progress()
		_update_readout()


func _set_destination() -> void:
	var access := Layout.square_access() if state == "to_square" else Layout.workshop_access()
	destination = access[-1]
	var departure := PackedVector3Array()
	if state == "to_workshop" and car.global_position.distance_to(Layout.square_access()[-1]) < 20.0:
		departure = Layout.square_access()
	route = navigation.route_to_access(car.global_position, access, departure)
	route_cursor = 0
	_route_timer = 0.0


func _update_route_progress() -> void:
	if route.is_empty():
		return
	var nearest := INF
	var index := route_cursor
	for step in range(maxi(0, route_cursor - 8), mini(route.size(), route_cursor + 160)):
		var distance := car.global_position.distance_squared_to(route[step])
		if distance < nearest:
			nearest = distance
			index = step
	route_cursor = index
	# Recalculate after a wrong turn, with a cooldown rather than every frame.
	if nearest > 24.0 * 24.0 and _route_timer > 3.0:
		_set_destination()
	remaining_metres = car.global_position.distance_to(route[route_cursor])
	for step in range(route_cursor, route.size() - 1):
		remaining_metres += route[step].distance_to(route[step + 1])


func _build_readout() -> void:
	panel = PanelContainer.new()
	panel.name = "CityTrip"
	panel.position = Vector2(20, 82)
	panel.custom_minimum_size = Vector2(350, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.09, 0.9)
	style.border_color = Color("86c7bd")
	style.border_width_left = 3
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 16)
	box.add_child(label)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 6
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(progress)
	var overlay := get_parent().get_node("HUD/Overlay")
	overlay.add_child(panel)
	overlay.move_child(panel, overlay.get_node("PauseMenu").get_index())
	panel.hide()


func _update_readout() -> void:
	var controller := not Input.get_connected_joypads().is_empty()
	var key := "↑ no direcional" if controller else "T"
	var place := "Praça dos Ipês" if state == "to_square" else "Oficina Alvorada"
	label.text = "PASSEIO PELA CIDADE · %s\n%s · %d m pelo percurso" % ["1 / 2" if state == "to_square" else "2 / 2", place, roundi(remaining_metres)]
	progress.value = parked_seconds / PARK_SECONDS * 100.0
	if car.global_position.distance_to(destination) < 18.0 and state in ["to_square", "to_workshop"]:
		label.text = "%s\nPare no acesso marcado por dois segundos." % place.to_upper()
	elif state == "to_workshop" and car.global_position.distance_to(Layout.square_access()[-1]) < 20.0:
		label.text = "OFICINA ALVORADA · %d m\nSaia de ré pelo acesso e siga a rota." % roundi(remaining_metres)
	elif state == "complete":
		label.text = "PASSEIO CONCLUÍDO\nExplore a cidade · %s para repetir." % key
		progress.value = 100.0
	elif state == "interrupted":
		label.text = "PASSEIO INTERROMPIDO\n%s para começar um novo percurso." % key
