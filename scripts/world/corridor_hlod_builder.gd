extends RefCounted

const Baked = preload("res://scripts/city/baked_multimesh.gd")
var _colors: Dictionary = {}


func build(cells: Array[Node3D], origins: Array[Vector3]) -> Node3D:
	var root := Node3D.new()
	root.name = "Distant"
	var material := StandardMaterial3D.new()
	material.resource_name = "distant_opaque"
	material.vertex_color_use_as_albedo = true
	# Compatibility already renders in sRGB: keep the shared default shader.
	# WorldHLOD enables vertex conversion for linear-space renderers.
	material.roughness = 1.0
	for index in cells.size():
		var group := Node3D.new()
		group.name = "vale-%d" % index
		group.position = origins[index]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var trees: Array[Transform3D] = []
		var tree_material: Material
		var tree_mesh: Mesh
		var silhouettes := 0
		for child in cells[index].get_children():
			if child is MultiMeshInstance3D:
				var palette: StandardMaterial3D = child.material_override
				for placement: Transform3D in child.multimesh.instance_transforms:
					var transform: Transform3D = child.transform * placement
					if palette.resource_name == "street_tree":
						trees.append(transform)
						tree_material = palette
						tree_mesh = child.multimesh.mesh
					elif _silhouette(child.multimesh.mesh, palette.resource_name, placement):
						_append(tool, child.multimesh.mesh, transform, _color(palette))
						silhouettes += 1
			elif child is MeshInstance3D and (child.name.begins_with("Ground_") or child.name.begins_with("Avenue_") or child.name.begins_with("SideStreet_") or child.name.begins_with("TownSideStreet_") or child.name.contains("Forecourt_") or child.name.begins_with("VacantLot_")):
				_append(tool, child.mesh, child.transform, _color(child.material_override))
		var opaque := MeshInstance3D.new()
		opaque.name = "Silhouette"
		opaque.mesh = tool.commit()
		opaque.material_override = material
		opaque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(opaque)
		if not trees.is_empty():
			var cards := MultiMeshInstance3D.new()
			cards.name = "Trees"
			var batch := Baked.new()
			batch.mesh = tree_mesh
			batch.billboard_radius = 6.0
			batch.instance_transforms = trees
			cards.multimesh = batch
			cards.material_override = tree_material
			cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(cards)
		group.set_meta("silhouettes", silhouettes)
		group.set_meta("trees", trees.size())
		group.set_meta("triangles", opaque.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3 + trees.size() * 2)
		root.add_child(group)
	return root


func _silhouette(mesh: Mesh, palette: String, placement: Transform3D) -> bool:
	var size := placement.basis.get_scale().abs()
	return (mesh is PrismMesh and palette == "roof") or (mesh is BoxMesh and ((palette == "plaster" and size.y >= 3.0 and minf(size.x, size.z) >= 8.0) or (palette == "metal" and minf(size.x, size.z) >= 20.0)))


func _color(material: StandardMaterial3D) -> Color:
	if _colors.has(material):
		return _colors[material]
	var tint := material.albedo_color
	if material.albedo_texture != null:
		# Sample source pixels offline; never read back the GPU in the game.
		var image := Image.load_from_file(ProjectSettings.globalize_path(material.albedo_texture.resource_path))
		assert(image != null and not image.is_empty())
		var rgb := Vector3.ZERO
		var count := 0
		for y in range(0, image.get_height(), maxi(1, image.get_height() / 32)):
			for x in range(0, image.get_width(), maxi(1, image.get_width() / 32)):
				var pixel := image.get_pixel(x, y)
				rgb += Vector3(pixel.r, pixel.g, pixel.b)
				count += 1
		rgb /= count
		tint *= Color(rgb.x, rgb.y, rgb.z)
	_colors[material] = tint
	return tint


func _append(tool: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color) -> void:
	var normal_basis := transform.basis.inverse().transposed()
	for surface in mesh.get_surface_count():
		var data := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else points.size()
		for offset in count:
			var vertex := indices[offset] if not indices.is_empty() else offset
			tool.set_normal((normal_basis * normals[vertex]).normalized())
			tool.set_color(color)
			tool.add_vertex(transform * points[vertex])
