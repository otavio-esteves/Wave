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
	_check(settings.get_graphics_preset() == "custom" and lod.economy_enabled and not far.visible and is_equal_approx(surface.lod_bias, 0.2), "custom resolution preserves the Economy tower and surface budgets")
	settings.set_graphics("shadows", true)
	settings.set_graphics("antialiasing", true)
	settings.set_graphics("material_detail", true)
	_check(lod.economy_enabled and not far.visible and is_equal_approx(lod.groups[0].detail_radius, VisualLOD.DETAIL_RADIUS), "shadow, MSAA and material controls preserve the chosen geometry detail and radius")
	settings.set_graphics("city_detail_extended", true)
	_check(is_equal_approx(lod.groups[0].detail_radius, VisualLOD.DETAIL_RADIUS * 1.6) and not far.visible, "independent city distance control extends the structural detail budget")
	settings.save_settings()
	settings.graphics.city_lod = false
	settings.reload_settings()
	_check(settings.graphics.city_lod and lod.economy_enabled and not far.visible, "custom geometry preference survives saved settings reload")
	settings.set_graphics("city_lod", false)
	_check(near.visible and far.visible and _proxy_transforms(lod).is_empty() and is_equal_approx(surface.lod_bias, 0.5), "geometry control restores full towers and the authored surface budget")
	settings.set_graphics_preset("economy")
	_check(lod.economy_enabled and not far.visible, "Economy preset enables geometry simplification again")
	settings.set_graphics_preset("medium")
	_check(lod.economy_enabled and near.visible and not far.visible, "balanced preset uses a larger structural-detail radius while preserving near facades")
	for preset in ["high", "legacy"]:
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
	_check(combined.proxies.size() == 4 and _proxy_transforms(combined).size() == 4, "equivalent materials and cube meshes from separate resources merge within the same proxy sector")
	combined.set_economy_enabled(false)
	combined.free()
	var near_house := _house(city, 100)
	var far_house := _house(city, 900)
	var houses := VisualLOD.new()
	world.add_child(houses)
	_check(near_house.all(func(node): return node.visible) and far_house.all(func(node): return not node.visible), "residential walls, roofs and windows retain full detail near the car")
	var far_parts: Array[Transform3D] = []
	for record in houses.groups:
		if record.node in far_house:
			for key in record.proxy_keys:
				for segment in houses.proxies[key].members:
					if segment.group == record:
						for index in segment.count:
							far_parts.append(VisualLOD.unpack_transform(houses.proxies[key].source_buffer, segment.offset / 16 + index))
	_check(far_parts.size() == 3, "distant houses retain their main wall volume, pitched roof and window pane while omitting fine rails")
	_check(far_parts.any(func(placement): return placement.origin == Vector3(900, 9, 0)), "pitched residential roof retains its authored transform")
	car.position.x = 900
	houses.refresh()
	_check(far_house.all(func(node): return node.visible) and near_house.all(func(node): return not node.visible), "crossing into a residential district restores all authored facade parts")
	car.reset_car()
	car.set_physics_process(false)
	_check(near_house.all(func(node): return node.visible), "reset restores nearby residential detail immediately")
	settings.set_graphics_preset("medium")
	houses.set_economy_enabled(false)
	_check(near_house.all(func(node): return node.visible) and far_house.all(func(node): return node.visible) and _proxy_transforms(houses).is_empty(), "full-detail profiles restore residential geometry without changing saved instances")
	var uv_material: StandardMaterial3D = material.duplicate()
	uv_material.uv1_scale.x = 0.5
	var palette := preload("res://scripts/city/pilot_proxy_palette.gd").new()
	_check(VisualLOD._material_key(material) != VisualLOD._material_key(uv_material) and palette.key(material, false) == palette.key(uv_material, false) and uv_material.uv1_scale.x == 0.5, "nearby authored UV properties stay distinct while distant opaque reflectance may share a palette draw")
	houses.free()
	settings.set_graphics_preset("high")
	for index in 20:
		_tower(city, 3000 + index * 600, material)
	var lazy := VisualLOD.new()
	world.add_child(lazy)
	_check(lazy.groups.is_empty() and lazy.proxies.is_empty(), "full-detail startup allocates no unused far-building buffers")
	lazy.set_economy_enabled(true)
	lazy.refresh()
	_check(lazy.last_refresh_candidates < lazy.groups.size() / 2 and near_house.all(func(node): return node.visible), "moving selection polls nearby and previously active groups instead of the whole city")
	car.position.x = 14400
	lazy.refresh()
	_check(not near.visible and lazy.active_detail_batches > 0, "spatial selection finds a distant destination after teleporting across many cells")
	car.reset_car()
	car.set_physics_process(false)
	_check(near.visible and near_house.all(func(node): return node.visible), "spatial reset releases the old district and restores the spawn detail")
	lazy.set_economy_enabled(false)
	lazy.free()
	for source in city.get_children():
		source.free()
	_mixed_segments(world, city, car)
	world.queue_free()
	await process_frame
	print("Pilot visual LOD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _mixed_segments(world: Node3D, city: Node3D, car: PlayerCar) -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "charcoal"
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var placements: Array[Transform3D] = []
	for size in [Vector3(2, 2, 2), Vector3(0.1, 2, 2), Vector3(2, 0.1, 2), Vector3(2, 2, 0.1)]:
		placements.append(Transform3D(Basis(Vector3.UP, 0.3) * Basis.from_scale(size), Vector3.ZERO))
	var first := _mixed_source(city, 100, material, placements)
	var second := _mixed_source(city, 200, material, placements)
	var fine := _mixed_source(city, 900, material, [Transform3D(Basis.from_scale(Vector3(0.1, 0.1, 0.1)), Vector3.ZERO)])
	var glow_material: StandardMaterial3D = material.duplicate()
	glow_material.emission_enabled = true
	var glow := _mixed_source(city, 900, glow_material, [placements[3]])
	var original: Array[Transform3D] = first.multimesh.instance_transforms.duplicate()
	car.position.x = -100
	var lod := VisualLOD.new()
	world.add_child(lod)
	lod.set_render_profile(true, false)
	var group: Dictionary = lod.groups[0]
	_check(lod.groups.size() == 4 and group.node == first and group.proxy_keys.size() == 2 and lod.total_detail_instances == 10 and lod.total_proxy_instances == 9, "mixed box and thin meshes share one source selection record with exact unique instance totals")
	_check(first.visible and not second.visible and not fine.visible and lod.groups[2].proxy_keys.is_empty(), "fine-only sources remain indexed and hide outside detail even without any structural proxy")
	var source_bytes: Dictionary = {}
	var total_far := 0
	for key in group.proxy_keys:
		var entry: Dictionary = lod.proxies[key]
		source_bytes[key] = entry.source_buffer.to_byte_array()
		_check(entry.members.size() == 2 and entry.members[0].group == group and entry.members[1].group == lod.groups[1], "proxy segments refer to unique source records rather than duplicating hysteresis")
		total_far += entry.buffer.size() / 16
		var segment: Dictionary = entry.members[0]
		for index in segment.count:
			var transformed := VisualLOD.unpack_transform(entry.source_buffer, segment.offset / 16 + index)
			var source_index: int = index + 1 if key.ends_with("/major_faces") else index
			var before: AABB = first.transform * original[source_index] * AABB(Vector3.ONE * -0.5, Vector3.ONE)
			var after := transformed * AABB(Vector3.ONE * -0.5, Vector3.ONE)
			_check(before.position.is_equal_approx(after.position) and before.size.is_equal_approx(after.size), "major-face reorientation preserves rotated source bounds on every thin axis")
			var at: int = segment.offset + index * 16 + 12
			var tint: Color = first.multimesh.instance_tints[source_index]
			_check(entry.source_buffer.slice(at, at + 4) == PackedFloat32Array([tint.r, tint.g, tint.b, tint.a]), "mixed proxy segment preserves exact per-instance RGBA")
		if key.ends_with("/major_faces"):
			_check(entry.node.multimesh.mesh.get_faces().size() / 3 == 4 and entry.node.material_override.cull_mode == material.cull_mode, "production thin proxies use four triangles and preserve source culling")
	_check(total_far == 4 and lod.active_detail_batches == 1, "partial rebuild excludes both near-source segments and counts the source once")
	var glow_group: Dictionary = lod.groups[3]
	_check(glow_group.proxy_keys.size() == 1 and lod.proxies[glow_group.proxy_key].node.multimesh.mesh is BoxMesh and lod.proxies[glow_group.proxy_key].node.material_override == glow_material, "emissive thin boxes retain their original volumetric mesh and live material")
	car.position.x = 1000
	lod.refresh()
	var count := 0
	for key in group.proxy_keys:
		count += lod.proxies[key].buffer.size() / 16
		_check(lod.proxies[key].source_buffer.to_byte_array() == source_bytes[key], "dirty rebuild leaves immutable segment source bytes intact")
	_check(count == 8 and not first.visible and not second.visible, "moving away dirties every mesh segment of each original source")
	car.reset_car()
	car.set_physics_process(false)
	_check(first.visible and second.visible and group.proxy_keys.all(func(key): return lod.proxies[key].buffer.is_empty()), "reset restores both mixed sources and removes both distant mesh segments")
	lod.set_economy_enabled(false)
	_check(first.visible and second.visible and fine.visible and glow.visible and lod.proxies.values().all(func(entry): return not entry.node.visible), "master opt-out restores all original sources including fine-only nodes")
	lod.set_render_profile(true, true)
	_check(first.visible and second.visible and is_equal_approx(group.detail_radius, VisualLOD.HOUSE_DETAIL_RADIUS * 1.6), "extended profile re-enables the same source records and updates their shared distance once")
	_check(first.multimesh.instance_transforms == original and first.material_override == material, "selection and proxy splitting never modify the authored mesh placements or material")
	lod.set_economy_enabled(false)
	lod.free()


func _mixed_source(city: Node3D, x: float, material: StandardMaterial3D, placements: Array[Transform3D]) -> MultiMeshInstance3D:
	var source := MultiMeshInstance3D.new()
	source.position.x = x
	source.material_override = material
	source.multimesh = Baked.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	source.multimesh.mesh = box
	var colours := PackedColorArray()
	for index in placements.size():
		colours.append(Color(0.2 + index * 0.1, 0.5, 0.7, 1.0))
	source.multimesh.set_instances(placements, colours)
	city.add_child(source)
	return source


func _house(city: Node3D, x: float) -> Array[MultiMeshInstance3D]:
	var nodes: Array[MultiMeshInstance3D] = []
	for kind in ["wall", "roof", "window"]:
		var node := MultiMeshInstance3D.new()
		node.position.x = x
		node.visibility_range_end = 650
		var material := StandardMaterial3D.new()
		material.resource_name = {"wall": "ivory", "roof": "roof", "window": "residential_glass_lit"}[kind]
		node.material_override = material
		node.multimesh = Baked.new()
		var placements: Array[Transform3D] = []
		if kind == "wall":
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			node.multimesh.mesh = cube
			placements = [Transform3D(Basis.from_scale(Vector3(12, 8, 9)), Vector3(0, 4, 0)), Transform3D(Basis.from_scale(Vector3(0.05, 0.12, 9)), Vector3(6, 8, 0)), Transform3D(Basis.from_scale(Vector3(0.05, 8, 0.08)), Vector3(-6, 4, 0))]
		elif kind == "roof":
			var roof := PrismMesh.new()
			roof.size = Vector3(13, 2, 10)
			node.multimesh.mesh = roof
			placements = [Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 9, 0))]
		else:
			node.multimesh.mesh = QuadMesh.new()
			placements = [Transform3D(Basis.from_scale(Vector3(2, 1.5, 1)), Vector3(1, 4, 4.6))]
		node.multimesh.set_instances(placements)
		city.add_child(node)
		nodes.append(node)
	return nodes


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
			for index in entry.buffer.size() / 16:
				result.append(VisualLOD.unpack_transform(entry.buffer, index))
	return result


func _proxy_colours(lod: Node3D) -> PackedColorArray:
	var result := PackedColorArray()
	for entry in lod.proxies.values():
		if entry.node.visible:
			for index in entry.buffer.size() / 16:
				var at: int = index * 16 + 12
				result.append(Color(entry.buffer[at], entry.buffer[at + 1], entry.buffer[at + 2], entry.buffer[at + 3]))
	return result


func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
