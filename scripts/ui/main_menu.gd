extends Control

const AUDIO_OPTIONS = preload("res://scripts/audio/audio_options.gd")
const GRAPHICS_OPTIONS = preload("res://scripts/ui/graphics_options.gd")
# Warm the three small shared WAV streams on the main thread. Loading their
# script for the first time in a worker leaked decoder references in this engine.
const SHARED_AUDIO = preload("res://scripts/audio/driving_audio.gd")
# The first shader preload from a worker-held script also left an internal
# reference in the exported loader. Warm this small shared shader on the main thread.
const SHARED_CONTACT_SHADER = preload("res://assets/shaders/corridor/contact_shadow.gdshader")
var streaming_button: Button
var pilot_button: Button
var intercity_button: Button
var elevation_button: Button
var corridor_button: Button
var buttons_scroll: ScrollContainer
var buttons: VBoxContainer
var audio_options: PanelContainer
var graphics_options: PanelContainer
var drive_button: Button
var race_button: Button
var rally_button: Button
var technical_button: Button
var audio_button: Button
var graphics_button: Button
var loading_path := ""
var loading_panel: VBoxContainer
var loading_label: Label
var loading_progress: ProgressBar
var load_error: Label
var _prepared_scene: PackedScene
var _prepared_frame := 0


func _ready() -> void:
	InputSetup.configure()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	buttons_scroll = ScrollContainer.new()
	buttons_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	buttons_scroll.follow_focus = true
	center.add_child(buttons_scroll)
	loading_panel = VBoxContainer.new()
	loading_panel.custom_minimum_size.x = 320
	center.add_child(loading_panel)
	loading_label = Label.new()
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_panel.add_child(loading_label)
	loading_progress = ProgressBar.new()
	loading_progress.custom_minimum_size.y = 12
	loading_panel.add_child(loading_progress)
	loading_panel.hide()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons_scroll.add_child(buttons)
	get_tree().root.size_changed.connect(_resize_menu)
	_resize_menu()
	var title := Label.new()
	title.text = "WAVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	buttons.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Direção arcade · Brasil"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(subtitle)
	load_error = Label.new()
	load_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load_error.custom_minimum_size.x = 320
	load_error.hide()
	buttons.add_child(load_error)
	pilot_button = _button("Dirigir na cidade piloto", func() -> void: _load_world("res://scenes/city/drive_pilot_city.tscn"))
	var city_description := Label.new()
	city_description.text = "3 bairros · 200 quarteirões · dia e noite"
	city_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(city_description)
	var laboratories := Label.new()
	laboratories.text = "LABORATÓRIOS ANTERIORES"
	laboratories.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(laboratories)
	streaming_button = _button("Avenida do Vale · streaming", func() -> void: _load_world("res://scenes/world/drive_streamed_corridor.tscn"))
	intercity_button = _button("Viajar pelo Caminho da Serra", func() -> void: _load_world("res://scenes/world/drive_intercity.tscn"))
	drive_button = _button("Dirigir no Bairro do Sol", _drive)
	corridor_button = _button("Avenida do Vale · referência visual", func() -> void: _load_world("res://scenes/corridor/drive_corridor.tscn"))
	race_button = _button("Circuito de corrida", func() -> void: _load_world("res://scenes/race/drive_race.tscn"))
	rally_button = _button("Rally da Serra", func() -> void: _load_world("res://scenes/rally/drive_rally.tscn"))
	technical_button = _button("Pista técnica", func() -> void: _load_world("res://scenes/test_track.tscn"))
	elevation_button = _button("Experimentar relevo da serra", func() -> void: _load_world("res://scenes/world/drive_elevation.tscn"))
	audio_button = _button("Áudio", func() -> void:
		buttons.hide()
		buttons_scroll.hide()
		audio_options.open()
	)
	graphics_button = _button("Gráficos", func() -> void:
		buttons.hide()
		buttons_scroll.hide()
		graphics_options.open()
	)
	_button("Sair", WaveSettings.quit_game)
	audio_options = PanelContainer.new()
	audio_options.set_script(AUDIO_OPTIONS)
	audio_options.hide()
	center.add_child(audio_options)
	audio_options.closed.connect(func() -> void:
		buttons.show()
		buttons_scroll.show()
		audio_button.grab_focus()
	)
	graphics_options = PanelContainer.new()
	graphics_options.set_script(GRAPHICS_OPTIONS)
	graphics_options.hide()
	center.add_child(graphics_options)
	graphics_options.closed.connect(func() -> void:
		buttons.show()
		buttons_scroll.show()
		graphics_button.grab_focus()
	)
	pilot_button.grab_focus()


func _resize_menu() -> void:
	buttons_scroll.custom_minimum_size = Vector2(350, clampf(get_viewport_rect().size.y - 32, 300, 660))


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
	if not loading_path.is_empty():
		return
	if not ResourceLoader.exists(path):
		_load_failed("O mapa não está disponível.")
		return
	loading_path = path
	load_error.hide()
	buttons_scroll.hide()
	loading_panel.show()
	loading_label.text = "Carregando o mundo…"
	loading_progress.value = 0
	loading_progress.show()
	var error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if error != OK:
		_load_failed("Não foi possível carregar o mapa. Tente novamente.")


func _process(_delta: float) -> void:
	if loading_path.is_empty():
		return
	if _prepared_scene != null:
		# Give the preparation message a complete frame before main-thread instantiation.
		if Engine.get_process_frames() <= _prepared_frame + 1:
			return
		var error := get_tree().change_scene_to_packed(_prepared_scene)
		if error != OK:
			_load_failed("Não foi possível abrir o mapa. Tente novamente.")
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(loading_path, progress)
	if not progress.is_empty():
		loading_progress.value = float(progress[0]) * 100.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_prepared_scene = ResourceLoader.load_threaded_get(loading_path) as PackedScene
		if _prepared_scene == null:
			_load_failed("O arquivo do mapa é inválido.")
			return
		_prepared_frame = Engine.get_process_frames()
		loading_label.text = "Preparando a cidade…"
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		ResourceLoader.load_threaded_get(loading_path)
		_load_failed("Não foi possível carregar o mapa. Tente novamente.")


func _load_failed(message: String) -> void:
	loading_path = ""
	_prepared_scene = null
	loading_panel.hide()
	load_error.text = message
	load_error.show()
	buttons_scroll.show()
	pilot_button.grab_focus()


func _exit_tree() -> void:
	if not loading_path.is_empty() and _prepared_scene == null:
		var drain := WorldStreamer.LoadDrain.new()
		drain.paths = [loading_path]
		drain.process_mode = Node.PROCESS_MODE_ALWAYS
		if not get_tree().root.is_queued_for_deletion():
			get_tree().root.add_child.call_deferred(drain)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
		if audio_options.visible:
			audio_options.close()
		elif graphics_options.visible:
			graphics_options.close()
		get_viewport().set_input_as_handled()
