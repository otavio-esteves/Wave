extends SceneTree

const Foliage = preload("res://scripts/city/pilot_foliage_lod.gd")
const Baked = preload("res://scripts/city/baked_multimesh.gd")
var checks := 0
var failures := 0

class ProfileHarness:
	extends "res://scripts/tools/pilot_profile.gd"
	func _ready() -> void:
		pass

class StructuralFixture:
	extends Node
	var economy_enabled := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var initial_orphans := Node.get_orphan_node_ids()
	InputSetup.configure()
	root.get_node("WaveSettings").set_graphics_preset("economy")
	var atlas := _atlas()
	var probe := Foliage.new()
	probe.domain = "blossoms"
	probe.atlas = ImageTexture.create_from_image(Image.create(8, 4, false, Image.FORMAT_RGBA8))
	_check(not probe.atlas_supports_domain(), "an old or empty atlas cannot silently become a blossom proxy")
	probe.atlas = atlas
	_check(probe.atlas_supports_domain(), "the independently tagged nonempty fourteenth layer satisfies the blossom cache guard")
	probe.free()
	var world := Node3D.new()
	var city := Node3D.new()
	city.name = "City"
	city.position = Vector3(12, 3, 8)
	world.add_child(city)
	var mesh := preload("res://scripts/city/neighborhood_flower_mesh.gd").build()
	var gold := StandardMaterial3D.new()
	gold.resource_name = "blossom_gold"
	gold.albedo_color = Color("e6bd50")
	gold.vertex_color_use_as_albedo = false
	var violet := gold.duplicate() as StandardMaterial3D
	violet.resource_name = "blossom_violet"
	violet.albedo_color = Color("b77cbb")
	var near := _batch(city, "flower_cluster_blossom_gold_true_0_0", mesh, gold, 10)
	var far := _batch(city, "flower_cluster_blossom_gold_true_4_0", mesh, gold, 400)
	far.layers = 4
	var purple := _batch(city, "flower_cluster_blossom_violet_false_5_0", mesh, violet, 550)
	var hidden := _batch(city, "flower_cluster_blossom_gold_true_8_0", mesh, gold, 850)
	hidden.hide()
	var leaf_material := StandardMaterial3D.new()
	leaf_material.resource_name = "tree_leaves"
	leaf_material.vertex_color_use_as_albedo = true
	var leaves := _batch(city, "tree_leaves0_tree_leaves_true_7_0", BoxMesh.new(), leaf_material, 700)
	var bark_material := leaf_material.duplicate() as StandardMaterial3D
	bark_material.resource_name = "tree_bark"
	var bark := _batch(city, "tree_bark0_tree_bark_true_7_0", BoxMesh.new(), bark_material, 700)
	var unrelated := _batch(city, "flower_cluster_hedge_true_6_0", mesh, leaf_material, 600)
	var car := preload("res://scenes/cars/player_car.tscn").instantiate() as PlayerCar
	car.name = "PlayerCar"
	car.position = city.position
	world.add_child(car)
	root.add_child(world)
	car.set_physics_process(false)
	var trees := Foliage.new()
	trees.atlas = atlas
	world.add_child(trees)
	_check(trees.domain == "foliage" and trees.groups.size() == 2 and near.visible and far.visible and purple.visible and unrelated.visible, "default leaf/bark selection excludes every blossom and leaves its visibility untouched")
	_check(trees.snapshot().detail_radius == 200.0 and trees.snapshot().retain_radius == 260.0 and trees.alpha_cutoff == 0.35, "default gameplay foliage distances and cutoff remain unchanged")
	var source_placements: Array[Transform3D] = far.multimesh.instance_transforms.duplicate()
	var source_colours: PackedColorArray = far.multimesh.instance_tints.duplicate()
	var lod := _controller(atlas)
	world.add_child(lod)
	_check(lod.groups.size() == 4 and lod.total_instances == 3 and near.visible and not far.visible and not purple.visible and not hidden.visible and unrelated.visible and not leaves.visible and not bark.visible, "blossom domain owns only gold/violet flower clusters and preserves leaf/bark/hidden/unknown state")
	_check(lod.snapshot().detail_radius == 40.0 and lod.snapshot().retain_radius == 70.0 and lod.snapshot().alpha_cutoff == 0.15 and lod.snapshot().proxy_instances == 2, "diagnostic domain selects its forty/seventy metre near and retention budgets")
	var record: Dictionary
	for candidate in lod.groups:
		if candidate.node == far:
			record = candidate
	var entry: Dictionary = lod.proxies[record.proxy_key]
	var buffer: PackedFloat32Array = entry.source_buffer
	var offset: int = record.offset
	_check(buffer[offset + 16] == 13 and Color(buffer[offset + 12], buffer[offset + 13], buffer[offset + 14], buffer[offset + 15]) == Color.WHITE, "flower layer13 uses WHITE instance tint when the source material ignores vertex colour")
	_check(entry.node.material_override.get_shader_parameter("albedo_modulate") == gold.albedo_color and is_equal_approx(entry.node.material_override.get_shader_parameter("alpha_cutoff"), 0.15), "gold/violet come only from the live source albedo and the configured alpha cutoff")
	var original_bounds := mesh.get_aabb()
	var span := maxf(original_bounds.size.x, maxf(original_bounds.size.y, original_bounds.size.z)) * 1.12
	var expected := far.transform * source_placements[0] * Transform3D(Basis.from_scale(Vector3.ONE * span), original_bounds.get_center())
	var stored := Transform3D(Basis(Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]), Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]), Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])), Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11]))
	_check(stored.is_equal_approx(expected) and entry.node.layers == far.layers and entry.node.multimesh.mesh.get_faces().size() / 3 == 4, "rotated nonuniform bloom geometry keeps its source pivot, shape scale and camera layers")
	_check(far.multimesh.instance_transforms == source_placements and far.multimesh.instance_tints == source_colours, "original flower transforms and colour arrays are immutable")
	car.position = city.position + Vector3(400, 0, 0)
	lod.refresh()
	_check(far.visible and not near.visible, "entering the flower district restores original ninety-triangle source geometry")
	car.position = city.position + Vector3(460, 0, 0)
	lod.refresh()
	_check(far.visible, "previously active blooms remain stable inside the retention band")
	lod.set_render_profile(false, false)
	_check(near.visible and far.visible and purple.visible and not hidden.visible and lod.snapshot().proxy_instances == 0, "full geometry opt-out restores exact authored flower visibility")
	lod.set_render_profile(true, false)
	_check(not far.visible, "re-enabling blossom HLOD starts at entry rather than full-detail retention")
	car.reset_car()
	car.set_physics_process(false)
	_check(near.visible and not far.visible, "reset immediately returns the selected source blossoms to spawn")
	lod.set_canopy_visible(false)
	_check(not near.visible and not far.visible and not purple.visible and lod.snapshot().proxy_instances == 0, "no-blossoms hides the original and proxy domain together")
	lod.set_canopy_visible(true)
	lod.free()
	_check(near.visible and far.visible and purple.visible and not hidden.visible and not leaves.visible and not bark.visible, "freeing the diagnostic controller restores flowers without touching the default foliage controller")
	var structural := StructuralFixture.new()
	structural.name = "CityVisualLOD"
	world.add_child(structural)
	var profile := ProfileHarness.new()
	root.add_child(profile)
	profile.world = world
	for node in [near, far, purple, hidden]:
		profile.geometry.append({"node": node, "material": node.material_override, "visible": node.visible})
	_check(not "blossom-hlod" in profile.DEFAULT_CASES and not "no-blossoms" in profile.DEFAULT_CASES and profile._apply_blossom_hlod(atlas), "only an explicit profiler request creates the configured second domain")
	profile._apply("no-blossoms")
	_check(not near.visible and not far.visible and not purple.visible and profile._diagnostic_blossoms.snapshot().proxy_instances == 0, "profiler no-blossoms removes both representations when the domain is present")
	profile._restore_blossom_hlod()
	_check(not is_instance_valid(profile._diagnostic_blossoms) and not world.has_node("DiagnosticBlossomLOD") and near.visible and far.visible and purple.visible and not hidden.visible, "profiler cleanup frees the second controller and restores every authored source flag")
	root.get_node("WaveSettings").set_graphics_preset("high")
	_check(not profile._apply_blossom_hlod(atlas), "full authored settings cannot activate the diagnostic blossom simplification")
	var disabled := _controller(atlas)
	world.add_child(disabled)
	_check(disabled.groups.is_empty() and disabled.proxies.is_empty(), "full-detail startup allocates no unused blossom buffers")
	disabled.free()
	profile.world = null
	profile.geometry.clear()
	profile.free()
	world.free()
	for index in 3:
		await process_frame
	if OS.is_debug_build():
		var remaining := Node.get_orphan_node_ids()
		initial_orphans.sort()
		remaining.sort()
		_check(remaining == initial_orphans, "domain and profiler cleanup leave no orphan nodes")
	print("Pilot blossom HLOD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _controller(atlas: Texture2D) -> Node3D:
	var lod := Foliage.new()
	lod.domain = "blossoms"
	lod.detail_radius = 40.0
	lod.retain_radius = 70.0
	lod.alpha_cutoff = 0.15
	lod.atlas = atlas
	return lod


func _atlas() -> Texture2D:
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var layers: Array = []
	for index in 14:
		layers.append({"kind": "flower_cluster" if index == 13 else "fixture%d" % index})
	texture.set_meta("layer_count", 14)
	texture.set_meta("layers", layers)
	texture.set_meta("nonempty_layers", [13])
	return texture


func _batch(city: Node3D, node_name: String, mesh: Mesh, material: Material, x: float) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.position.x = x
	node.rotation.y = 0.2
	node.multimesh = Baked.new()
	node.multimesh.mesh = mesh
	var transforms: Array[Transform3D] = [Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3(2, 3, 4)), Vector3(-2, 1, 3))]
	node.multimesh.set_instances(transforms, PackedColorArray([Color(0.2, 0.7, 0.1, 0.6)]))
	node.material_override = material
	city.add_child(node)
	return node


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
