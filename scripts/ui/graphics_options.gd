extends PanelContainer

signal closed
var first_control: CheckButton
var resolution: OptionButton
var _toggles: Dictionary = {}
var _scroll: ScrollContainer


func _ready() -> void:
	custom_minimum_size = Vector2(420, 0)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	get_tree().root.size_changed.connect(_update_panel_height)
	_update_panel_height()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	_scroll.add_child(box)
	var title := Label.new()
	title.text = "Gráficos"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	for key: String in ["fullscreen", "vsync", "shadows", "antialiasing", "post_effects", "cinematic_effects"]:
		var toggle := CheckButton.new()
		toggle.name = key
		toggle.text = {"fullscreen": "Tela cheia", "vsync": "Sincronização vertical", "shadows": "Sombras", "antialiasing": "Suavizar contornos (MSAA 2×)", "post_effects": "Oclusão ambiente e brilho no rally", "cinematic_effects": "Luz indireta e névoa no rally"}[key]
		if key == "cinematic_effects":
			toggle.disabled = RenderingServer.get_current_rendering_method() != "forward_plus"
			toggle.tooltip_text = "Cosméticos opcionais disponíveis ao iniciar com Forward+."
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
	quality.text = "HIGH · 1080p"
	quality.custom_minimum_size.y = 44
	quality.pressed.connect(func() -> void:
		WaveSettings.set_quality_mode()
		_sync_controls()
	)
	box.add_child(quality)
	var balanced := Button.new()
	balanced.name = "Balanced"
	balanced.text = "MEDIUM · 720p"
	balanced.custom_minimum_size.y = 44
	balanced.pressed.connect(func() -> void:
		WaveSettings.set_balanced_mode()
		_sync_controls()
	)
	box.add_child(balanced)
	var legacy := Button.new()
	legacy.name = "Legacy"
	legacy.text = "LOW / Legacy · 720p"
	legacy.custom_minimum_size.y = 44
	legacy.pressed.connect(func() -> void:
		WaveSettings.set_graphics_preset("legacy")
		_sync_controls()
	)
	box.add_child(legacy)
	var economy := Button.new()
	economy.name = "Economy"
	economy.text = "Fallback econômico · 480p"
	economy.custom_minimum_size.y = 44
	economy.pressed.connect(func() -> void:
		WaveSettings.set_economy_mode()
		_sync_controls()
	)
	box.add_child(economy)
	var hint := Label.new()
	hint.text = "Tela cheia usa a resolução do monitor.\nLegacy: 720p sem sombras ou contornos suaves."
	box.add_child(hint)
	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size.y = 44
	back.pressed.connect(close)
	box.add_child(back)


func _update_resolution() -> void:
	if resolution != null:
		resolution.disabled = WaveSettings.graphics["fullscreen"]


func _update_panel_height() -> void:
	_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 60.0, 300.0, 600.0)


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
