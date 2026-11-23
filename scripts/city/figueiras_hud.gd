extends "res://scripts/prototype_hud.gd"

var _expanded_help := false


func _ready() -> void:
	super._ready()
	buttons.get_node("Race").hide()
	buttons.get_node("Rally").hide()
	buttons.get_node("MainMenu").text = "Laboratórios"
	buttons.move_child(buttons.get_node("Exit"), buttons.get_child_count() - 1)
	$Overlay/Telemetry.hide()
	var instruments := preload("res://scripts/city/figueiras_instruments.gd").new()
	instruments.name = "Instruments"
	instruments.car = car
	instruments.clock = world.get_node("DayNightCycle")
	$Overlay.add_child(instruments)
	instruments.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	instruments.position += Vector2(-238, -117)
	instruments.size = Vector2(218, 97)
	var minimap := preload("res://scripts/city/figueiras_minimap.gd").new()
	minimap.name = "Minimap"
	minimap.car = car
	minimap.sprint = world.get_node("AlamedaSprint")
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Overlay.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.position += Vector2(20, -166)
	minimap.size = Vector2(176, 146)
	city_map = preload("res://scripts/city/figueiras_activity_map.gd").new()
	city_map.name = "ActivityMap"
	city_map.car = car
	city_map.sprint = minimap.sprint
	$Overlay.add_child(city_map)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("driving_help") and not event.is_echo() and not get_tree().paused:
		_expanded_help = not _expanded_help
		_update_control_help()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused and not city_map.visible and event.is_action_pressed("city_map"):
		return
	super._unhandled_input(event)


func _update_control_help(_device: int = -1, _connected: bool = false) -> void:
	var pad := not Input.get_connected_joypads().is_empty()
	var hints := ("Share  Mapa   ·   →  Chuva   ·   Quadrado  Câmera   ·   ←  Controles" if pad
		else "M  Mapa   ·   G  Chuva   ·   V  Câmera   ·   H  Controles")
	if _expanded_help:
		hints += ("\nAnalógico E  Direção   ·   R2 / L2  Pedais   ·   X  Freio de mão\nAnalógico D  Olhar   ·   Triângulo  Olhar atrás   ·   Options  Pausa\nCírculo  Reset   ·   L1  Faróis   ·   R1  Hora   ·   ↑  Prova" if pad
			else "\nWASD / setas  Dirigir   ·   Espaço  Freio de mão   ·   Esc  Pausa\nMouse  Olhar   ·   C  Olhar atrás   ·   R  Reset\nL  Faróis   ·   F6  Hora   ·   T  Prova")
	$Overlay/Controls.text = hints
