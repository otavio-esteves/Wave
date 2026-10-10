extends SceneTree
const FixtureInput = preload("fixture_input.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	InputSetup.configure()
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_START
	event.pressed = true
	_check(event.is_action_pressed("pause"), "normal bindings accept the physical controller")
	FixtureInput.isolate()
	_check(not event.is_action_pressed("pause"), "isolated fixtures reject physical pause events")
	event.button_index = JOY_BUTTON_BACK
	_check(not event.is_action_pressed("city_map"), "isolated fixtures reject physical map events")
	event.button_index = JOY_BUTTON_DPAD_UP
	FixtureInput.inject(event)
	await process_frame
	await process_frame
	_check(Input.is_action_pressed("city_activity"), "fixture injection preserves actual gamepad action bindings")
	event.pressed = false
	FixtureInput.inject(event)
	await process_frame
	await process_frame
	_check(not Input.is_action_pressed("city_activity"), "fixture release clears the injected action")
	print("Fixture input: 5 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)
func _check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
