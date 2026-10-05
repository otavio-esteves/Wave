extends PanelContainer

signal closed
var first_control: CheckButton
var resolution: OptionButton
var _toggles: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(420, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Gráficos"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	for key: String in ["fullscreen", "vsync", "shadows", "antialiasing", "cinematic_effects"]:
		var toggle := CheckButton.new()
		toggle.name = key
		toggle.text = {"fullscreen": "Tela cheia", "vsync": "Sincronização vertical", "shadows": "Sombras", "antialiasing": "Suavizar contornos (MSAA 2×)", "cinematic_effects": "Efeitos cinematográficos no rally"}[key]
		toggle.button_pressed = WaveSettings.graphics[key]
		_toggles[key] = toggle
		box.add_child(toggle)
		toggle.toggled.connect(func(enabled: bool) -> void:
			WaveSettings.set_graphics(key, enabled)
			_update_resolution()
		)
		if first_control == null:
			first_control = toggle
	var caption := Label.new()
	caption.text = "Resolução da janela"
	box.add_child(caption)
	resolution = OptionButton.new()
	resolution.name = "resolution"
	for size: String in WaveSettings.RESOLUTIONS:
		resolution.add_item(size)
		if size == WaveSettings.graphics["resolution"]:
			resolution.select(resolution.item_count - 1)
	resolution.item_selected.connect(func(index: int) -> void:
		WaveSettings.set_graphics("resolution", resolution.get_item_text(index))
	)
	box.add_child(resolution)
	_update_resolution()
	var quality := Button.new()
	quality.name = "Quality"
	quality.text = "Priorizar qualidade visual"
	quality.custom_minimum_size.y = 44
	quality.pressed.connect(func() -> void:
		WaveSettings.set_quality_mode()
		_sync_controls()
	)
	box.add_child(quality)
	var balanced := Button.new()
	balanced.name = "Balanced"
	balanced.text = "Equilibrar qualidade e desempenho"
	balanced.custom_minimum_size.y = 44
	balanced.pressed.connect(func() -> void:
		WaveSettings.set_balanced_mode()
		_sync_controls()
	)
	box.add_child(balanced)
	var economy := Button.new()
	economy.name = "Economy"
	economy.text = "Aplicar modo econômico"
	economy.custom_minimum_size.y = 44
	economy.pressed.connect(func() -> void:
		WaveSettings.set_economy_mode()
		_sync_controls()
	)
	box.add_child(economy)
	var hint := Label.new()
	hint.text = "Tela cheia usa a resolução do monitor.\nEquilibrado: 720p, sombras e contornos suaves.\nEfeitos cinematográficos exigem mais da GPU."
	box.add_child(hint)
	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size.y = 44
	back.pressed.connect(close)
	box.add_child(back)


func _update_resolution() -> void:
	if resolution != null:
		resolution.disabled = WaveSettings.graphics["fullscreen"]


func open() -> void:
	_sync_controls()
	show()
	first_control.grab_focus()


func _sync_controls() -> void:
	for key: String in _toggles:
		_toggles[key].set_pressed_no_signal(WaveSettings.graphics[key])
	for index in resolution.item_count:
		if resolution.get_item_text(index) == WaveSettings.graphics["resolution"]:
			resolution.select(index)
	_update_resolution()


func close() -> void:
	WaveSettings.save_settings()
	hide()
	closed.emit()
