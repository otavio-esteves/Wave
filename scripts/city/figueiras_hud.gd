extends "res://scripts/prototype_hud.gd"


func _ready() -> void:
	super._ready()
	buttons.get_node("Race").hide()
	buttons.get_node("Rally").hide()
	buttons.get_node("MainMenu").text = "Laboratórios"
	buttons.move_child(buttons.get_node("Exit"), buttons.get_child_count() - 1)
	$Overlay/Telemetry.offset_left = -250
	$Overlay/Telemetry.offset_top = -98
	var minimap := preload("res://scripts/city/figueiras_minimap.gd").new()
	minimap.name = "Minimap"
	minimap.car = car
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Overlay.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.position += Vector2(20, -166)
	minimap.size = Vector2(176, 146)


func _update_control_help(_device: int = -1, _connected: bool = false) -> void:
	var hints := "WASD / setas: dirigir   ·   Esc: pausa" if Input.get_connected_joypads().is_empty() else "R2 / L2: acelerar e frear   ·   Options: pausa"
	$Overlay/Controls.text = "%s\n%s" % [world.world_title, hints]
