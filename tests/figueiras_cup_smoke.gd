extends SceneTree

const FixtureInput = preload("fixture_input.gd")
const FixtureAudio = preload("fixture_audio.gd")
const GhostRun = preload("res://scripts/city/figueiras_ghost_run.gd")
const Cup = preload("res://scripts/city/figueiras_cup.gd")
const Events = preload("res://scripts/city/figueiras_events.gd")
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_render_loop_enabled(false)
	_check_replays()
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")) != OK:
		quit(1)
		return
	await scene_changed
	FixtureInput.isolate()
	var sprint := current_scene.get_node("AlamedaSprint")
	var weather := current_scene.get_node("Weather")
	var map: Control = current_scene.get_node("HUD").city_map
	_check(sprint.cup_available() and sprint.events.size() == 12, "the cup has five authored stages and twelve events total")
	if not sprint.cup_available():
		quit(1)
		return
	var pass_event: Dictionary = sprint.events[sprint._index_of("passo")]
	var approach: Vector2 = pass_event.curve.point_at(341.0)
	_check(Events.pace_note(pass_event, approach, 14.0).contains("Grampo à direita")
		and Events.pace_note(pass_event, approach, 2.0).is_empty(), "the Passo hairpin note arrives earlier at race speed")
	weather.set_wet(true)
	map.open_map()
	_check(paused and map._cup.visible and map._cup.text == "Iniciar Copa da Vila", "the real atlas offers the cup in free drive")
	map._cup.pressed.emit()
	_check(not paused and sprint.next_gate == 0 and sprint.cup.event_id() == Cup.STAGES[0],
		"the cup stages its first course without moving the player")
	weather.set_wet(false)
	_check(weather.wet and sprint.wet, "a cup keeps the chosen driving conditions throughout")
	sprint.next_gate = 1
	sprint._on_impact(0.68)
	sprint._finish_attempt(30.0)
	_check(sprint.cup.rounds.is_empty() and sprint._result_line.contains("Colisão forte"), "a major collision requires a clean retry before advancing")
	_check(sprint.record_for(0) == 30.0 and sprint.record_for(0, true) < 0.0, "a recorded time with a major collision never grants a medal")
	var car: PlayerCar = current_scene.get_node("PlayerCar")
	var home := car.spawn_transform
	_check(sprint.retry_from_start(0, true) and sprint.next_gate == 0 and car.spawn_transform == home
		and car.global_position.distance_to(sprint.gates[0].origin) < 9.0, "retry stages the car at the actual start and retains free-drive reset")
	sprint._finish_attempt(Events.target(sprint.events[sprint.selected], 3, true) - 1.0)
	_check(sprint.record_for(0, true) > 0.0, "a clean time persists as the medal reference on the atlas")
	var resumed := Cup.new()
	_check(resumed.active and resumed.wet and resumed.points() == 3 and resumed.event_id() == Cup.STAGES[1],
		"a completed stage atomically advances and resumes at that point")
	map.open_map()
	_check(map._preview == sprint.cup_event_index() and map._enter.text == "Marcar largada", "reopening the atlas focuses the next round")
	map._rows[2].grab_focus()
	_check(map._enter.disabled, "a standalone trial cannot discard an active championship")
	map.close_map()
	for remaining in range(1, Cup.STAGES.size()):
		sprint.start_attempt()
		_check(sprint.events[sprint.selected].id == Cup.STAGES[remaining] and sprint.next_gate == 0,
			"T selects the current cup course in round %d" % (remaining + 1))
		sprint._finish_attempt(Events.target(sprint.events[sprint.selected], 3, true) - 1.0)
	resumed = Cup.new()
	_check(not resumed.active and resumed.record(true) == 15 and resumed.record(false) == -1,
		"winning the rainy cup persists its trophy independently of dry records")
	sprint.start_cup()
	sprint.abort_cup()
	resumed = Cup.new()
	_check(not resumed.active and resumed.record(true) == 15, "ending an ongoing cup keeps previously finished trophies")
	await FixtureAudio.drain(self)
	print("Figueiras cup and ghosts: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))


func _check_replays() -> void:
	var run := GhostRun.new()
	for index in 16:
		var t := index / 15.0
		run.add_pose(t, Transform3D(Basis(Vector3.UP, 0.5 * t), Vector3(12.0 * t, 3.0, 0.0)))
	_check(run.save_run("test-fixture", false, 0x88776655, 12.0) == OK, "save a compact local run")
	var restored := GhostRun.new()
	restored.load_run("test-fixture", false, 0x88776655, 12.0)
	_check(is_equal_approx(restored.duration(), 1.0)
		and restored.pose_at(0.31).origin.is_equal_approx(Vector3(3.72, 3.0, 0.0))
		and absf(restored.pose_at(0.85).basis.get_euler().y - 0.425) < 0.001, "saved ghost interpolates position and heading")
	restored.load_run("test-fixture", true, 0x88776655, 12.0)
	_check(restored.samples.is_empty(), "dry and rainy ghosts are independent")
	restored.load_run("test-fixture", false, 0x88776654, 12.0)
	_check(restored.samples.is_empty(), "ghost is rejected after a course change")
	var invalid := GhostRun.new()
	invalid.add_pose(0.0, Transform3D.IDENTITY)
	invalid.add_pose(0.06, Transform3D(Basis.IDENTITY, Vector3(150, 0, 0)))
	_check(invalid.save_run("test-fixture", false, 0x88776655, 12.0) == ERR_INVALID_DATA,
		"an invalid discontinuous run cannot replace a valid ghost")
	restored.load_run("test-fixture", false, 0x88776655, 12.0)
	_check(is_equal_approx(restored.duration(), 1.0), "rejecting an invalid replacement preserves the prior replay")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
