extends SceneTree

const Baked = preload("res://scripts/city/baked_multimesh.gd")
const VisualLOD = preload("res://scripts/city/pilot_city_visual_lod.gd")
var checks := 0
var failures := 0

class GraphicsWorld:
	extends "res://scripts/city/pilot_city_world.gd"

	func _enter_tree() -> void:
		InputSetup.configure()

	func _ready() -> void:
		add_to_group("driving_world")
		apply_graphics()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputSetup.configure()
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset("economy")
	var world := GraphicsWorld.new()
	var city := Node3D.new()
	city.name = "City"
	world.add_child(city)
	var surface := MeshInstance3D.new()
	surface.mesh = BoxMesh.new()
	surface.set_meta("surface_kind", "Terrain")
	city.add_child(surface)
	var material := StandardMaterial3D.new()
	material.resource_name = "downtown_frame"
	material.vertex_color_use_as_albedo = true
	var near := _tower(city, 100, material)
	var far := _tower(city, 900, material.duplicate())
	var car := preload("res://scenes/cars/player_car.tscn").instantiate() as PlayerCar
	car.name = "PlayerCar"
	world.add_child(car)
	root.add_child(world)
	car.set_physics_process(false)
	var lod := VisualLOD.new()
	lod.name = "CityVisualLOD"
	world.add_child(lod)
	_check(near.visible and not far.visible, "economy keeps nearby facade detail and substitutes distant towers")
	_check(lod.total_detail_instances == 8 and lod.total_proxy_instances == 4, "far silhouette retains main mass and roof while omitting subpixel facade strips")
	var placements := _proxy_transforms(lod)
	_check(placements.size() == 2 and placements[0].origin == Vector3(900, 33, 0) and placements[1].origin == Vector3(900, 66.15, 0), "proxy transforms include the authored batch origin and roof position")
	var colours := _proxy_colours(lod)
	_check(colours == PackedColorArray([Color(0.9, 0.8, 0.7), Color(0.7, 0.8, 0.9)]), "far towers retain their exact per-instance palette")
	_check(near.visibility_range_end == 1800 and far.multimesh.instance_count == 4, "authored ranges, mesh resources and detail instances remain intact")
	car.position.x = 900
	lod.refresh()
	_check(far.visible and not near.visible and _proxy_transforms(lod)[0].origin.x == 100, "crossing a district restores full detail and updates the affected far proxy")
	car.position.x = 500
	lod.refresh()
	_check(far.visible and not near.visible, "retention margin prevents detail churn near the boundary")
	car.reset_car()
	car.set_physics_process(false)
	_check(near.visible and not far.visible, "reset immediately restores the authored nearby facade")
	lod.set_economy_enabled(false)
	_check(near.visible and far.visible and _proxy_transforms(lod).is_empty(), "medium/high restore all detail and disable the coarse representations")
	lod.set_economy_enabled(true)
	_check(near.visible and not far.visible, "returning to economy reapplies the near/far selection")
	settings.set_graphics("resolution", "960x540")
	_check(settings.get_graphics_preset() == "custom" and lod.economy_enabled and not far.visible and is_equal_approx(surface.lod_bias, 0.2), "custom resolution preserves Economy tower and surface simplification")
	settings.set_graphics("shadows", true)
	settings.set_graphics("antialiasing", true)
	settings.set_graphics("material_detail", true)
	_check(lod.economy_enabled and not far.visible, "shadow, MSAA and material controls preserve the chosen geometry detail")
	settings.save_settings()
	settings.graphics.city_lod = false
	settings.reload_settings()
	_check(settings.graphics.city_lod and lod.economy_enabled and not far.visible, "custom geometry preference survives saved settings reload")
	settings.set_graphics("city_lod", false)
	_check(near.visible and far.visible and _proxy_transforms(lod).is_empty() and is_equal_approx(surface.lod_bias, 0.5), "geometry control restores full towers and surface detail independently")
	settings.set_graphics_preset("economy")
	_check(lod.economy_enabled and not far.visible, "Economy preset enables geometry simplification again")
	for preset in ["medium", "high", "legacy"]:
		settings.set_graphics_preset(preset)
		_check(not lod.economy_enabled and near.visible and far.visible, "%s preset restores its authored geometry" % preset)
	settings.set_graphics_preset("economy")
	_check(VisualLOD._structural(Vector3(0.65, 12, 0.65), "downtown_copper") and VisualLOD._structural(Vector3(2.7, 1.8, 0.06), "downtown_window"), "distant representation preserves antennae and occupied window lighting")
	lod.set_economy_enabled(false)
	lod.queue_free()
	await process_frame
	_tower(city, 920, material.duplicate())
	var combined := VisualLOD.new()
	world.add_child(combined)
	_check(combined.proxies.size() == 2 and _proxy_transforms(combined).size() == 4, "equivalent materials and cube meshes from separate resources merge within the same proxy sector")
	world.queue_free()
	await process_frame
	print("Pilot visual LOD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _tower(city: Node3D, x: float, material: StandardMaterial3D) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.position.x = x
	node.visibility_range_end = 1800
	node.material_override = material
	node.multimesh = Baked.new()
	node.multimesh.mesh = BoxMesh.new()
	node.multimesh.mesh.size = Vector3.ONE
	var placements: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3(23, 66, 19)), Vector3(0, 33, 0)),
		Transform3D(Basis.from_scale(Vector3(24, 0.3, 20)), Vector3(0, 66.15, 0)),
		Transform3D(Basis.from_scale(Vector3(23, 0.18, 19)), Vector3(0, 10, 0)),
		Transform3D(Basis.from_scale(Vector3(0.27, 66, 0.16)), Vector3(2, 33, 9.55)),
	]
	node.multimesh.instance_transforms = placements
	node.multimesh.instance_tints = PackedColorArray([Color(0.9, 0.8, 0.7), Color(0.7, 0.8, 0.9), Color.WHITE, Color.WHITE])
	city.add_child(node)
	return node


func _proxy_transforms(lod: Node3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for entry in lod.proxies.values():
		if entry.node.visible:
			result.append_array(entry.node.multimesh.instance_transforms)
	return result


func _proxy_colours(lod: Node3D) -> PackedColorArray:
	var result := PackedColorArray()
	for entry in lod.proxies.values():
		if entry.node.visible:
			result.append_array(entry.node.multimesh.instance_tints)
	return result


func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
