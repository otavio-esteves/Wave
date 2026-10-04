extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("WaveSettings")
	if "--verify-persistence" in OS.get_cmdline_user_args():
		_check(is_equal_approx(settings.volumes["Motor"], 0.37), "engine volume survives restarting the game")
		_check(is_equal_approx(settings.volumes["Música"], 0.0), "music mute survives restarting the game")
		_finish()
		return
	var world := load("res://scenes/city/drive_neighborhood.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	await _frames(10)
	var audio := world.get_node("DrivingAudio")
	var car := world.get_node("PlayerCar") as PlayerCar
	var hud := world.get_node("HUD")
	for label: String in ["Engine", "Ambience", "Music"]:
		var player := audio.get_node(label) as AudioStreamPlayer
		var stream := player.stream as AudioStreamWAV
		_check(player.playing and stream.data.size() > 1000, "%s starts with real audio data" % label)
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0, "%s loops with a valid sample range" % label)
	var idle_pitch: float = audio.engine.pitch_scale
	Input.action_press("accelerate")
	await _frames(60)
	_check(audio.engine.pitch_scale > idle_pitch + 0.2, "engine pitch responds to driving")
	Input.action_release("accelerate")
	car.reset_car()
	_check(is_equal_approx(audio.engine.pitch_scale, 0.8), "reset restores idle engine pitch")
	hud.set_paused(true)
	await _frames(2)
	_check(audio.engine.stream_paused and audio.ambience.stream_paused and audio.music.stream_paused, "pause suspends every audio layer")
	var buttons := hud.get_node("Overlay/PauseMenu/Center/Buttons")
	buttons.get_node("Audio").pressed.emit()
	var options := hud.get_node("Overlay/PauseMenu/Center/AudioOptions")
	_check(options.visible and not buttons.visible, "pause opens the audio options")
	_check(root.gui_get_focus_owner() == options.first_slider, "audio options focus the first slider for keyboard/controller")
	var sliders := options.find_children("*", "HSlider", true, false)
	for slider: HSlider in sliders:
		if slider.name == "Motor":
			slider.value = 37
		elif slider.name == "Música":
			slider.value = 0
	_check(is_equal_approx(settings.volumes["Motor"], 0.37), "engine slider changes its separate bus")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Música")), "zero music volume mutes the music bus")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Motor")), "music mute leaves the engine enabled")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)
	_check(paused and not options.visible and buttons.visible, "Escape returns from audio options to the pause menu")
	hud.set_paused(false)
	await _frames(2)
	_check(not audio.engine.stream_paused and not audio.music.stream_paused, "resuming restores audio playback")
	settings.save_settings()
	settings.volumes["Motor"] = 1.0
	settings.reload_settings()
	_check(is_equal_approx(settings.volumes["Motor"], 0.37), "saved volume reloads from the configuration file")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Música")), "saved mute is reapplied to the bus")
	world.queue_free()
	await process_frame
	# The audio thread uses wall time even when physics uses --fixed-fps.
	OS.delay_msec(100)
	await process_frame
	await process_frame
	_finish()


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	print("Audio smoke test: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
