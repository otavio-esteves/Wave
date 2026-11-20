extends SceneTree

# Headless CPU/memory/structure diagnostic. It deliberately makes no claim about
# GPU time, actual draw calls, frame pacing, or a controlled startup benchmark.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var city_path := "res://scenes/city/pilot/pilot_city.scn"
	var output := "user://city-cpu.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--city="):
			city_path = argument.trim_prefix("--city=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	root.get_node("WaveSettings").set_graphics_preset("legacy")
	var source := FileAccess.get_file_as_string("res://scenes/city/drive_pilot_city.tscn")
	var temporary := "user://cpu-world.tscn"
	FileAccess.open(temporary, FileAccess.WRITE).store_string(source.replace("res://scenes/city/pilot/pilot_city.scn", city_path))
	var started := Time.get_ticks_usec()
	print("City CPU phase: resource-load-start; usec=%d; city=%s" % [started, city_path])
	var packed := load(temporary) as PackedScene
	if packed == null:
		quit(1)
		return
	var loaded := Time.get_ticks_usec()
	print("City CPU phase: resource-load-finish; usec=%d; phase_ms=%.3f" % [loaded, (loaded - started) / 1000.0])
	var world := packed.instantiate()
	var instantiated := Time.get_ticks_usec()
	print("City CPU phase: scene-instantiated; usec=%d; phase_ms=%.3f" % [instantiated, (instantiated - loaded) / 1000.0])
	root.add_child(world)
	var attached := Time.get_ticks_usec()
	print("City CPU phase: world-attached; usec=%d; phase_ms=%.3f" % [attached, (attached - instantiated) / 1000.0])
	world.get_node("PlayerCar").set_physics_process(false)
	world.get_node("DayNightCycle").running = false
	var geometries := world.get_node("City").find_children("*", "GeometryInstance3D", true, false)
	var categories: Dictionary = {}
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	var multimeshes: Dictionary = {}
	var multimesh_load_work: Dictionary = {}
	for node in geometries:
		var material := node.material_override as StandardMaterial3D
		var key: String = material.resource_name if material != null else str(node.get_meta("surface_kind", "unknown"))
		if not categories.has(key):
			categories[key] = {"batches": 0, "instances": 0}
		categories[key].batches += 1
		if material != null:
			materials[material] = true
		if node is MultiMeshInstance3D:
			categories[key].instances += node.multimesh.instance_count
			meshes[node.multimesh.mesh] = true
			if not multimeshes.has(node.multimesh):
				multimeshes[node.multimesh] = true
				if node.multimesh.has_method("load_work"):
					var work: Dictionary = node.multimesh.load_work()
					for counter: String in work:
						multimesh_load_work[counter] = int(multimesh_load_work.get(counter, 0)) + int(work[counter])
	var lod := world.get_node("CityVisualLOD")
	var foliage := world.get_node_or_null("CityFoliageLOD")
	var refresh_started := Time.get_ticks_usec()
	# Apply the real preset so every current renderer budget participates. The
	# original diagnostic only toggled the architectural controller directly.
	root.get_node("WaveSettings").set_graphics_preset("economy")
	var refresh_ms := (Time.get_ticks_usec() - refresh_started) / 1000.0
	var memory_after_refresh := Performance.get_monitor(Performance.MEMORY_STATIC)
	var selection: Array = []
	var car := world.get_node("PlayerCar") as Node3D
	var layout = preload("res://scripts/city/pilot_city_layout.gd")
	for id in [150, 113, 119]:
		car.position = layout.node(id)
		refresh_started = Time.get_ticks_usec()
		lod.refresh()
		var selected := {"node": id, "refresh_ms": (Time.get_ticks_usec() - refresh_started) / 1000.0, "candidate_batches": lod.last_refresh_candidates, "near_batches": 0, "near_instances": 0, "proxy_batches": 0, "proxy_instances": 0}
		if foliage != null:
			refresh_started = Time.get_ticks_usec()
			foliage.refresh()
			selected["foliage_refresh_ms"] = (Time.get_ticks_usec() - refresh_started) / 1000.0
			selected["foliage_hlod"] = foliage.snapshot()
		for record in lod.groups:
			if record.node.visible:
				selected.near_batches += 1
				selected.near_instances += record.node.multimesh.instance_count
		for entry in lod.proxies.values():
			if entry.node.visible:
				selected.proxy_batches += 1
				selected.proxy_instances += entry.node.multimesh.instance_count
		selection.append(selected)
	var step_times: Array[float] = []
	var step_candidates: Array[int] = []
	var foliage_step_times: Array[float] = []
	var step_origin: Vector3 = layout.node(150)
	for step in 16:
		car.position = step_origin + Vector3(step * 16.1, 0, 0)
		refresh_started = Time.get_ticks_usec()
		lod.refresh()
		step_times.append((Time.get_ticks_usec() - refresh_started) / 1000.0)
		step_candidates.append(lod.last_refresh_candidates)
		if foliage != null:
			refresh_started = Time.get_ticks_usec()
			foliage.refresh()
			foliage_step_times.append((Time.get_ticks_usec() - refresh_started) / 1000.0)
	step_times.sort()
	step_candidates.sort()
	var physics := world.get_node("CityPhysics")
	var report := {"city": city_path, "scope": "headless CPU/structure diagnostic, shared machine; no GPU or FPS measurement", "engine": Engine.get_version_info().string, "load_ms": (loaded - started) / 1000.0, "instantiate_ms": (instantiated - loaded) / 1000.0, "attach_ms": (attached - instantiated) / 1000.0, "economy_refresh_ms": refresh_ms, "geometry_batches": geometries.size(), "unique_multimesh_meshes": meshes.size(), "unique_materials": materials.size(), "categories": categories, "static_memory_bytes": memory_after_refresh, "physics_total_shapes": physics.total_shapes, "physics_active_shapes": physics.active_shapes, "lod_authored_instances": lod.total_detail_instances, "lod_proxy_instances": lod.total_proxy_instances, "lod_selection": selection}
	report["runtime_city_nodes"] = world.get_node("City").find_children("*", "", true, false).size() + 1
	report["lod_group_batches"] = lod.groups.size()
	report["unique_multimesh_resources"] = multimeshes.size()
	report["multimesh_load_work"] = multimesh_load_work
	report["structural_hlod_preparation"] = lod.preparation_diagnostics.duplicate(true)
	report["runtime_batch_compaction"] = world.get_node("City").get_meta("runtime_batch_compaction", {})
	if foliage != null:
		report["foliage_hlod"] = foliage.snapshot()
		foliage_step_times.sort()
		report["synthetic_foliage_updates"] = {"median_ms": foliage_step_times[8], "max_ms": foliage_step_times[-1], "samples": foliage_step_times.size()}
	report["synthetic_step_updates"] = {"step_m": 16.1, "samples": 16, "median_ms": step_times[8], "max_ms": step_times[-1], "max_candidates": step_candidates[-1], "scope": "CPU selection only; not a driven route or frame time"}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("City CPU diagnostic: %s; load %.1f ms, instantiate %.1f ms, attach %.1f ms" % [output, report.load_ms, report.instantiate_ms, report.attach_ms])
	world.queue_free()
	await process_frame
	quit()
