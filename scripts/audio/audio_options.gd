extends PanelContainer

signal closed
var first_slider: HSlider


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
	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size.y = 44
	back.pressed.connect(close)
	box.add_child(back)


func open() -> void:
	show()
	first_slider.grab_focus()


func close() -> void:
	WaveSettings.save_settings()
	hide()
	closed.emit()
