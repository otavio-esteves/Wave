extends RefCounted

const Source = preload("res://scripts/city/pilot_foliage_lod.gd")
const SIZE := 42.0
const VARIANTS := [0, 3, 1, 5]


func bake(city: Node3D) -> void:
	var groups := {}
	for batch: MultiMeshInstance3D in city.find_children("*", "MultiMeshInstance3D", false, false):
		var label := str(batch.name)
		var crown := label.begins_with("canopy")
		if not crown and not label.begins_with("bark"):
			continue
		var material := batch.material_override as StandardMaterial3D
		var index := int(label[6 if crown else 4])
		var layer: int = VARIANTS[index] + (0 if crown else 7)
		var tile := Vector2i((Vector2(batch.position.x, batch.position.z) / SIZE).floor())
		if not groups.has(tile):
			groups[tile] = {"parts": [], "instances": 0}
		groups[tile].parts.append({"node": batch, "layer": layer, "tint": material.albedo_color})
		groups[tile].instances += batch.multimesh.instance_count
		batch.set_meta("foliage_cell", tile)
		batch.visibility_range_end = 0.0
		if crown:
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var atlas: Texture2D = load(Source.ATLAS_PATH)
	var material := ShaderMaterial.new()
	material.resource_name = "figueiras_tree_impostor"
	material.shader = Source.SHADER
	material.set_shader_parameter("foliage_atlas", atlas)
	material.set_shader_parameter("alpha_cutoff", 0.38)
	var mesh := Source._cross_cards()
	var distance_groups: Dictionary = {}
	for tile: Vector2i in groups:
		var record := _proxy(city, tile, groups[tile], mesh, material)
		var coarse := Vector2i((Vector2(tile) / 2.0).floor())
		if not distance_groups.has(coarse):
			distance_groups[coarse] = []
		distance_groups[coarse].append(record)
	var merged := 0
	for tile: Vector2i in distance_groups:
		if distance_groups[tile].size() > 1:
			_batch_distant_tiles(city, tile, distance_groups[tile], mesh, material)
			merged += 1
	city.set_meta("foliage_cells", groups.size())
	city.set_meta("foliage_distant_batches", merged)
	_bake_forest(city, mesh, material)


func _proxy(city: Node3D, tile: Vector2i, group: Dictionary, mesh: Mesh, material: Material) -> Dictionary:
	var data := PackedFloat32Array()
	data.resize(group.instances * Source.STRIDE)
	var origin := Vector3((tile.x + 0.5) * SIZE, group.parts[0].node.position.y, (tile.y + 0.5) * SIZE)
	var bounds := AABB()
	var index := 0
	for part: Dictionary in group.parts:
		var source: MultiMeshInstance3D = part.node
		var mesh_bounds := source.multimesh.mesh.get_aabb()
		var span := maxf(mesh_bounds.size.x, maxf(mesh_bounds.size.y, mesh_bounds.size.z)) * 1.12
		var card := Transform3D(Basis.from_scale(Vector3.ONE * span), mesh_bounds.get_center())
		var local := Transform3D(Basis.IDENTITY, source.position - origin)
		for placement: Transform3D in source.multimesh.instance_transforms:
			var pose := local * placement * card
			var box := pose * mesh.get_aabb()
			bounds = box if index == 0 else bounds.merge(box)
			Source._write_instance(data, index * Source.STRIDE, pose, part.tint, part.layer)
			index += 1
	var node := _make_batch(city, "FoliageDistance_%d_%d" % [tile.x, tile.y], origin, bounds, data, mesh, material)
	node.set_meta("foliage_cell", tile)
	node.set_meta("foliage_proxy", true)
	node.hide()
	return {"node": node, "buffer": data, "geometry": group.parts}


func _batch_distant_tiles(city: Node3D, tile: Vector2i, records: Array, mesh: Mesh, material: Material) -> void:
	var first: MultiMeshInstance3D = records[0].node
	var origin := first.position
	var buffer := PackedFloat32Array()
	var bounds := AABB()
	for record: Dictionary in records:
		var source: MultiMeshInstance3D = record.node
		var offset := source.position - origin
		var moved: PackedFloat32Array = record.buffer
		for index in range(0, moved.size(), Source.STRIDE):
			moved[index + 3] += offset.x
			moved[index + 7] += offset.y
			moved[index + 11] += offset.z
		buffer.append_array(moved)
		var piece := source.multimesh.custom_aabb
		piece.position += offset
		bounds = piece if source == first else bounds.merge(piece)
	var proxy := _make_batch(city, "FoliageDistant_%d_%d" % [tile.x, tile.y], origin, bounds, buffer, mesh, material)
	proxy.set_meta("foliage_distant", true)
	proxy.visibility_range_begin = 164.0
	proxy.visibility_range_begin_margin = 12.0
	for record: Dictionary in records:
		var path := NodePath("../" + proxy.name)
		record.node.visibility_parent = path
		for part: Dictionary in record.geometry:
			part.node.visibility_parent = path


func _bake_forest(city: Node3D, mesh: Mesh, material: Material) -> void:
	# The outer woods always use the atlas. Two original atlas parts share one
	# batch per forest tile and preserve an anchored trunk and varied crowns.
	var groups := {}
	for marker: MultiMeshInstance3D in city.find_children("horizon_tree*", "MultiMeshInstance3D", false, false):
		var tile := Vector2i((Vector2(marker.position.x, marker.position.z) / 96.0).floor())
		if not groups.has(tile):
			groups[tile] = []
		groups[tile].append(marker)
	var tree_count := 0
	for tile: Vector2i in groups:
		var markers: Array = groups[tile]
		var origin: Vector3 = markers[0].position
		var bounds := AABB()
		var data := PackedFloat32Array()
		var count := 0
		for marker: MultiMeshInstance3D in markers:
			var start := count
			data.resize((count + marker.multimesh.instance_count) * 2 * Source.STRIDE)
			var local := Transform3D(Basis.IDENTITY, marker.position - origin)
			for placement: Transform3D in marker.multimesh.instance_transforms:
				var kind: int = VARIANTS[posmod(tile.x + tile.y + count, VARIANTS.size())]
				var pose := local * placement
				var trunk := pose * Transform3D(Basis.from_scale(Vector3(0.71, 0.69, 0.71)), Vector3(0, 0.315, 0))
				var crown := pose * Transform3D(Basis.from_scale(Vector3(1.08, 0.87, 1.08)), Vector3(0, 0.69, 0))
				var tint := Color("a6b29b").lerp(Color("d9d8b3"), 0.5 + 0.5 * sin(count * 2.3))
				Source._write_instance(data, count * 2 * Source.STRIDE, trunk, Color("9d947c"), kind + 7)
				Source._write_instance(data, (count * 2 + 1) * Source.STRIDE, crown, tint, kind)
				var box := (trunk * mesh.get_aabb()).merge(crown * mesh.get_aabb())
				bounds = box if count == 0 else bounds.merge(box)
				count += 1
			tree_count += count - start
			marker.free()
		_make_batch(city, "Forest_%d_%d" % [tile.x, tile.y], origin, bounds, data, mesh, material)
	city.set_meta("forest_impostors", tree_count)


func _make_batch(city: Node3D, label: String, origin: Vector3, bounds: AABB,
		data: PackedFloat32Array, mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.use_custom_data = true
	batch.mesh = mesh
	batch.instance_count = data.size() / Source.STRIDE
	batch.custom_aabb = bounds
	batch.buffer = data
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.position = origin
	node.multimesh = batch
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city.add_child(node)
	node.owner = city
	return node
