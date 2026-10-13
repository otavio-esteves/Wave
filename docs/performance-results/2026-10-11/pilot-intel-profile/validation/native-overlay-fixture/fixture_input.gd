extends RefCounted

# Physical gamepad events remain outside this device. Injected events retain
# the real bindings, allowing GUI tests without interference from a connected pad.
const DEVICE := 1024


static func isolate() -> void:
	for action in InputMap.get_actions():
		var events := InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		Input.action_release(action)
		for event in events:
			event.device = DEVICE
			InputMap.action_add_event(action, event)


static func inject(event: InputEvent) -> void:
	var injected := event.duplicate() as InputEvent
	injected.device = DEVICE
	Input.parse_input_event(injected)
