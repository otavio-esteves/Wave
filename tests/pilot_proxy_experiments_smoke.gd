extends SceneTree

const Experiment = preload("res://scripts/tools/pilot_proxy_experiment.gd")
const Baked = preload("res://scripts/city/baked_multimesh.gd")
var checks := 0
var failures := 0

class FixtureLOD:
	extends Node3D
	var economy_enabled := true
	var groups: Array[Dictionary] = []
	var proxies: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var placements: Array[Transform3D] = []
	var colours := PackedColorArray()
	var sizes := [Vector3(8, 3, 7), Vector3(8, 0.3, 6), Vector3(2, 2, 0.1), Vector3(0.1, 2, 2), Vector3(2, 0.1, 2), Vector3(2, 2, 2), Vector3(0.1, 4, 2)]
	for index in sizes.size():
		placements.append(Transform3D(Basis(Vector3.UP, 0.37) * Basis.from_scale(sizes[index]), Vector3(index * 9, index, 3)))
		colours.append(Color(index * 0.1, 0.25, 0.75, 0.7))
	var buffer := Baked.make_buffer(placements, colours)
	var original := buffer.to_byte_array()
	var mass := Experiment.partition(buffer, "far-mass-only")
	_check(mass.box.size() / 16 == 2 and mass.thin.is_empty() and mass.removed == 5, "mass ceiling retains only the main volume and wide roof slab in a mixed buffer")
	_check(mass.box == buffer.slice(0, 32), "mass filtering retains exact source transform and RGBA bytes in original order")
	var thin := Experiment.partition(buffer, "far-flat-thin")
	_check(thin.box.size() / 16 == 2 and thin.thin.size() / 16 == 5 and thin.removed == 0, "flat-thin partitions all three narrow axes and the slab while preserving volumetric boxes")
	_check(buffer.to_byte_array() == original, "partitioning never edits its immutable input buffer")
	var indices := [1, 2, 3, 4, 6]
	var unit := AABB(Vector3.ONE * -0.5, Vector3.ONE)
	for index in indices.size():
		var source := placements[indices[index]]
		var transformed := Experiment._transform(thin.thin, index * 16)
		var before := source * unit
		var after := transformed * unit
		_check(before.position.is_equal_approx(after.position) and before.size.is_equal_approx(after.size) and transformed.origin.is_equal_approx(source.origin), "oriented plane keeps the source world bounds and pivot for mixed instance%d" % indices[index])
		_check(thin.thin.slice(index * 16 + 12, index * 16 + 16) == buffer.slice(indices[index] * 16 + 12, indices[index] * 16 + 16), "plane instance%d keeps exact source RGBA" % indices[index])
	var lod := FixtureLOD.new()
	root.add_child(lod)
	var material := StandardMaterial3D.new()
	material.resource_name = "far_palette_0_4_0"
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var node := _proxy(lod, "eligible", box, material, buffer)
	var pane := _proxy(lod, "pane", QuadMesh.new(), material, buffer)
	var emissive := material.duplicate() as StandardMaterial3D
	emissive.emission_enabled = true
	var glow := _proxy(lod, "emissive", box, emissive, buffer)
	var authored := material.duplicate() as StandardMaterial3D
	authored.resource_name = "preserved_authored_material"
	var preserved := _proxy(lod, "authored", box, authored, buffer)
	var near := MultiMeshInstance3D.new()
	near.multimesh = MultiMesh.new()
	lod.add_child(near)
	var hidden := MultiMeshInstance3D.new()
	hidden.multimesh = MultiMesh.new()
	hidden.hide()
	lod.add_child(hidden)
	lod.groups = [{"node": near, "active": true}, {"node": hidden, "active": false}]
	var initial_children := lod.get_child_count()
	var initial_bounds := node.multimesh.custom_aabb
	var experiment := Experiment.new()
	experiment.apply(lod, "no-far-buildings")
	_check(not node.visible and not pane.visible and near.visible and not hidden.visible, "no-far-buildings hides only proxies and preserves both authored source visibility states")
	experiment.cleanup()
	_check(node.visible and pane.visible and near.visible and not hidden.visible, "hidden-only proxy restoration returns exact original visibility")
	experiment.apply(lod, "no-buildings")
	_check(not node.visible and not near.visible and not hidden.visible, "no-buildings hides all structural groups and their far proxies")
	experiment.cleanup()
	_check(near.visible and not hidden.visible and lod.groups[0].active and not lod.groups[1].active, "source restoration preserves visibility and selection state independently")
	var stats := experiment.apply(lod, "far-mass-only")
	_check(stats.eligible_batches == 1 and node.multimesh.instance_count == 2 and pane.multimesh.instance_count == 7 and glow.multimesh.instance_count == 7 and preserved.multimesh.instance_count == 7, "mass experiment changes only opaque palette boxes, preserving panes, emission and authored materials")
	experiment.cleanup()
	_check(node.multimesh.instance_count == 7 and node.multimesh.custom_aabb == initial_bounds and lod.proxies.eligible.buffer.to_byte_array() == original and lod.proxies.eligible.source_buffer.to_byte_array() == original, "mass cleanup restores instance count and bounds without modifying either controller buffer")
	stats = experiment.apply(lod, "far-flat-thin")
	_check(stats.temporary_batches == 1 and stats.plane_instances == 5 and stats.box_instances == 2 and lod.get_child_count() == initial_children + 1, "all thin axes share one temporary MultiMesh and one four-triangle mesh per proxy")
	var temporary: MultiMeshInstance3D = experiment._temporary[0]
	_check(temporary.multimesh.mesh.get_faces().size() / 3 == 4 and temporary.material_override == material and temporary.material_override.cull_mode == BaseMaterial3D.CULL_DISABLED and temporary.multimesh.custom_aabb == initial_bounds and temporary.layers == node.layers and temporary.visibility_range_end == node.visibility_range_end, "temporary planes keep exact material/cull mode and conservative visibility eligibility")
	_check(pane.multimesh.instance_count == 7 and glow.multimesh.instance_count == 7 and preserved.multimesh.instance_count == 7, "flat-thin leaves non-box, emissive and preserved authored proxies unchanged")
	experiment.cleanup()
	_check(not is_instance_valid(temporary) and lod.get_child_count() == initial_children and node.multimesh.instance_count == 7 and node.visible and experiment.stats.is_empty(), "flat-thin cleanup frees every split node and restores the original proxy")
	_check(lod.proxies.eligible.buffer.to_byte_array() == original and lod.proxies.eligible.source_buffer.to_byte_array() == original, "all experiments leave immutable selection and source bytes intact")
	lod.economy_enabled = false
	_check(not experiment.apply(lod, "far-flat-thin").applied and lod.get_child_count() == initial_children, "full authored opt-out cannot create diagnostic proxy geometry")
	lod.free()
	print("Pilot proxy experiments: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _proxy(parent: FixtureLOD, key: String, mesh: Mesh, material: Material, buffer: PackedFloat32Array) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = true
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = buffer.size() / 16
	node.multimesh.custom_aabb = AABB(Vector3(-10, -10, -10), Vector3(100, 40, 40))
	node.multimesh.buffer = buffer
	node.material_override = material
	node.visibility_range_end = 900.0
	node.layers = 5
	parent.add_child(node)
	parent.proxies[key] = {"node": node, "buffer": buffer, "source_buffer": buffer}
	return node


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
