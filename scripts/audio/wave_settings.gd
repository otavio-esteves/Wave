extends Node

const SETTINGS_PATH := "user://wave-settings.cfg"
const DEFAULTS := {"Master": 0.8, "Motor": 0.7, "Ambiente": 0.65, "Música": 0.45}
const GRAPHICS_DEFAULTS := {"fullscreen": false, "vsync": true, "shadows": false, "antialiasing": false, "post_effects": false, "cinematic_effects": false, "resolution": "1280x720"}
const RESOLUTIONS := {"960x540": Vector2i(960, 540), "1280x720": Vector2i(1280, 720), "1600x900": Vector2i(1600, 900), "854x480": Vector2i(854, 480), "1920x1080": Vector2i(1920, 1080)}
const GRAPHICS_PRESETS := {
	"legacy": {"resolution": "1280x720", "shadows": false, "antialiasing": false, "post_effects": false, "cinematic_effects": false},
	"medium": {"resolution": "1280x720", "shadows": true, "antialiasing": true, "post_effects": false, "cinematic_effects": false},
	"high": {"resolution": "1920x1080", "shadows": true, "antialiasing": true, "post_effects": true, "cinematic_effects": false},
	"economy": {"resolution": "854x480", "shadows": false, "antialiasing": false, "post_effects": false, "cinematic_effects": false},
}
var volumes: Dictionary = DEFAULTS.duplicate()
var graphics: Dictionary = GRAPHICS_DEFAULTS.duplicate()
var _save_timer: Timer
var _window_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in DEFAULTS:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	add_child(_save_timer)
	_save_timer.timeout.connect(save_settings)
	_window_timer = Timer.new()
	_window_timer.one_shot = true
	_window_timer.wait_time = 0.2
	add_child(_window_timer)
	_window_timer.timeout.connect(_restore_window_size)
	reload_settings()
	if "--quality" in OS.get_cmdline_user_args():
		set_quality_mode()


func reload_settings() -> void:
	var config := ConfigFile.new()
	var result := config.load(SETTINGS_PATH)
	if result != OK and result != ERR_FILE_NOT_FOUND:
		push_warning("Wave could not read volume settings: %s" % error_string(result))
	for bus: String in DEFAULTS:
		var stored: Variant = config.get_value("audio", bus, DEFAULTS[bus])
		var value: float = DEFAULTS[bus]
		if (stored is float or stored is int) and is_finite(float(stored)):
			value = clampf(float(stored), 0.0, 1.0)
		volumes[bus] = value
		_apply_volume(bus, value)
	var graphics_defaults := GRAPHICS_DEFAULTS.duplicate()
	for key: String in graphics_defaults:
		var stored: Variant = config.get_value("graphics", key, graphics_defaults[key])
		if key == "resolution":
			graphics[key] = stored if stored is String and RESOLUTIONS.has(stored) else graphics_defaults[key]
		else:
			graphics[key] = stored if stored is bool else graphics_defaults[key]
	apply_graphics()


func set_graphics(key: String, value: Variant) -> void:
	if not GRAPHICS_DEFAULTS.has(key):
		return
	if key == "resolution":
		if not value is String or not RESOLUTIONS.has(value):
			return
	elif not value is bool:
		return
	if graphics[key] == value:
		return
	# Finish the current sample before changing its recorded graphics settings.
	get_tree().call_group("performance_capture", "finish")
	graphics[key] = value
	apply_graphics()
	_save_timer.start()


func set_economy_mode() -> void:
	set_graphics_preset("economy")


func set_graphics_preset(preset: String) -> void:
	if not GRAPHICS_PRESETS.has(preset):
		return
	# Save one capture with the old settings, then apply the entire preset once.
	get_tree().call_group("performance_capture", "finish")
	graphics["fullscreen"] = false
	for key: String in GRAPHICS_PRESETS[preset]:
		graphics[key] = GRAPHICS_PRESETS[preset][key]
	apply_graphics()
	_save_timer.start()


func get_graphics_preset() -> String:
	for preset: String in GRAPHICS_PRESETS:
		var matches := true
		for key: String in GRAPHICS_PRESETS[preset]:
			matches = matches and graphics[key] == GRAPHICS_PRESETS[preset][key]
		if matches:
			return preset
	return "custom"


func apply_graphics() -> void:
	if DisplayServer.get_name() != "headless":
		var window := get_tree().root
		window.msaa_3d = Viewport.MSAA_2X if graphics["antialiasing"] else Viewport.MSAA_DISABLED
		var mode := Window.MODE_FULLSCREEN if graphics["fullscreen"] else Window.MODE_WINDOWED
		if window.mode != mode:
			window.mode = mode
			if mode == Window.MODE_WINDOWED:
				# Desktop window managers can restore an old size asynchronously.
				_window_timer.start()
		if not graphics["fullscreen"]:
			window.size = RESOLUTIONS[graphics["resolution"]]
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if graphics["vsync"] else DisplayServer.VSYNC_DISABLED)
	get_tree().call_group("driving_world", "apply_graphics")


func _restore_window_size() -> void:
	if not graphics["fullscreen"] and DisplayServer.get_name() != "headless":
		get_tree().root.size = RESOLUTIONS[graphics["resolution"]]


func apply_world_graphics(world: Node) -> void:
	for light: DirectionalLight3D in world.find_children("*", "DirectionalLight3D", true, false):
		light.shadow_enabled = graphics["shadows"]


func set_volume(bus: String, value: float) -> void:
	if not volumes.has(bus) or not is_finite(value):
		return
	value = clampf(value, 0.0, 1.0)
	volumes[bus] = value
	_apply_volume(bus, value)
	_save_timer.start()


func _apply_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, is_zero_approx(value))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


func save_settings() -> void:
	var config := ConfigFile.new()
	for bus: String in volumes:
		config.set_value("audio", bus, volumes[bus])
	for key: String in graphics:
		config.set_value("graphics", key, graphics[key])
	var result := config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("Wave could not save volume settings: %s" % error_string(result))


func _exit_tree() -> void:
	save_settings()


func quit_game() -> void:
	save_settings()
	get_tree().call_group("wave_audio", "stop_audio")
	# Allow the audio thread to finish the stop fade before the engine shuts down.
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()


func set_quality_mode() -> void:
	set_graphics_preset("high")


func set_balanced_mode() -> void:
	set_graphics_preset("medium")
