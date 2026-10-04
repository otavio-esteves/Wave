extends Control

const AUDIO_OPTIONS = preload("res://scripts/audio/audio_options.gd")
const GRAPHICS_OPTIONS = preload("res://scripts/ui/graphics_options.gd")
var buttons: VBoxContainer
var audio_options: PanelContainer
var graphics_options: PanelContainer
var drive_button: Button
var race_button: Button
var technical_button: Button
var audio_button: Button
var graphics_button: Button


func _ready() -> void:
	InputSetup.configure()
	get_tree().paused = false
	var background := ColorRect.new()
	background.color = Color("493f43")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	buttons = VBoxContainer.new()
	buttons.custom_minimum_size.x = 320
	buttons.add_theme_constant_override("separation", 14)
	center.add_child(buttons)
	var title := Label.new()
	title.text = "WAVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	buttons.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Um passeio ao fim da tarde"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(subtitle)
	drive_button = _button("Dirigir no bairro", _drive)
	race_button = _button("Autódromo", func() -> void: _load_world("res://scenes/race/drive_race.tscn"))
	technical_button = _button("Pista técnica", func() -> void: _load_world("res://scenes/test_track.tscn"))
	audio_button = _button("Áudio", func() -> void:
		buttons.hide()
		audio_options.open()
	)
	graphics_button = _button("Gráficos", func() -> void:
		buttons.hide()
		graphics_options.open()
	)
	_button("Sair", WaveSettings.quit_game)
	audio_options = PanelContainer.new()
	audio_options.set_script(AUDIO_OPTIONS)
	audio_options.hide()
	center.add_child(audio_options)
	audio_options.closed.connect(func() -> void:
		buttons.show()
		audio_button.grab_focus()
	)
	graphics_options = PanelContainer.new()
	graphics_options.set_script(GRAPHICS_OPTIONS)
	graphics_options.hide()
	center.add_child(graphics_options)
	graphics_options.closed.connect(func() -> void:
		buttons.show()
		graphics_button.grab_focus()
	)
	drive_button.grab_focus()


func _button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 48
	button.pressed.connect(callback)
	buttons.add_child(button)
	return button


func _drive() -> void:
	_load_world("res://scenes/city/drive_neighborhood.tscn")


func _load_world(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Could not start driving: %s" % error_string(error))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if audio_options.visible:
			audio_options.close()
		elif graphics_options.visible:
			graphics_options.close()
		get_viewport().set_input_as_handled()
