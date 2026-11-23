extends RefCounted

const MeshLods = preload("res://scripts/tools/bake_mesh_lods.gd")
const Builder = preload("res://scripts/city/figueiras_builder.gd")
const TreeMesh = preload("res://scripts/city/neighborhood_tree_mesh.gd")
const STATIC_FINISHES := ["figueiras_surface_white", "figueiras_architecture"]


static func bake(city: Node3D) -> void:
	var meshes: Dictionary[ArrayMesh, ArrayMesh] = {}
	var flowers := Builder.make_flowers(false)
	var shrubs := TreeMesh.new().build_shrub(false)
	for node in city.get_children():
		if not node is GeometryInstance3D or node.has_meta("city_mesh_lod"):
			continue
		var material: Material = node.material_override
		if material == null:
			continue
		if node is MeshInstance3D and material.resource_name in STATIC_FINISHES and node.mesh is ArrayMesh:
			var mesh: ArrayMesh = _bake_mesh(meshes, node.mesh)
			if mesh != node.mesh:
				node.mesh = mesh
				node.set_meta("city_mesh_lod", true)
		elif node is MultiMeshInstance3D:
			if node.name.begins_with("flower_heads_flowers_"):
				node.set_meta("distant_plant_mesh", flowers)
			elif node.name.begins_with("shrub_bush_"):
				node.set_meta("distant_plant_mesh", shrubs)


static func _bake_mesh(meshes: Dictionary[ArrayMesh, ArrayMesh], mesh: ArrayMesh) -> ArrayMesh:
	if not meshes.has(mesh):
		meshes[mesh] = MeshLods.bake(mesh)
	return meshes[mesh]
