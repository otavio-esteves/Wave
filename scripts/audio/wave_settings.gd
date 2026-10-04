extends Node

const SETTINGS_PATH := "user://wave-settings.cfg"
const DEFAULTS := {"Master": 0.8, "Motor": 0.7, "Ambiente": 0.65, "Música": 0.45}
var volumes: Dictionary = DEFAULTS.duplicate()
var _save_timer: Timer


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
	reload_settings()


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
