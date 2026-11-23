extends PanelContainer

signal closed
const Radio = preload("res://scripts/audio/wave_radio.gd")
var first_slider: HSlider
var _radio: Node
var _track_choice: OptionButton


func _ready() -> void:
	custom_minimum_size = Vector2(420, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "Áudio"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	for bus: String in WaveSettings.DEFAULTS:
		var row := VBoxContainer.new()
		box.add_child(row)
		var caption := Label.new()
		var label := "Volume geral" if bus == "Master" else bus
		caption.text = "%s · %d%%" % [label, roundi(WaveSettings.volumes[bus] * 100)]
		row.add_child(caption)
		var slider := HSlider.new()
		slider.name = bus
		slider.custom_minimum_size = Vector2(360, 32)
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = WaveSettings.volumes[bus] * 100.0
		slider.tooltip_text = label
		row.add_child(slider)
		slider.value_changed.connect(func(value: float) -> void:
			WaveSettings.set_volume(bus, value / 100.0)
			caption.text = "%s · %d%%" % [label, roundi(value)]
		)
		if first_slider == null:
			first_slider = slider
	_track_choice = OptionButton.new()
	_track_choice.name = "RadioTrack"
	_track_choice.tooltip_text = "Escolher a faixa da rádio"
	_track_choice.custom_minimum_size.y = 40
	for track_title in Radio.TITLES:
		_track_choice.add_item(track_title)
	_track_choice.item_selected.connect(_select_track)
	_track_choice.hide()
	box.add_child(_track_choice)
	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size.y = 44
	back.pressed.connect(close)
	box.add_child(back)


func open() -> void:
	var radio := get_tree().get_first_node_in_group("wave_radio")
	if radio != _radio:
		if is_instance_valid(_radio):
			_radio.track_changed.disconnect(_track_choice.select)
		_radio = radio
		if _radio != null:
			_radio.track_changed.connect(_track_choice.select)
	_track_choice.visible = _radio != null
	if _radio != null:
		_track_choice.select(_radio.track_index)
	show()
	first_slider.grab_focus()


func _select_track(index: int) -> void:
	if is_instance_valid(_radio):
		_radio.play_track(index)


func close() -> void:
	WaveSettings.save_settings()
	hide()
	closed.emit()
