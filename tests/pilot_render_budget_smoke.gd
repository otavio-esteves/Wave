extends SceneTree

const Baked = preload("res://scripts/city/baked_multimesh.gd")
const Palette = preload("res://scripts/city/pilot_proxy_palette.gd")
const FoliageLOD = preload("res://scripts/city/pilot_foliage_lod.gd")
const Compaction = preload("res://scripts/city/pilot_batch_compaction.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_palette_contract()
	_compaction_contract()
	var atlas := load(FoliageLOD.ATLAS_PATH) as Texture2D
	_check(atlas != null and atlas.get_size() == Vector2(2048, 1024) and atlas.get_meta("layers", []).size() >= 13 and atlas.get_meta("views", 0) == 2, "atlas contains independent source canopies, shrub and trunks with two views each")
	if atlas == null:
		quit(1)
		return
	var original_kinds: Array[String] = []
	for index in 6:
		original_kinds.append("tree_leaves%d" % index)
	original_kinds.append("shrub")
	for index in 6:
		original_kinds.append("tree_bark%d" % index)
	_check(range(13).all(func(index): return atlas.get_meta("layers")[index].kind == original_kinds[index]), "atlas extension preserves all thirteen original layer indices and source kinds")
	_check(atlas.get_image().has_mipmaps() and atlas.get_meta("layers")[6].kind == "shrub" and atlas.get_meta("layers")[7].kind == "tree_bark0", "atlas persists cell-isolated mipmaps and the shrub/trunk layer contract")
	_check(FoliageLOD._cross_cards().get_faces().size() == 12, "far foliage uses four triangles per source instance")
	InputSetup.configure()
	root.get_node("WaveSettings").set_graphics_preset("high")
	var world := Node3D.new()
	var city := Node3D.new()
	city.name = "City"
	world.add_child(city)
	var near := _batch(city, "tree_leaves0_tree_leaves_true_0_0", 70)
	var band := _batch(city, "tree_leaves2_tree_leaves_true_2_0", 235)
	var middle := _batch(city, "tree_leaves1_tree_leaves_true_3_0", 300)
	var far := _batch(city, "shrub_tree_leaves_true_8_0", 1000)
	far.visibility_range_end = 850.0
	far.layers = 4
	var bark := _batch(city, "tree_bark2_tree_bark_true_8_0", 1000)
	bark.material_override.resource_name = "tree_bark"
	var authored: Array[Transform3D] = far.multimesh.instance_transforms.duplicate()
	var car := preload("res://scenes/cars/player_car.tscn").instantiate() as PlayerCar
	car.name = "PlayerCar"
	world.add_child(car)
	root.add_child(world)
	car.set_physics_process(false)
	var lod := FoliageLOD.new()
	lod.atlas = atlas
	world.add_child(lod)
	_check(lod.groups.is_empty() and lod.proxies.is_empty(), "full-detail startup does not allocate an unused foliage HLOD")
	lod.set_render_profile(true, false)
	_check(near.visible and not band.visible and not middle.visible and not far.visible and not bark.visible, "cold foliage selection uses the entry radius, retaining volumetric sources only near the car")
	_check(lod.total_instances == 5 and lod.snapshot().proxy_instances == 4, "each source part has exactly one selected near or far representation")
	_check(far.multimesh.instance_transforms == authored, "HLOD does not alter any authored source transforms")
	var record: Dictionary
	for item in lod.groups:
		if item.node == far:
			record = item
	var data: PackedFloat32Array = lod.proxies[record.proxy_key].source_buffer
	var offset: int = record.offset
	var saved := Transform3D(Basis(Vector3(data[offset], data[offset + 4], data[offset + 8]), Vector3(data[offset + 1], data[offset + 5], data[offset + 9]), Vector3(data[offset + 2], data[offset + 6], data[offset + 10])), Vector3(data[offset + 3], data[offset + 7], data[offset + 11]))
	var bounds: AABB = far.multimesh.mesh.get_aabb()
	var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.12
	var expected: Transform3D = far.transform * authored[0] * Transform3D(Basis.from_scale(Vector3.ONE * span), bounds.get_center())
	_check(saved.is_equal_approx(expected) and data[offset + 16] == 6, "far card preserves rotated nonuniform scales, source pivot and the independent shrub layer")
	_check(Color(data[offset + 12], data[offset + 13], data[offset + 14], data[offset + 15]).is_equal_approx(Color(0.8, 0.9, 0.7, 0.6)), "far foliage retains instance tint and alpha in the native buffer")
	_check(is_equal_approx(lod.proxies[record.proxy_key].node.visibility_range_end, 850.0), "a single distant batch retains its authored range instead of drawing an unlimited forest")
	_check(lod.proxies[record.proxy_key].node.layers == far.layers, "foliage proxies preserve the original camera/reflection visibility layers")
	lod.set_canopy_visible(false)
	_check(not near.visible and lod.snapshot().proxy_instances == 1, "no-foliage diagnostic hides source and proxy canopies while retaining the trunk representation")
	lod.set_canopy_visible(true)
	_check(near.visible and lod.snapshot().proxy_instances == 4, "restoring the foliage diagnostic recovers the selected near/far canopies")
	lod.set_render_profile(true, true)
	_check(middle.visible and lod.snapshot().detail_radius == 320.0, "extended geometry distance retains full foliage farther away independently of normal maps")
	car.position.x = 1000
	lod.refresh()
	_check(far.visible and bark.visible and not near.visible, "moving into a distant district restores its original shrub and trunk geometry")
	car.reset_car()
	car.set_physics_process(false)
	_check(near.visible and not far.visible and not bark.visible, "vehicle reset immediately restores source foliage around the spawn")
	lod.set_render_profile(false, true)
	_check(near.visible and middle.visible and far.visible and bark.visible and lod.snapshot().proxy_instances == 0, "explicit geometry opt-out restores every source part and removes all impostors")
	lod.set_render_profile(true, false)
	_check(not band.visible, "re-enabling simplification starts in the entry radius rather than inheriting full-detail retention")
	car.position.x = 40
	lod.refresh()
	car.position.x = 0
	lod.refresh()
	_check(band.visible, "a previously selected source remains stable inside the retention band")
	car.position.x = 480
	lod.refresh()
	car.position.x = 510
	lod.refresh()
	_check(middle.visible, "retention distance keeps source foliage stable while crossing the entry boundary")
	world.queue_free()
	await process_frame
	print("Pilot render budget: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _palette_contract() -> void:
	var palette := Palette.new()
	var plaster := StandardMaterial3D.new()
	plaster.resource_name = "ivory"
	plaster.albedo_color = Color(0.7, 0.6, 0.5)
	plaster.vertex_color_use_as_albedo = true
	plaster.roughness = 0.91
	var stucco: StandardMaterial3D = plaster.duplicate()
	stucco.resource_name = "sage"
	stucco.albedo_color = Color(0.3, 0.5, 0.4)
	_check(palette.material(plaster, false) == palette.material(stucco, false) and palette.tint(plaster, Color.WHITE, false) != palette.tint(stucco, Color.WHITE, false), "equivalent distant reflectance models share a draw material while retaining distinct facade colours")
	var glass := StandardMaterial3D.new()
	glass.resource_name = "residential_glass_lit"
	glass.emission_enabled = true
	_check(palette.material(glass, true) == glass and palette.material(glass, false) == glass, "window panes and emissive facade materials retain their original live material")
	glass.emission_energy_multiplier = 2.5
	_check(palette.material(glass, true).emission_energy_multiplier == 2.5, "nighttime emission changes propagate to distant occupied windows without a copied stale value")
	_check(palette.material(plaster, false).albedo_texture == null and palette.material(plaster, false).vertex_color_use_as_albedo, "structural materials move subpixel texture reflectance into native instance colours")
	var cached: StandardMaterial3D = plaster.duplicate()
	cached.albedo_texture = load("res://assets/textures/neighborhood/stucco-albedo.res")
	_check(not palette.prepare(cached, false).preserve, "shipped facade textures resolve a hash-matched precomputed reflectance")
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color(0.4, 0.6, 0.8))
	var unknown: StandardMaterial3D = plaster.duplicate()
	unknown.albedo_texture = ImageTexture.create_from_image(image)
	_check(palette.material(unknown, false) == unknown and palette.prepare(unknown, false).preserve and palette.diagnostics().runtime_texture_readbacks == 0, "unknown embedded textures retain their authored material without a graphics-driver readback")


func _compaction_contract() -> void:
	var city := Node3D.new()
	var sector := Node3D.new()
	sector.transform = Transform3D(Basis(Vector3.UP, 0.2), Vector3(8, 3, 5))
	city.add_child(sector)
	var material := StandardMaterial3D.new()
	material.resource_name = "address_plate"
	var mesh := QuadMesh.new()
	var placements: Array[Transform3D] = []
	var source_centres: Array[Vector3] = []
	for x in [20.0, 35.0]:
		var node := _batch(sector, "Digit%d" % int(x), x)
		node.material_override = material
		node.multimesh.mesh = mesh
		node.multimesh.rebuild_instances()
		node.visibility_range_end = 55.0
		var placement: Transform3D = sector.transform * node.transform * node.multimesh.instance_transforms[0]
		placements.append(placement)
		source_centres.append((sector.transform * node.transform * node.multimesh.custom_aabb).get_center())
	var attachment_owner := _batch(sector, "DigitWithAttachment", 50)
	attachment_owner.material_override = material
	attachment_owner.multimesh.mesh = mesh
	attachment_owner.multimesh.rebuild_instances()
	attachment_owner.add_child(Node.new())
	var limited: Array[MultiMeshInstance3D] = []
	for x in [60.0, 75.0]:
		var node := _batch(sector, "DigitBegin%d" % int(x), x)
		node.material_override = material
		node.multimesh.mesh = mesh
		node.multimesh.rebuild_instances()
		node.visibility_range_begin = 10.0
		limited.append(node)
	Compaction.prepare(city)
	var nodes := city.find_children("RuntimeBatch_address_plate*", "MultiMeshInstance3D", true, false)
	_check(nodes.size() == 1 and nodes[0].get_parent() == sector and nodes[0].multimesh.instance_count == 2, "equivalent address batches compact before tree entry while preserving their parent visibility")
	_check(is_instance_valid(attachment_owner) and attachment_owner.get_child_count() == 1, "batches with attached runtime nodes are never freed by compaction")
	_check(limited.all(func(node): return is_instance_valid(node) and node.visibility_range_begin == 10.0), "batches with a nonzero entry range retain their original centre-dependent visibility")
	if nodes.size() == 1:
		var node: MultiMeshInstance3D = nodes[0]
		var same := true
		var saved: Array[Transform3D] = node.multimesh.instance_transforms
		for index in saved.size():
			same = same and (sector.transform * node.transform * saved[index]).is_equal_approx(placements[index])
		_check(same and node.material_override == material and node.multimesh.mesh == mesh, "batch compaction preserves every rotated scaled transform and the exact source material/mesh")
		var centre: Vector3 = sector.transform * node.transform * node.multimesh.custom_aabb.get_center()
		_check(source_centres.all(func(point): return node.visibility_range_end >= 55.0 + centre.distance_to(point) - 0.001), "merged visibility distance preserves all previously eligible source batches")
		_check(node.multimesh.instance_tints == PackedColorArray([Color(0.8, 0.9, 0.7, 0.6), Color(0.8, 0.9, 0.7, 0.6)]), "compaction preserves original instance colours and alpha")
	Compaction.prepare(city)
	_check(city.find_children("*", "MultiMeshInstance3D", true, false).size() == 4 and city.get_meta("runtime_batch_compaction").saved_batches == 1, "compaction is idempotent and records its actual batch reduction")
	city.free()


func _batch(city: Node3D, node_name: String, x: float) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.position.x = x
	node.multimesh = Baked.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 1.2, 0.5)
	node.multimesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.resource_name = "tree_leaves"
	material.vertex_color_use_as_albedo = true
	node.material_override = material
	var placements: Array[Transform3D] = [Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3(4, 7, 5)), Vector3(-2, 1, 3))]
	node.multimesh.set_instances(placements, PackedColorArray([Color(0.8, 0.9, 0.7, 0.6)]))
	city.add_child(node)
	return node


func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
