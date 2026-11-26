extends RefCounted

const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
const Ground = preload("res://scripts/city/figueiras_ground.gd")
const GROUND_SHADER = preload("res://assets/shaders/figueiras/sector_ground.gdshader")
const BUILDING_SECTOR := 96.0
const BUILDING_FINISHES := ["figueiras_architecture", "figueiras_matte", "roof", "roof_gray", "stone"]
const PAVEMENT_LAYERS := {"sidewalk": 0.0, "curb": 1.0, "cobbles": 2.0, "paving": 3.0}


class Batch:
	var origin: Vector3
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var finishes := PackedFloat32Array()
	var indices := PackedInt32Array()
	var distant_indices := PackedInt32Array()

	func _init(center: Vector3) -> void:
		origin = center

	func append(arrays: Array, tiers: Array[PackedInt32Array], pose: Transform3D,
			color: Color, use_colors: bool, kind: int, layer: float, baked_pavement: bool) -> void:
		pose.origin -= origin
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var directions: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_colors: Variant = arrays[Mesh.ARRAY_COLOR]
		var source_uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
		var source_uv2: Variant = arrays[Mesh.ARRAY_TEX_UV2]
		var source_layers: Variant = arrays[Mesh.ARRAY_CUSTOM0]
		var normal_basis := pose.basis.inverse().transposed()
		var remap := PackedInt32Array()
		remap.resize(points.size())
		remap.fill(-1)
		for level in tiers.size():
			var remapped := PackedInt32Array()
			remapped.resize(tiers[level].size())
			var offset := 0
			for index in tiers[level]:
				if remap[index] < 0:
					remap[index] = positions.size()
					positions.append(pose * points[index])
					normals.append((normal_basis * directions[index]).normalized())
					colors.append(color * source_colors[index] if use_colors and source_colors != null else color)
					if kind >= 0:
						uv.append(source_uv[index])
						uv2.append(source_uv2[index])
						finishes.append(float(kind))
						finishes.append(source_layers[index] if baked_pavement else layer)
				remapped[offset] = remap[index]
				offset += 1
			if level == 0:
				indices.append_array(remapped)
			else:
				distant_indices.append_array(remapped)

	func make_mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var flags := 0
		if not finishes.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = uv
			arrays[Mesh.ARRAY_TEX_UV2] = uv2
			arrays[Mesh.ARRAY_CUSTOM0] = finishes
			flags = Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		var lods := {}
		if not distant_indices.is_empty() and distant_indices.size() < indices.size():
			# The renderer uses the coarser indices only when the sector's
			# projected size crosses this threshold.
			lods[0.52] = distant_indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods, flags)
		return mesh


static func bake(city: Node3D) -> void:
	if city.has_meta("sector_lod_counts"):
		return
	var ground: Dictionary[Vector2i, Array] = {}
	var buildings: Dictionary[Vector2i, Array] = {}
	var terrain_materials: Dictionary[String, ShaderMaterial] = {}
	var old_ground: Array[MeshInstance3D] = []
	for node in city.get_children():
		if not node is GeometryInstance3D or node.material_override == null:
			continue
		if node.has_meta("terrain_distant"):
			old_ground.append(node)
			continue
		if not node.visible or node.visibility_range_end > 0.0 or node.layers != 1 or node.material_overlay != null:
			continue
		var name: String = node.material_override.resource_name
		var mesh := _mesh(node)
		if mesh == null or mesh.get_surface_count() != 1:
			continue
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		if node is MeshInstance3D and node.name.begins_with("Ground_") and name.begins_with("figueiras_surface_"):
			var role := name.trim_prefix("figueiras_surface_")
			if role in ["asphalt", "grass", "white", "pavement"] or PAVEMENT_LAYERS.has(role):
				terrain_materials[role] = node.material_override
				_append(ground, node, Ground.SECTOR_SIZE)
		elif node.has_meta("masonry_lod") or (node.visibility_parent.is_empty() and node.visibility_range_begin == 0.0
			and (name in BUILDING_FINISHES or name.begins_with("figueiras_wall_"))):
			_append(buildings, node, BUILDING_SECTOR)
	var ground_batches := 0
	if terrain_materials.has_all(["asphalt", "grass", "pavement"]):
		ground_batches = _bake_ground(city, ground, terrain_materials)
		for node in old_ground:
			node.free()
		city.set_meta("terrain_distant_batches", ground_batches)
	var building_batches := _bake_buildings(city, buildings)
	for node in city.get_children():
		if node.has_meta("architecture_sector_indices"):
			node.remove_meta("architecture_sector_indices")
	city.set_meta("sector_lod_counts", Vector2i(ground_batches, building_batches))


static func _mesh(node: GeometryInstance3D) -> Mesh:
	if node is MeshInstance3D:
		return node.mesh
	if node is MultiMeshInstance3D and node.multimesh is BakedMultiMesh and node.multimesh.visible_instance_count == -1:
		return node.multimesh.mesh
	return null


static func _append(groups: Dictionary[Vector2i, Array], node: GeometryInstance3D, size: float) -> void:
	var tile := Vector2i((Vector2(node.position.x, node.position.z) / size).floor())
	if not groups.has(tile):
		groups[tile] = []
	groups[tile].append(node)


static func _bake_ground(city: Node3D, groups: Dictionary[Vector2i, Array], finishes: Dictionary[String, ShaderMaterial]) -> int:
	var finish := ShaderMaterial.new()
	finish.shader = GROUND_SHADER
	finish.resource_name = "figueiras_surface_sector"
	finish.set_shader_parameter("surface_kind", -1)
	var asphalt := finishes["asphalt"]
	for parameter in [&"base_color", &"tint", &"avenue_section", &"has_ground_contact", &"ground_contact", &"contact_bounds"]:
		finish.set_shader_parameter(parameter, asphalt.get_shader_parameter(parameter))
	finish.set_shader_parameter("meadow_albedo", finishes["grass"].get_shader_parameter("base_color"))
	for parameter in [&"pavement_albedo", &"pavement_tints"]:
		finish.set_shader_parameter(parameter, finishes["pavement"].get_shader_parameter(parameter))
	var sectors: Array = []
	var grass_only: Dictionary[Vector2i, Array] = {}
	for tile: Vector2i in groups:
		var members: Array = groups[tile]
		if members.size() == 1 and members[0].material_override.resource_name == "figueiras_surface_grass":
			var outer_tile := Vector2i((Vector2(tile) * 0.5).floor())
			if not grass_only.has(outer_tile):
				grass_only[outer_tile] = []
			grass_only[outer_tile].append(members[0])
		else:
			sectors.append(members)
	sectors.append_array(grass_only.values())
	for index in sectors.size():
		var members: Array = sectors[index]
		var batch := Batch.new(members[0].position)
		for node: MeshInstance3D in members:
			var role: String = node.material_override.resource_name.trim_prefix("figueiras_surface_")
			var kind: int = node.material_override.get_shader_parameter("surface_kind")
			# Paint and architectural trim already have representations for
			# distant views. Keep the stricter tolerances on the driven surface.
			var error := 0.76 if kind == 5 else (INF if kind == 2 else 0.24)
			var distant_error := 1.8 if kind == 5 else (INF if kind == 2 else 0.73)
			var arrays := node.mesh.surface_get_arrays(0)
			var shape := _ground_shape(arrays, kind, role == "pavement")
			batch.append(arrays, _index_tiers(node.mesh, arrays, error, distant_error, shape), node.transform, Color.WHITE, true,
				kind, PAVEMENT_LAYERS.get(role, 0.0), role == "pavement")
		var proxy := _install(city, batch, "Ground_SectorLOD_%d" % index, finish, &"terrain_sector_lod")
		proxy.set_meta("sector_source_count", members.size())
		for node: MeshInstance3D in members:
			node.visibility_parent = NodePath("../" + proxy.name)
	return sectors.size()


static func _ground_shape(source: Array, kind: int, layered: bool) -> ImporterMesh:
	if kind == 2 or source[Mesh.ARRAY_INDEX] == null or source[Mesh.ARRAY_INDEX].size() < 144:
		return null
	# The terrain indices can follow surface shape without inheriting the
	# dense shading tessellation. Lock boundaries by simplifying each finish
	# on its own and keep material seams in the simplifier's UV2 channel.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = source[Mesh.ARRAY_VERTEX]
	arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
	var normals := PackedVector3Array()
	normals.resize(source[Mesh.ARRAY_VERTEX].size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	if layered:
		var layers: PackedFloat32Array = source[Mesh.ARRAY_CUSTOM0]
		var seams := PackedVector2Array()
		seams.resize(layers.size())
		for index in layers.size():
			seams[index] = Vector2(layers[index], 0.0)
		arrays[Mesh.ARRAY_TEX_UV2] = seams
	elif kind == 0:
		arrays[Mesh.ARRAY_TEX_UV2] = source[Mesh.ARRAY_TEX_UV2]
	var mesh := ImporterMesh.new()
	mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.generate_lods(78.0, 0.0, [])
	return mesh


static func _bake_buildings(city: Node3D, groups: Dictionary[Vector2i, Array]) -> int:
	var finish := StandardMaterial3D.new()
	finish.resource_name = "figueiras_architecture"
	finish.vertex_color_use_as_albedo = true
	finish.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	finish.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var count := 0
	for tile: Vector2i in groups:
		var members: Array = groups[tile]
		if members.size() < 2:
			continue
		var batch := Batch.new(members[0].position)
		for node: GeometryInstance3D in members:
			var mesh := _mesh(node)
			var arrays := mesh.surface_get_arrays(0)
			# The mixed architecture meshes include sections of bridges,
			# guardrails and signposts. Keep the index changes small enough
			# to preserve those disconnected, narrow parts.
			var architecture := node.material_override.resource_name == "figueiras_architecture"
			var tiers: Array[PackedInt32Array] = []
			if node.has_meta("architecture_sector_indices") and node is MeshInstance3D:
				tiers.assign(node.get_meta("architecture_sector_indices"))
			else:
				tiers = _index_tiers(mesh, arrays, 0.04 if architecture else 0.18, 0.22 if architecture else 0.80)
			var paint := _building_paint(node.material_override)
			var vertex_color := _uses_vertex_color(node.material_override)
			if node is MultiMeshInstance3D:
				var instances: BakedMultiMesh = node.multimesh
				for index in instances.instance_transforms.size():
					var tint := paint * instances.instance_tints[index] if vertex_color and instances.use_colors else paint
					batch.append(arrays, tiers, node.transform * instances.instance_transforms[index], tint, vertex_color, -1, 0.0, false)
			else:
				batch.append(arrays, tiers, node.transform, paint, vertex_color, -1, 0.0, false)
		var proxy := _install(city, batch, "Building_SectorLOD_%d_%d" % [tile.x, tile.y], finish, &"building_sector_lod")
		proxy.set_meta("sector_source_count", members.size())
		for node: GeometryInstance3D in members:
			if node.has_meta("masonry_lod"):
				var facade := city.get_node_or_null(str(node.name).trim_prefix("Distant")) as MeshInstance3D
				if facade != null and facade.get_node_or_null(facade.visibility_parent) == node:
					facade.visibility_parent = NodePath("../" + proxy.name)
					node.free()
					continue
			node.visibility_parent = NodePath("../" + proxy.name)
		count += 1
	return count


static func _building_paint(material: Material) -> Color:
	if material is ShaderMaterial:
		var color: Color = Color.WHITE if material.get_shader_parameter("instance_tint") else material.get_shader_parameter("wall_color")
		return color * Color(0.80, 0.79, 0.76)
	var surface := material as StandardMaterial3D
	var base := surface.albedo_color
	if surface.resource_name in ["roof", "roof_gray"]:
		return base * Color(0.71, 0.63, 0.58)
	if surface.resource_name == "stone":
		return base * Color(0.78, 0.75, 0.69)
	return base


static func _uses_vertex_color(material: Material) -> bool:
	if material is ShaderMaterial:
		return material.get_shader_parameter("instance_tint") == true
	return (material as StandardMaterial3D).vertex_color_use_as_albedo


static func _index_tiers(mesh: Mesh, arrays: Array, maximum_error: float, distant_error: float, shape: ImporterMesh = null) -> Array[PackedInt32Array]:
	var base := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		base = arrays[Mesh.ARRAY_INDEX]
	if base.is_empty():
		base.resize(arrays[Mesh.ARRAY_VERTEX].size())
		for index in base.size():
			base[index] = index
	var distant := base
	var sources: Array[ImporterMesh] = []
	if mesh is ArrayMesh and base.size() >= 144:
		sources.append(ImporterMesh.from_mesh(mesh))
	if shape != null:
		sources.append(shape)
	for imported in sources:
		for level in imported.get_surface_lod_count(0):
			var error := imported.get_surface_lod_size(0, level)
			if error <= distant_error:
				var indices := imported.get_surface_lod_indices(0, level)
				if indices.size() < distant.size():
					distant = indices
				if error <= maximum_error and indices.size() < base.size():
					base = indices
	return [base, distant]


static func _install(city: Node3D, batch: Batch, label: String, finish: Material, tag: StringName) -> MeshInstance3D:
	var proxy := MeshInstance3D.new()
	proxy.name = label
	proxy.position = batch.origin
	proxy.mesh = batch.make_mesh()
	proxy.material_override = finish
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy.visibility_range_begin_margin = 8.0
	proxy.set_meta(tag, true)
	proxy.hide()
	city.add_child(proxy)
	proxy.owner = city
	return proxy
