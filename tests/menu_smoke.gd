extends SceneTree

const MENU := "res://scenes/ui/main_menu.tscn"
const CITY := "res://scenes/city/drive_neighborhood.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("WaveSettings")
	if "--verify-persistence" in OS.get_cmdline_user_args():
		_check(settings.graphics == {"fullscreen": true, "vsync": false, "shadows": false, "antialiasing": false, "post_effects": false, "cinematic_effects": false, "resolution": "960x540", "fps_limit": 60}, "graphics preferences survive restarting the process")
		_finish()
		return
	_check(ProjectSettings.get_setting("application/run/main_scene") == MENU, "project starts at the main menu")
	change_scene_to_file(MENU)
	await _frames(3)
	var menu := current_scene
	_check(root.gui_get_focus_owner() == menu.streaming_button, "main menu focuses the city walk for keyboard and controller")
	_check(menu.streaming_button.get_index() < menu.drive_button.get_index() and menu.streaming_button.get_global_rect().intersects(Rect2(Vector2.ZERO, root.get_visible_rect().size)), "city walk is the first driving option and visible without scrolling")
	menu.audio_button.pressed.emit()
	_check(menu.audio_options.visible and not menu.buttons.visible, "main menu opens audio settings")
	await _escape()
	_check(not menu.audio_options.visible and root.gui_get_focus_owner() == menu.audio_button, "Escape closes audio and restores focus")
	menu.graphics_button.pressed.emit()
	var options: PanelContainer = menu.graphics_options
	_check(options.visible and root.gui_get_focus_owner() == options.first_control, "graphics settings open with focus")
	options.first_control.button_pressed = true
	_check(settings.graphics["fullscreen"] and options.resolution.disabled, "fullscreen preference disables window resolution selection")
	options.first_control.button_pressed = false
	options.resolution.select(0)
	options.resolution.item_selected.emit(0)
	_check(settings.graphics["resolution"] == "960x540" and not options.resolution.disabled, "window resolution selection changes preferences")
	settings.set_graphics("resolution", "invalid")
	settings.set_graphics("shadows", "invalid")
	_check(settings.graphics["resolution"] == "960x540" and settings.graphics["shadows"] is bool, "invalid graphic values are rejected")
	options.fps_limit.select(2)
	options.fps_limit.item_selected.emit(2)
	_check(settings.graphics.fps_limit == 60, "FPS limit selection updates the graphics preference")
	settings.set_graphics("fps_limit", 99)
	settings.set_graphics("fps_limit", true)
	_check(settings.graphics.fps_limit == 60, "invalid FPS limits cannot replace a valid selection")
	await _escape()
	_check(menu.buttons.visible and root.gui_get_focus_owner() == menu.graphics_button, "Escape returns from graphics to main menu")
	menu.drive_button.pressed.emit()
	await _frames(5)
	_check(current_scene.scene_file_path == CITY and not paused, "Drive starts the neighborhood")
	var world := current_scene
	var light: DirectionalLight3D = world.get_node("Sun")
	var hud := world.get_node("HUD")
	hud.set_paused(true)
	hud.get_node("Overlay/PauseMenu/Center/Buttons/Graphics").pressed.emit()
	var pause_options := hud.get_node("Overlay/PauseMenu/Center/GraphicsOptions")
	var aa_toggle := pause_options.find_child("antialiasing", true, false) as CheckButton
	aa_toggle.button_pressed = false
	_check(not settings.graphics["antialiasing"], "antialiasing option updates saved graphics preferences")
	var shadow_toggle := pause_options.find_child("shadows", true, false) as CheckButton
	shadow_toggle.button_pressed = false
	_check(not light.shadow_enabled and not settings.graphics["shadows"], "shadow option updates the current world while paused")
	await _escape()
	_check(paused and not pause_options.visible and hud.buttons.visible, "Escape from graphics keeps the world paused")
	settings.set_graphics("vsync", false)
	settings.save_settings()
	settings.graphics["shadows"] = true
	settings.reload_settings()
	_check(not settings.graphics["shadows"] and not settings.graphics["vsync"] and not light.shadow_enabled, "graphics reload reapplies saved values to the world")
	hud.get_node("Overlay/PauseMenu/Center/Buttons/World").pressed.emit()
	await _frames(5)
	_check(not current_scene.get_node("Sun").shadow_enabled, "graphics settings carry over to the test track")
	current_scene.get_node("HUD").set_paused(true)
	current_scene.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(5)
	_check(current_scene.scene_file_path == MENU and not paused and get_nodes_in_group("wave_audio").is_empty(), "return to main menu clears pause and driving audio")
	current_scene.drive_button.pressed.emit()
	await _frames(5)
	_check(not current_scene.get_node("Sun").shadow_enabled, "new driving session retains graphic preferences")
	var capture := current_scene.get_node("PerformanceCapture")
	capture.toggle()
	_check(not capture.recording, "headless mode refuses to report rendered performance")
	hud = current_scene.get_node("HUD")
	hud.set_paused(true)
	hud.get_node("Overlay/PauseMenu/Center/Buttons/Graphics").pressed.emit()
	options = hud.graphics_options
	options.find_child("Balanced", true, false).pressed.emit()
	_check(settings.graphics["resolution"] == "1280x720" and settings.graphics["shadows"] and settings.graphics["antialiasing"] and not settings.graphics["cinematic_effects"], "balanced mode keeps shadows and MSAA with lightweight rally effects")
	_check(not options.find_child("cinematic_effects", true, false).button_pressed, "balanced mode synchronizes its effects control")
	options.find_child("Quality", true, false).pressed.emit()
	_check(settings.graphics["resolution"] == "1920x1080" and not settings.graphics["cinematic_effects"], "high profile uses 1080p without requiring Forward+ effects")
	options.find_child("Legacy", true, false).pressed.emit()
	_check(settings.get_graphics_preset() == "legacy" and settings.graphics["resolution"] == "1280x720" and not current_scene.get_node("Sun").shadow_enabled and not settings.graphics["antialiasing"] and not settings.graphics["post_effects"], "legacy profile targets native 720p and updates the paused world")
	_check(options.resolution.get_item_text(options.resolution.selected) == "1280x720", "legacy profile synchronizes visible resolution")
	_check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "presets retain the Compatibility renderer")
	options.find_child("Economy", true, false).pressed.emit()
	_check(settings.graphics["resolution"] == "854x480" and not settings.graphics["fullscreen"] and not settings.graphics["shadows"] and not settings.graphics["antialiasing"], "economy mode applies the lightweight windowed profile")
	_check(options.resolution.get_item_text(options.resolution.selected) == "854x480" and not options.first_control.button_pressed, "economy mode synchronizes the visible controls")
	hud.set_paused(false)
	current_scene.queue_free()
	await process_frame
	OS.delay_msec(100)
	await process_frame
	settings.set_graphics("fullscreen", true)
	settings.set_graphics("resolution", "960x540")
	settings.set_graphics("fps_limit", 60)
	settings.save_settings()
	_finish()


func _escape() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	print("Menu smoke test: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
