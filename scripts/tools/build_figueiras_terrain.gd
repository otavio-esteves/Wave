extends RefCounted

const Ground = preload("res://scripts/city/figueiras_ground.gd")
const CONTACT_DENSITY := 3.5
const MAX_CONTACT_SIZE := 2048
const CONTACT_PREFIX := "Ground_shade_"
const SURFACE_PREFIX := "figueiras_surface_"


static func optimize(map: Node3D) -> void:
	var receivers: Array[ShaderMaterial] = []
	var patches: Array[MeshInstance3D] = []
	var ranges: Dictionary = {}
	var mesh_count := 0
	var triangle_count := 0
	var distant_count := 0
	for child in map.get_children():
		var node := child as MeshInstance3D
		if node == null or not node.name.begins_with("Ground_"):
			continue
		if node.name.begins_with(CONTACT_PREFIX):
			patches.append(node)
			continue
		var finish := node.material_override as ShaderMaterial
		if finish == null or not finish.resource_name.begins_with(SURFACE_PREFIX):
			continue
		if finish not in receivers:
			receivers.append(finish)
		var surface_kind: int = finish.get_shader_parameter("surface_kind")
		if surface_kind not in [0, 1, 5]:
			continue
		var lowest := _bake_mesh_lods(node)
		if not lowest.is_empty():
			mesh_count += 1
			triangle_count += node.mesh.surface_get_array_index_len(0) / 3
			distant_count += lowest.size() / 3
			if surface_kind == 5:
				var origin := Vector2(node.position.x, node.position.z)
				var key := Vector2i((origin / (Ground.SECTOR_SIZE * 2.0)).floor())
				if not ranges.has(key):
					ranges[key] = []
				ranges[key].append([node, lowest])
	map.set_meta("terrain_lod", Vector3i(mesh_count, triangle_count, distant_count))
	var distant_batches := 0
	for key: Vector2i in ranges:
		if ranges[key].size() > 1:
			_bake_distant_grass(map, key, ranges[key])
			distant_batches += 1
	map.set_meta("terrain_distant_batches", distant_batches)
	if not patches.is_empty() and not receivers.is_empty():
		_bake_contact(map, patches, receivers)


static func _bake_mesh_lods(node: MeshInstance3D) -> PackedInt32Array:
	var base := node.mesh as ArrayMesh
	if base == null or base.get_surface_count() != 1:
		return PackedInt32Array()
	var arrays := base.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.size() < 144:
		return PackedInt32Array()
	var imported := ImporterMesh.new()
	imported.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, base.surface_get_material(0))
	imported.generate_lods(32.0, 0.0, [])
	var levels := imported.get_surface_lod_count(0)
	if levels == 0:
		return PackedInt32Array()
	var smallest := indices
	for level in levels:
		var candidate := imported.get_surface_lod_indices(0, level)
		if candidate.size() < smallest.size():
			smallest = candidate
	node.mesh = imported.get_mesh()
	node.set_meta("terrain_lod", levels)
	return smallest


static func _bake_distant_grass(map: Node3D, tile: Vector2i, members: Array) -> void:
	# Keep the original simplified boundary positions and attributes so the
	# distant group and its neighbours can swap at different times.
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var faces := PackedInt32Array()
	var lead: MeshInstance3D = members[0][0]
	for member: Array in members:
		var node: MeshInstance3D = member[0]
		var local: Vector3 = node.position - lead.position
		var source := node.mesh.surface_get_arrays(0)
		var remap := PackedInt32Array()
		remap.resize(source[Mesh.ARRAY_VERTEX].size())
		remap.fill(-1)
		for index: int in member[1]:
			if remap[index] < 0:
				remap[index] = positions.size()
				positions.append(source[Mesh.ARRAY_VERTEX][index] + local)
				normals.append(source[Mesh.ARRAY_NORMAL][index])
				colors.append(source[Mesh.ARRAY_COLOR][index])
				uv.append(source[Mesh.ARRAY_TEX_UV][index])
				uv2.append(source[Mesh.ARRAY_TEX_UV2][index])
				tangents.append_array(source[Mesh.ARRAY_TANGENT].slice(index * 4, index * 4 + 4))
			faces.append(remap[index])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var proxy := MeshInstance3D.new()
	proxy.name = "Ground_DistantGrass_%d_%d" % [tile.x, tile.y]
	proxy.position = lead.position
	proxy.mesh = mesh
	proxy.material_override = lead.material_override
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy.visibility_range_begin = 300.0
	proxy.visibility_range_begin_margin = 18.0
	proxy.set_meta("terrain_distant", true)
	map.add_child(proxy)
	proxy.owner = map
	for member: Array in members:
		var node: MeshInstance3D = member[0]
		node.visibility_parent = NodePath("../" + proxy.name)


static func _bake_contact(map: Node3D, patches: Array[MeshInstance3D], receivers: Array[ShaderMaterial]) -> void:
	var bounds := _footprint(patches[0])
	for patch in patches:
		bounds = bounds.merge(_footprint(patch))
	bounds = bounds.grow(1.0)
	var density := minf(CONTACT_DENSITY, MAX_CONTACT_SIZE / maxf(bounds.size.x, bounds.size.y))
	var resolution := Vector2i((bounds.size * density).ceil())
	var data := PackedByteArray()
	data.resize(resolution.x * resolution.y * 2)
	var source_triangles := 0
	for patch in patches:
		for surface in patch.mesh.get_surface_count():
			var arrays := patch.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var pixel_vertices := PackedVector2Array()
			for local in vertices:
				var point := patch.transform * local
				pixel_vertices.append((Vector2(point.x, point.z) - bounds.position) / bounds.size * Vector2(resolution))
			var is_tree := patch.name.begins_with("Ground_shade_tree_")
			var rectangle := patch.name.begins_with("Ground_shade_building_")
			for first in range(0, indices.size(), 3):
				_rasterize(data, resolution, pixel_vertices, uv, Vector3i(indices[first], indices[first + 1], indices[first + 2]), is_tree, rectangle)
			source_triangles += indices.size() / 3
	var image := Image.create_from_data(resolution.x, resolution.y, false, Image.FORMAT_RG8, data)
	image.generate_mipmaps()
	var contact := ImageTexture.create_from_image(image)
	contact.resource_name = "figueiras_ground_contact"
	for material in receivers:
		material.set_shader_parameter("has_ground_contact", true)
		material.set_shader_parameter("ground_contact", contact)
		material.set_shader_parameter("contact_bounds", Vector4(bounds.position.x, bounds.position.y, 1.0 / bounds.size.x, 1.0 / bounds.size.y))
	map.set_meta("ground_contact", {"size": resolution, "patches": patches.size(), "triangles": source_triangles})
	for patch in patches:
		patch.free()


static func _footprint(node: MeshInstance3D) -> Rect2:
	var bounds := node.transform * node.get_aabb()
	return Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)


static func _rasterize(data: PackedByteArray, size: Vector2i, vertices: PackedVector2Array,
		uv: PackedVector2Array, indices: Vector3i, is_tree: bool, rectangle: bool) -> void:
	var a := vertices[indices.x]
	var b := vertices[indices.y]
	var c := vertices[indices.z]
	var ab := b - a
	var ac := c - a
	var area := ab.cross(ac)
	if absf(area) < 0.00001:
		return
	var start := Vector2i(a.min(b).min(c).floor()).clamp(Vector2i.ZERO, size)
	var end := Vector2i(a.max(b).max(c).ceil()).clamp(Vector2i.ZERO, size)
	var origin_uv := uv[indices.x]
	var ab_uv := uv[indices.y] - origin_uv
	var ac_uv := uv[indices.z] - origin_uv
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			var ap := Vector2(x + 0.5, y + 0.5) - a
			var u := ap.cross(ac) / area
			var v := ab.cross(ap) / area
			if u < 0.0 or v < 0.0 or u + v > 1.0:
				continue
			var falloff := (origin_uv + ab_uv * u + ac_uv * v - Vector2(0.5, 0.5)) * 2.0
			var shade := 1.0 - (smoothstep(0.72, 1.0, maxf(absf(falloff.x), absf(falloff.y))) if rectangle
				else smoothstep(0.12, 1.0, falloff.length_squared()))
			var slot := (y * size.x + x) * 2 + int(is_tree)
			var strength := 0.22 if is_tree else 0.31
			data[slot] += roundi((255 - data[slot]) * shade * strength)
