extends RefCounted


static func drain(tree: SceneTree) -> void:
	tree.call_group("wave_audio", "stop_audio")
	await tree.process_frame
	# The audio mixer uses wall time even when the test advances fixed steps.
	OS.delay_msec(120)
	await tree.process_frame
