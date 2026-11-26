extends "res://scripts/prototype_hud.gd"

const Instruments = preload("res://scripts/city/figueiras_instruments.gd")
var _show_help := false


func _ready() -> void:
	super._ready()
	buttons.get_node("Race").hide()
	buttons.get_node("Rally").hide()
	buttons.get_node("MainMenu").text = "Laboratórios"
	buttons.move_child(buttons.get_node("Exit"), buttons.get_child_count() - 1)
	$Overlay/Telemetry.hide()
	var instruments := Instruments.new()
	instruments.car = car
	$Overlay.add_child(instruments)
	instruments.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	instruments.position += Vector2(-238, -117)
	instruments.size = Vector2(218, 97)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("driving_help") and not event.is_echo() and not get_tree().paused:
		_show_help = not _show_help
		_update_control_help()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _update_control_help(device: int = -1, connected: bool = false) -> void:
	if _show_help:
		super._update_control_help(device, connected)
		return
	var pad := not Input.get_connected_joypads().is_empty()
	var keys := "Quadrado  Câmera   ·   ←  Controles" if pad else "V  Câmera   ·   H  Controles"
	$Overlay/Controls.text = "%s\n%s" % [world.world_title, keys]
