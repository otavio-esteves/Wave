extends RefCounted

const Ground = preload("res://scripts/city/figueiras_ground.gd")
const MeshLods = preload("res://scripts/tools/bake_mesh_lods.gd")
const SHADER = preload("res://assets/shaders/figueiras/pavement_finish.gdshader")
const FINISHES := ["sidewalk", "curb", "cobbles", "paving"]
const TEXTURE_LAYERS := ["paving", "limestone", "pavers"]
const TEXTURE_DIR := "res://assets/textures/neighborhood/"
const ALBEDO := "res://assets/textures/figueiras/pavement-albedo.res"
const NORMAL := "res://assets/textures/figueiras/pavement-normal.res"
const PREFIX := "figueiras_surface_"
# Each value is a maximum mesh simplification error in world metres.
const LOD_ERRORS := [0.008, 0.035, 0.14, 0.56, 2.24]
const ATTRIBUTES := [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]


static func bake_textures() -> Error:
	if DisplayServer.get_name() == "headless":
		push_error("Pavement texture arrays require a rendered session to serialize their layers")
		return ERR_UNAVAILABLE
	for channel: String in ["albedo", "normal"]:
		var images: Array[Image] = []
		for layer: String in TEXTURE_LAYERS:
			var texture: Texture2D = load(TEXTURE_DIR.path_join("%s-%s.res" % [layer, channel]))
			var image := texture.get_image()
			if image == null or image.is_empty():
				return ERR_CANT_ACQUIRE_RESOURCE
			images.append(image)
		var texture_array := Texture2DArray.new()
		var error := texture_array.create_from_images(images)
		if error != OK:
			return error
		error = ResourceSaver.save(texture_array, ALBEDO if channel == "albedo" else NORMAL, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			return error
	return OK


static func bake(city: Node3D) -> Error:
	var buckets := {}
	var finishes: Dictionary[int, ShaderMaterial] = {}
	for node in city.get_children():
		if not node is MeshInstance3D or not node.mesh is ArrayMesh or node.mesh.get_surface_count() != 1:
			continue
		if not node.visible or node.basis != Basis.IDENTITY or node.material_overlay != null:
			continue
		if not node.visibility_parent.is_empty() or node.visibility_range_begin > 0.0 or node.visibility_range_end > 0.0:
			continue
		var finish := node.material_override as ShaderMaterial
		if finish == null or not finish.resource_name.begins_with(PREFIX):
			continue
		var layer := FINISHES.find(finish.resource_name.trim_prefix(PREFIX))
		if layer < 0 or node.mesh.surface_get_array_index_len(0) == 0:
			continue
		finishes[layer] = finish
		var tile := Vector2i((Vector2(node.position.x, node.position.z) / Ground.SECTOR_SIZE).floor())
		var key := [tile, node.layers, node.cast_shadow, node.mesh.surface_get_format(0)]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append([node, layer])
	if finishes.is_empty():
		return OK
	var material := _material(finishes)
	if material == null:
		return ERR_CANT_ACQUIRE_RESOURCE
	var saved := int(city.get_meta("pavement_draws_saved", 0))
	for key: Array in buckets:
		var members: Array = buckets[key]
		if members.size() < 2:
			continue
		_join(city, key[0], members, material)
		saved += members.size() - 1
	city.set_meta("pavement_draws_saved", saved)
	return OK


static func _material(finishes: Dictionary[int, ShaderMaterial]) -> ShaderMaterial:
	var albedo := load(ALBEDO) as Texture2DArray
	var normal := load(NORMAL) as Texture2DArray
	if albedo == null or normal == null or albedo.get_layers() != 3 or normal.get_layers() != 3:
		return null
	var material := ShaderMaterial.new()
	material.resource_name = PREFIX + "pavement"
	material.shader = SHADER
	material.set_shader_parameter("surface_kind", 1)
	material.set_shader_parameter("pavement_albedo", albedo)
	material.set_shader_parameter("pavement_normal", normal)
	var tints := PackedColorArray()
	for layer in FINISHES.size():
		tints.append(finishes[layer].get_shader_parameter("tint") if finishes.has(layer) else Color.WHITE)
	material.set_shader_parameter("pavement_tints", tints)
	var original: ShaderMaterial = finishes.values()[0]
	for parameter: String in ["has_ground_contact", "ground_contact", "contact_bounds"]:
		material.set_shader_parameter(parameter, original.get_shader_parameter(parameter))
	return material


static func _join(city: Node3D, tile: Vector2i, members: Array, material: ShaderMaterial) -> void:
	var first: MeshInstance3D = members[0][0]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var layers := PackedFloat32Array()
	var levels := {}
	for error: float in LOD_ERRORS:
		levels[error] = PackedInt32Array()
	for member: Array in members:
		var node: MeshInstance3D = member[0]
		var imported := MeshLods.generate(node.mesh)
		var source := imported.get_surface_arrays(0)
		var lods := MeshLods.index_levels(imported, 0)
		var base: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var vertex_start := vertices.size()
		var offset := node.position - first.position
		for vertex: Vector3 in source[Mesh.ARRAY_VERTEX]:
			vertices.append(vertex + offset)
			layers.append(float(member[1]))
		indices.append_array(_offset_indices(base, vertex_start))
		for error: float in LOD_ERRORS:
			var best := base
			for level: float in lods:
				if level <= error and lods[level].size() < best.size():
					best = lods[level]
			var target: PackedInt32Array = levels[error]
			target.append_array(_offset_indices(best, vertex_start))
			levels[error] = target
		for channel: int in ATTRIBUTES:
			if source[channel] == null:
				continue
			if arrays[channel] == null:
				arrays[channel] = source[channel]
			else:
				var values: Variant = arrays[channel]
				values.append_array(source[channel])
				arrays[channel] = values
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_CUSTOM0] = layers
	var final_levels := {}
	var last := indices.size()
	for error: float in LOD_ERRORS:
		if levels[error].size() < last:
			final_levels[error] = levels[error]
			last = levels[error].size()
	var mesh := ArrayMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], final_levels, flags)
	var joined := MeshInstance3D.new()
	joined.name = "Ground_Pavement_%d_%d" % [tile.x, tile.y]
	joined.position = first.position
	joined.mesh = mesh
	joined.material_override = material
	joined.cast_shadow = first.cast_shadow
	joined.layers = first.layers
	if not final_levels.is_empty():
		joined.set_meta("terrain_lod", final_levels.size())
	city.add_child(joined, true)
	joined.owner = city
	for member: Array in members:
		member[0].free()


static func _offset_indices(source: PackedInt32Array, offset: int) -> PackedInt32Array:
	var output := source.duplicate()
	for index in output.size():
		output[index] += offset
	return output
