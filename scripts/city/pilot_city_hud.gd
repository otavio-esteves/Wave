extends "res://scripts/prototype_hud.gd"

var help_panel: PanelContainer
var help_label: Label


func _ready() -> void:
	super._ready()
	# Keep the driving screen focused on the current city and its controls.
	buttons.get_node("Race").hide()
	buttons.get_node("Rally").hide()
	$Overlay/Telemetry.offset_left = -315
	readout.add_theme_font_size_override("font_size", 21)
	help_panel = PanelContainer.new()
	help_panel.name = "DrivingHelp"
	help_panel.position = Vector2(20, 190)
	help_panel.custom_minimum_size = Vector2(500, 0)
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.09, 0.94)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	help_panel.add_theme_stylebox_override("panel", style)
	help_label = Label.new()
	help_label.add_theme_font_size_override("font_size", 16)
	help_panel.add_child(help_label)
	$Overlay.add_child(help_panel)
	help_panel.hide()
	_update_control_help()
	var help_button := Button.new()
	help_button.text = "Controles"
	help_button.custom_minimum_size.y = 42
	buttons.add_child(help_button)
	help_button.pressed.connect(_toggle_help)
	buttons.move_child(buttons.get_node("Exit"), buttons.get_child_count() - 1)


func _process(delta: float) -> void:
	var cycle := world.get_node_or_null("DayNightCycle")
	if cycle == null:
		return
	var gear := "R" if car.drive_speed < -0.2 else ("D" if car.drive_speed > 0.2 else "N")
	var district: String = preload("res://scripts/city/pilot_city_layout.gd").district_at(car.global_position.x)
	readout.text = "%03d km/h  ·  %s\n%s  ·  %s" % [roundi(car.get_speed_kmh()), gear, cycle.clock_text(), district]
	if diagnostics.visible:
		_diagnostic_timer += delta
		if _diagnostic_timer >= 0.5:
			_diagnostic_timer = 0.0
			_refresh_diagnostics()


func _update_control_help(_device: int = -1, _connected: bool = false) -> void:
	var controller := not Input.get_connected_joypads().is_empty()
	var hints := "Share: mapa   ↑ direcional: passeio   ← direcional: controles   Options: pausa" if controller else "M: mapa   T: passeio   H: controles   Esc: pausa"
	$Overlay/Controls.text = "WAVE · %s\n%s" % [world.world_title, hints]
	if help_label != null:
		help_label.text = "CONTROLES\n"
		if controller:
			help_label.text += "Analógico E: direção · R2 / L2: acelerar / frear\nAnalógico D: câmera · R3: centralizar\nX: freio de mão · Quadrado: câmera · Triângulo: olhar atrás\nCírculo: reiniciar · L1: faróis · R1: avançar horário\nShare: mapa · ↑: passeio · ←: fechar controles"
		else:
			help_label.text += "WASD / setas: dirigir · Espaço: freio de mão\nMouse: câmera · V: câmera · C: olhar atrás\nR: reiniciar · L: faróis · F6: avançar horário\nM: mapa · T: iniciar / cancelar passeio · H: fechar controles"


func _unhandled_input(event: InputEvent) -> void:
	if city_map != null and city_map.visible:
		super._unhandled_input(event)
		return
	if help_panel.visible and not event.is_echo() and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		car.suppress_reset_until_release()
		_toggle_help()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("driving_help") and not event.is_echo():
		_toggle_help()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("city_map") and help_panel.visible:
		_toggle_help()
	super._unhandled_input(event)


func _toggle_help() -> void:
	if not help_panel.visible and get_tree().paused:
		if audio_options.visible:
			audio_options.close()
		if graphics_options.visible:
			graphics_options.close()
	help_panel.visible = not help_panel.visible
	if get_tree().paused:
		buttons.visible = not help_panel.visible
		if not help_panel.visible:
			resume_button.grab_focus()


func set_paused(value: bool) -> void:
	if help_panel != null:
		help_panel.hide()
	super.set_paused(value)
