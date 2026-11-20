extends Node3D

# Far foliage uses two views of the exact source canopy/shrub/trunk. Each part
# retains its own pivot, scale and rotation; no assumption about one leaf batch
# corresponding to one complete tree is needed.
const ATLAS_PATH := "res://assets/textures/pilot/foliage-impostors.res"
const SHADER := preload("res://assets/shaders/pilot_foliage_impostor.gdshader")
const DETAIL_RADIUS := 200.0
const RETAIN_RADIUS := 260.0
const CELL := 128.0
const PROXY_TILE := 512.0
const STRIDE := 20
var target: PlayerCar
var atlas: Texture2D
# Alternate domains are created only by the profiling harness. The playable
# world still creates the original foliage domain with these unchanged defaults.
var domain := "foliage"
var detail_radius := DETAIL_RADIUS
var retain_radius := RETAIN_RADIUS
var alpha_cutoff := 0.35
var groups: Array[Dictionary] = []
var proxies: Dictionary = {}
var enabled := false
var total_instances := 0
var active_detail_batches := 0
var last_refresh_candidates := 0
var _cells: Dictionary = {}
var _active_ids: Dictionary = {}
var _built := false
var _initialized := false
var _detail_scale := 1.0
var _last_position := Vector3.INF
var _timer := 0.0
var _canopy_visible := true
var preparation_ms := 0.0
var last_refresh_wall_ms := 0.0
var last_upload_bytes := 0
var _pending_upload_bytes := 0


func _ready() -> void:
	var world := get_parent()
	target = world.get_node("PlayerCar")
	transform = world.get_node("City").transform
	target.car_reset.connect(refresh)
	var graphics: Dictionary = world.get_node("/root/WaveSettings").graphics
	set_render_profile(bool(graphics["city_lod"]), bool(graphics.get("city_detail_extended", false)))


func set_render_profile(wanted: bool, extended_detail: bool) -> void:
	var scale := 1.6 if extended_detail else 1.0
	var changed := not is_equal_approx(_detail_scale, scale)
	_detail_scale = scale
	if wanted and not _built:
		_build_groups()
		if not _built:
			return
	if _initialized and enabled == wanted and not changed:
		return
	_initialized = true
	if wanted and not enabled:
		# Only groups selected during a previous active refresh may use the
		# retention radius. Cold entry and a re-enabled profile use entry range.
		for record in groups:
			record.active = false
	enabled = wanted
	refresh(true)


func _build_groups() -> void:
	var started := Time.get_ticks_usec()
	if atlas == null:
		atlas = load(ATLAS_PATH) as Texture2D
	if not atlas_supports_domain():
		push_error("Foliage HLOD requires its baked source atlas")
		return
	_built = true
	var city: Node3D = get_parent().get_node("City")
	var inverse := city.global_transform.affine_inverse()
	var card := _cross_cards()
	var material_cache: Dictionary = {}
	for node in city.find_children("*", "MultiMeshInstance3D", true, false):
		var material := node.material_override as StandardMaterial3D
		var kind := domain_source_layer(str(node.name), material)
		if kind < 0:
			continue
		var canopy := domain == "blossoms" or material.resource_name == "tree_leaves"
		var local_transform: Transform3D = inverse * node.global_transform
		var bounds: AABB = local_transform * node.multimesh.custom_aabb
		var rectangle := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		var tile := Vector2i(floori(rectangle.get_center().x / PROXY_TILE), floori(rectangle.get_center().y / PROXY_TILE))
		var key := "%s/%s/%s" % [tile, material.get_instance_id(), node.layers]
		if not material_cache.has(material):
			var proxy_material := ShaderMaterial.new()
			proxy_material.resource_name = "FoliageImpostor_" + material.resource_name
			proxy_material.shader = SHADER
			proxy_material.set_shader_parameter("foliage_atlas", atlas)
			proxy_material.set_shader_parameter("albedo_modulate", material.albedo_color)
			proxy_material.set_shader_parameter("alpha_cutoff", alpha_cutoff)
			material_cache[material] = proxy_material
		if not proxies.has(key):
			var batch := MultiMeshInstance3D.new()
			batch.name = "FarFoliage_%d" % proxies.size()
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.use_colors = true
			batch.multimesh.use_custom_data = true
			batch.multimesh.mesh = card
			batch.material_override = material_cache[material]
			batch.layers = node.layers
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visible = false
			add_child(batch)
			proxies[key] = {"node": batch, "members": [], "source_buffer": PackedFloat32Array(), "source_bounds": AABB(), "buffer": PackedFloat32Array(), "source_material": material, "canopy": canopy}
		var source_bounds: AABB = node.multimesh.mesh.get_aabb()
		var span := maxf(source_bounds.size.x, maxf(source_bounds.size.y, source_bounds.size.z)) * 1.12
		var card_local := Transform3D(Basis.from_scale(Vector3.ONE * span), source_bounds.get_center())
		var placements: Array[Transform3D] = node.multimesh.instance_transforms
		var tints: PackedColorArray = node.multimesh.instance_tints
		var use_instance_tint := material.vertex_color_use_as_albedo
		var data := PackedFloat32Array()
		var card_bounds := AABB()
		var count := placements.size() if node.visible else 0
		data.resize(count * STRIDE)
		for index in count:
			var placement: Transform3D = local_transform * placements[index] * card_local
			var tint: Color = tints[index] if use_instance_tint and index < tints.size() else Color.WHITE
			_write_instance(data, index * STRIDE, placement, tint, kind)
			var aabb := placement * card.get_aabb()
			card_bounds = aabb if index == 0 else card_bounds.merge(aabb)
		var source_data: PackedFloat32Array = proxies[key].source_buffer
		var offset := source_data.size()
		source_data.append_array(data)
		proxies[key].source_buffer = source_data
		proxies[key].source_bounds = card_bounds if offset == 0 else proxies[key].source_bounds.merge(card_bounds)
		var record := {"node": node, "bounds": rectangle, "aabb": card_bounds, "active": true, "authored_visible": node.visible, "offset": offset, "count": count, "proxy_key": key, "canopy": canopy, "source_centre": bounds.get_center(), "source_end": node.visibility_range_end}
		_index_record(rectangle, groups.size())
		groups.append(record)
		proxies[key].members.append(record)
		total_instances += count
	preparation_ms = (Time.get_ticks_usec() - started) / 1000.0


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_timer += delta
	if _timer >= 0.25:
		_timer = 0.0
		if target.global_position.distance_squared_to(_last_position) > 16.0 * 16.0:
			refresh()


func refresh(force: bool = false) -> void:
	if not _built or not enabled and not force:
		return
	var started := Time.get_ticks_usec()
	_pending_upload_bytes = 0
	_last_position = target.global_position
	var local := to_local(_last_position)
	var point := Vector2(local.x, local.z)
	var dirty: Dictionary = {}
	var candidates: Array
	if force:
		candidates = range(groups.size())
		_active_ids.clear()
		active_detail_batches = 0
	else:
		candidates = _nearby_ids(point)
	last_refresh_candidates = candidates.size()
	for id: int in candidates:
		var record: Dictionary = groups[id]
		var bounds: Rect2 = record.bounds
		var radius := (retain_radius if record.active else detail_radius) * _detail_scale
		var wanted := not enabled or point.distance_squared_to(point.clamp(bounds.position, bounds.end)) <= radius * radius
		record.node.visible = wanted and record.authored_visible and (_canopy_visible or not record.canopy)
		if force or wanted != record.active:
			dirty[record.proxy_key] = true
			active_detail_batches += int(wanted) if force else (1 if wanted else -1)
		record.active = wanted
		if wanted:
			_active_ids[id] = true
		else:
			_active_ids.erase(id)
	for key in dirty:
		_rebuild_proxy(proxies[key])
	last_upload_bytes = _pending_upload_bytes
	last_refresh_wall_ms = (Time.get_ticks_usec() - started) / 1000.0


func _index_record(bounds: Rect2, id: int) -> void:
	for x in range(floori(bounds.position.x / CELL), floori(bounds.end.x / CELL) + 1):
		for z in range(floori(bounds.position.y / CELL), floori(bounds.end.y / CELL) + 1):
			var tile := Vector2i(x, z)
			if not _cells.has(tile):
				_cells[tile] = []
			_cells[tile].append(id)


func _nearby_ids(point: Vector2) -> Array:
	var candidates := _active_ids.duplicate()
	var radius := detail_radius * _detail_scale
	for x in range(floori((point.x - radius) / CELL), floori((point.x + radius) / CELL) + 1):
		for z in range(floori((point.y - radius) / CELL), floori((point.y + radius) / CELL) + 1):
			for id in _cells.get(Vector2i(x, z), []):
				candidates[id] = true
	return candidates.keys()


func _rebuild_proxy(entry: Dictionary) -> void:
	var data := PackedFloat32Array()
	var bounds := AABB()
	var has_bounds := false
	if enabled:
		var partial := false
		for record in entry.members:
			if record.active and record.count > 0:
				partial = true
		if not partial:
			data = entry.source_buffer
			bounds = entry.source_bounds
		else:
			for record in entry.members:
				if not record.active and record.count > 0:
					data.append_array(entry.source_buffer.slice(record.offset, record.offset + record.count * STRIDE))
					bounds = bounds.merge(record.aabb) if has_bounds else record.aabb
					has_bounds = true
	entry.node.visible = not data.is_empty() and (_canopy_visible or not entry.canopy)
	entry.buffer = data
	entry.node.multimesh.instance_count = data.size() / STRIDE
	entry.node.multimesh.custom_aabb = bounds
	# Preserve the eligibility of the original source ranges without drawing
	# an unlimited forest beyond them. Allow for the changed batch centre.
	var centre: Vector3 = global_transform * bounds.get_center()
	var end := 0.0
	for record in entry.members:
		end = INF if record.source_end == 0.0 else maxf(end, record.source_end + centre.distance_to(global_transform * record.source_centre))
	entry.node.visibility_range_end = 0.0 if is_inf(end) else end
	entry.node.material_override.set_shader_parameter("albedo_modulate", entry.source_material.albedo_color)
	if not data.is_empty() and DisplayServer.get_name() != "headless":
		entry.node.multimesh.buffer = data
		_pending_upload_bytes += data.size() * 4


func set_canopy_visible(value: bool) -> void:
	# Diagnostic ablations remove canopies in both representations. Trunk
	# geometry/cards stay present, matching the original no-foliage experiment.
	_canopy_visible = value
	for record in groups:
		if record.canopy:
			record.node.visible = record.active and record.authored_visible and value
	for entry in proxies.values():
		if entry.canopy:
			entry.node.visible = value and not entry.buffer.is_empty()


func snapshot() -> Dictionary:
	var proxy_instances := 0
	var proxy_batches := 0
	for entry in proxies.values():
		if entry.node.visible:
			proxy_batches += 1
			proxy_instances += entry.node.multimesh.instance_count
	return {"domain": domain, "enabled": enabled, "source_batches": groups.size(), "source_instances": total_instances, "active_detail_batches": active_detail_batches, "proxy_batches": proxy_batches, "proxy_instances": proxy_instances, "proxy_triangles": proxy_instances * 4, "detail_radius": detail_radius * _detail_scale, "retain_radius": retain_radius * _detail_scale, "alpha_cutoff": alpha_cutoff, "last_refresh_candidates": last_refresh_candidates, "preparation_ms": preparation_ms, "last_refresh_wall_ms": last_refresh_wall_ms, "last_upload_bytes": last_upload_bytes}


func atlas_supports_domain() -> bool:
	if atlas == null:
		return false
	if domain != "blossoms":
		return true
	var layers: Array = atlas.get_meta("layers", [])
	return int(atlas.get_meta("layer_count", 0)) >= 14 and layers.size() >= 14 and layers[13].get("kind", "") == "flower_cluster" and 13 in atlas.get_meta("nonempty_layers", [])


func domain_source_layer(node_name: String, material: StandardMaterial3D) -> int:
	if material == null:
		return -1
	if domain == "blossoms":
		return 13 if node_name.begins_with("flower_cluster_") and material.resource_name in ["blossom_gold", "blossom_violet"] else -1
	return source_layer(node_name) if material.resource_name in ["tree_leaves", "tree_bark"] else -1


func restore_original_sources() -> void:
	for record in groups:
		if is_instance_valid(record.node):
			record.node.visible = record.authored_visible


func _exit_tree() -> void:
	if domain == "blossoms":
		restore_original_sources()


static func source_layer(node_name: String) -> int:
	if node_name.begins_with("shrub_"):
		return 6
	for variant in 6:
		if node_name.begins_with("tree_leaves%d_" % variant):
			return variant
		if node_name.begins_with("tree_bark%d_" % variant):
			return 7 + variant
	return -1


static func _write_instance(data: PackedFloat32Array, offset: int, placement: Transform3D, tint: Color, layer: int) -> void:
	for row in 3:
		data[offset + row * 4] = placement.basis.x[row]
		data[offset + row * 4 + 1] = placement.basis.y[row]
		data[offset + row * 4 + 2] = placement.basis.z[row]
		data[offset + row * 4 + 3] = placement.origin[row]
	data[offset + 12] = tint.r
	data[offset + 13] = tint.g
	data[offset + 14] = tint.b
	data[offset + 15] = tint.a
	data[offset + 16] = layer


static func _cross_cards() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for view in 2:
		var basis := Basis(Vector3.UP, view * PI / 2)
		var points := [Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0), Vector3(0.5, -0.5, 0), Vector3(-0.5, -0.5, 0)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for index in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(basis * Vector3.BACK)
			tool.set_uv(uvs[index])
			tool.set_uv2(Vector2(view, 0))
			tool.add_vertex(basis * points[index])
	tool.index()
	return tool.commit()
