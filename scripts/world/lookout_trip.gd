extends Node

const Layout = preload("res://scripts/world/elevation_layout.gd")
const GATES := [-100.0, -200.0, -280.0]
const PARK_SECONDS := 2.0
var state := "driving"
var next_gate := 0
var parked_seconds := 0.0
var car: PlayerCar
var streamer: WorldStreamer
var previous := Vector3.ZERO
var panel: PanelContainer
var label: Label
var progress: ProgressBar


func _ready() -> void:
	process_physics_priority = 5
	car = get_parent().get_node("PlayerCar")
	streamer = get_parent().get_node("WorldStreamer")
	car.car_reset.connect(restart)
	_build_readout()
	restart()


func restart() -> void:
	state = "driving"
	next_gate = 0
	parked_seconds = 0.0
	previous = car.global_position
	_update_readout()


func cancel() -> void:
	state = "restart"
	next_gate = 0
	parked_seconds = 0.0
	previous = car.global_position
	_update_readout()


func _physics_process(delta: float) -> void:
	var current := car.global_position
	# A position jump cannot award route progress or an arrival.
	if current.distance_to(previous) > maxf(car.forward_speed, car.reverse_speed) * delta + 2.0:
		cancel()
	if state in ["driving", "parking"]:
		if streamer.blocked or not car.is_on_floor():
			parked_seconds = 0.0
		else:
			if next_gate < GATES.size():
				var z: float = GATES[next_gate]
				if previous.z > z and current.z <= z:
					var crossing := previous.lerp(current, (previous.z - z) / (previous.z - current.z))
					if absf(crossing.x - Layout.center_x(z)) <= 8 and absf(crossing.y - Layout.height(z) - 0.36) < 1:
						next_gate += 1
						if next_gate == GATES.size():
							state = "parking"
			if state == "parking":
				var offset := current.x - Layout.center_x(current.z)
				var inside := current.z >= Layout.PARK_Z_MIN and current.z <= Layout.PARK_Z_MAX and offset >= Layout.PARK_LANE_MIN and offset <= Layout.PARK_LANE_MAX and absf(current.y - Layout.height(current.z) - 0.36) < 1
				if inside and car.velocity.length() <= 2.0 / 3.6:
					parked_seconds += delta
					if parked_seconds >= PARK_SECONDS:
						state = "complete"
				else:
					parked_seconds = 0.0
	previous = current
	_update_readout()


func _build_readout() -> void:
	panel = PanelContainer.new()
	panel.name = "LookoutTrip"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 20
	panel.offset_right = 360
	panel.offset_top = -132
	panel.offset_bottom = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.88)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	box.add_child(label)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(progress)
	var overlay := get_parent().get_node("HUD/Overlay")
	overlay.add_child(panel)
	overlay.move_child(panel, overlay.get_node("PauseMenu").get_index())


func _update_readout() -> void:
	if label == null:
		return
	var destination := Layout.point(Layout.LOOKOUT_Z, 21)
	var metres := roundi(car.global_position.distance_to(destination))
	var guidance := "Siga a estrada até a serra."
	if next_gate == 1:
		guidance = "Suba pela curva da serra."
	elif next_gate == 2:
		guidance = "O mirante fica logo adiante."
	label.text = "PASSEIO AO MIRANTE · %d m\n%s" % [metres, guidance]
	progress.value = next_gate * 85.0 / GATES.size()
	if state == "parking":
		label.text = "MIRANTE À DIREITA\nPare nas vagas marcadas e segure o freio de mão."
		progress.value = 85 + 15 * minf(parked_seconds / PARK_SECONDS, 1)
	elif state == "complete":
		label.text = "MIRANTE ALCANÇADO\nExplore a vista · R para repetir o passeio."
		progress.value = 100
	elif state == "restart":
		label.text = "PASSEIO AO MIRANTE\nR para voltar ao início e começar o passeio."
		progress.value = 0
