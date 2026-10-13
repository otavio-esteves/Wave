extends SceneTree

const FixtureInput = preload("fixture_input.gd")
const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("WaveSettings").set_graphics_preset("medium")
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	FixtureInput.isolate()
	for frame in 3:
		await physics_frame
		await process_frame
	var city := current_scene.get_node("City")
	var counts: Dictionary = city.get_meta("composition_counts", {})
	_check(city.get_meta("visual_revision", "") == "2026-10-12-neighborhood-composition", "playable city references the complete authored composition revision")
	var filled := true
	var least := 100000
	for block in city.find_children("Block*", "Node3D", false, false):
		var id := str(block.name).trim_prefix("Block").to_int()
		if id in Layout.PARK_BLOCKS or id == Layout.WORKSHOP_BLOCK:
			continue
		var buildings := int(block.get_meta("building_count", 0))
		least = mini(least, buildings)
		filled = filled and buildings >= 8
	_check(filled, "every ordinary block has substantial built frontage (minimum %d buildings)" % least)
	_check(int(counts.get("courts", 0)) == Layout.PARK_BLOCKS.size() and int(counts.get("playgrounds", 0)) == Layout.PARK_BLOCKS.size(), "every public park contains an authored court and playground with safe parcels")
	_check(int(counts.get("street_trees", 0)) > 1500 and int(counts.get("planted_gaps", 0)) > 500, "street canopy and residual block planting are present across the expanded neighbourhood")
	_check(int(counts.get("shops", 0)) > 150 and int(counts.get("utility_poles", 0)) > 100 and int(counts.get("benches", 0)) > 700, "commercial and public-space details ship in the playable scene")
	var shrub_batches := 0
	var glass_batches := 0
	var wire_segments := 0
	var sound_transforms := true
	for node in city.find_children("*", "MultiMeshInstance3D", true, false):
		var material: StandardMaterial3D = node.material_override
		if str(node.name).begins_with("shrub_"):
			shrub_batches += 1
			_check_shrub(node, material)
		if material.resource_name in ["downtown_glass", "downtown_glass_dark"]:
			glass_batches += 1
			sound_transforms = sound_transforms and material.albedo_texture != null and material.normal_texture != null
		for placement: Transform3D in node.multimesh.instance_transforms:
			sound_transforms = sound_transforms and placement.origin.is_finite() and placement.basis.determinant() > 0.0
			if str(node.name).begins_with("cylinder_charcoal_") and placement.basis.x.length() < 0.02:
				wire_segments += 1
	_check(shrub_batches > 100 and glass_batches > 0 and sound_transforms, "textured shrubs and curtain walls retain finite, correctly oriented saved geometry")
	_check(wire_segments > 1000, "sagging overhead utility wires are included in the generated neighbourhood")
	var turf := false
	for node in city.find_children("Terrain_*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = node.material_override
		turf = material.albedo_texture != null and material.normal_texture != null and material.uv1_world_triplanar
		if turf:
			break
	_check(turf, "terrain uses original turf with world-scale detail on slopes")
	var cycle := current_scene.get_node("DayNightCycle")
	cycle.running = false
	cycle.set_hour(23.0)
	var lit_shops := false
	for node in city.find_children("*", "GeometryInstance3D", true, false):
		var material := node.material_override as StandardMaterial3D
		if material != null and material.resource_name == "residential_glass_lit":
			lit_shops = material.emission_enabled and material.emission_energy_multiplier > 0.0
			break
	_check(lit_shops, "occupied residential windows remain lit through the neighbourhood revision")
	current_scene.queue_free()
	await process_frame
	print("Neighbourhood composition: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_shrub(node: MultiMeshInstance3D, material: StandardMaterial3D) -> void:
	if material.resource_name != "tree_leaves" or material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or node.multimesh.mesh is SphereMesh:
		failures += 1
		push_error("Shrub lost its textured leaf silhouette: " + str(node.name))

func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
