extends Node3D

# Preserve tower setbacks, roofs, antennae and occupied windows at distance.
# Nearby batches use the full authored facade; no geometry/collision is deleted.
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
const ProxyPalette = preload("res://scripts/city/pilot_proxy_palette.gd")
const DETAIL_RADIUS := 340.0
const RETAIN_RADIUS := 420.0
const PROXY_TILE := 512.0
const HOUSE_DETAIL_RADIUS := 240.0
const HOUSE_RETAIN_RADIUS := 320.0
const HOUSE_PROXY_TILE := 256.0
const DETAIL_CELL := 128.0
const HOUSE_MATERIALS := ["ivory", "sage", "cream", "rose", "stone", "charcoal", "roof", "timber", "metal", "glass", "water_tank", "aged_plaster", "oxidized_metal", "residential_glass", "residential_glass_lit", "commercial_glass", "terracotta", "plaster", "blue"]
var target: PlayerCar
var groups: Array[Dictionary] = []
var proxies: Dictionary = {}
var economy_enabled := false
var total_detail_instances := 0
var total_proxy_instances := 0
var active_detail_batches := 0
var _timer := 0.0
var _last_position := Vector3.INF
var _initialized := false
var _groups_built := false
var _cells: Dictionary = {"tower": {}, "house": {}}
var _active_ids: Dictionary = {}
var last_refresh_candidates := 0
var _detail_scale := 1.0
var preparation_diagnostics: Dictionary = {}
var last_refresh_wall_ms := 0.0
var last_upload_bytes := 0
var _pending_upload_bytes := 0
var _authored_ranges_enabled := true


func _ready() -> void:
	var world := get_parent()
	target = world.get_node("PlayerCar")
	var city: Node3D = world.get_node("City")
	transform = city.transform
	target.car_reset.connect(refresh)
	var graphics: Dictionary = world.get_node("/root/WaveSettings").graphics
	set_render_profile(bool(graphics["city_lod"]), bool(graphics.get("city_detail_extended", false)))


func _build_groups() -> void:
	var started := Time.get_ticks_usec()
	_groups_built = true
	var city: Node3D = get_parent().get_node("City")
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var palette := ProxyPalette.new()
	var major_face_instances := 0
	for node in city.find_children("*", "MultiMeshInstance3D", true, false):
		var material := node.material_override as StandardMaterial3D
		if material == null:
			continue
		var source_mesh: Mesh = node.multimesh.mesh
		var tower := material.resource_name.begins_with("downtown") and source_mesh is BoxMesh
		var house := material.resource_name in HOUSE_MATERIALS and (source_mesh is BoxMesh or source_mesh is PrismMesh or source_mesh is QuadMesh)
		if not tower and not house:
			continue
		var local_transform: Transform3D = city.global_transform.affine_inverse() * node.global_transform
		var bounds: AABB = local_transform * node.multimesh.custom_aabb
		var rectangle := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		var tile_width := PROXY_TILE if tower else HOUSE_PROXY_TILE
		var tile := Vector2i(floori(rectangle.get_center().x / tile_width), floori(rectangle.get_center().y / tile_width))
		# Nearby parts always retain their authored material. Structural opaque
		# proxies bake reflectance into instance colours instead of splitting a
		# distant sector into one draw call for every stucco/roof/trim material.
		var mesh_key := "box" if source_mesh is BoxMesh else str(source_mesh.get_rid())
		var pane := source_mesh is QuadMesh
		var tint_policy := palette.prepare(material, pane)
		var base_key := "%s/%s/%s/%s" % ["tower" if tower else "house", tile, mesh_key, palette.key(material, pane)]
		# Downtown proxies carry the skyline across districts. Apply the authored
		# cutoff to residential detail without thinning distant silhouettes.
		var range_end: float = 0.0 if tower else node.visibility_range_end
		var range_margin: float = node.visibility_range_end_margin
		if range_end > 0.0:
			base_key += "/range/%s/%s" % [range_end, range_margin]
		var placements: Array[Transform3D] = []
		var thin_placements: Array[Transform3D] = []
		var colours := PackedColorArray()
		var thin_colours := PackedColorArray()
		var mesh_size: Vector3 = source_mesh.get_aabb().size
		var authored: Array[Transform3D] = node.multimesh.instance_transforms
		var tints: PackedColorArray = node.multimesh.instance_tints
		var can_flatten := source_mesh is BoxMesh and not bool(tint_policy.preserve)
		for index in authored.size():
			var placement := authored[index]
			var size := Vector3(placement.basis.x.length(), placement.basis.y.length(), placement.basis.z.length()) * mesh_size
			var structural := _structural(size, material.resource_name) if tower else _house_structural(size, source_mesh is QuadMesh)
			if not structural or not node.visible:
				continue
			if source_mesh is BoxMesh:
				placement.basis *= Basis.from_scale(mesh_size)
			var tint := ProxyPalette.tint_prepared(tint_policy, tints[index] if index < tints.size() else Color.WHITE)
			var axis := size.min_axis_index()
			var thin := can_flatten and size[axis] <= 0.4 and size[axis] <= size[size.max_axis_index()] * 0.2
			if thin:
				# Reorient a shared Z-face pair to the original thin axis. Both
				# major faces stay at their authored depths, including roof slabs.
				if axis == 0:
					placement.basis *= Basis(Vector3.UP, PI * 0.5)
				elif axis == 1:
					placement.basis *= Basis(Vector3.RIGHT, -PI * 0.5)
				thin_placements.append(local_transform * placement)
				thin_colours.append(tint)
			else:
				placements.append(local_transform * placement)
				colours.append(tint)
		var detail_radius := DETAIL_RADIUS if tower else HOUSE_DETAIL_RADIUS
		var retain_radius := RETAIN_RADIUS if tower else HOUSE_RETAIN_RADIUS
		# A source has one visibility/hysteresis record even when its proxy
		# geometry uses two meshes. Only entries refer back to this record;
		# the record stores key strings, avoiding reference cycles.
		var record := {"node": node, "bounds": rectangle, "aabb": bounds, "active": true, "authored_visible": node.visible, "offset": 0, "count": placements.size() + thin_placements.size(), "proxy_key": "", "proxy_keys": [], "base_detail_radius": detail_radius, "base_retain_radius": retain_radius, "detail_radius": detail_radius * _detail_scale, "retain_radius": retain_radius * _detail_scale}
		for flat in [false, true]:
			var segment_placements: Array[Transform3D] = thin_placements if flat else placements
			if segment_placements.is_empty():
				continue
			var key := base_key + ("/major_faces" if flat else "")
			if not proxies.has(key):
				var batch := MultiMeshInstance3D.new()
				batch.name = "FarBuilding_%d" % proxies.size()
				batch.multimesh = MultiMesh.new()
				batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
				batch.multimesh.use_colors = true
				batch.multimesh.mesh = load("res://scripts/city/pilot_proxy_planes.gd").mesh(2, material.cull_mode) if flat else (cube if source_mesh is BoxMesh else source_mesh)
				batch.material_override = palette.material(material, pane)
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				batch.visibility_range_end_margin = range_margin if range_end > 0.0 else 0.0
				batch.visible = false
				add_child(batch)
				proxies[key] = {"node": batch, "range_end": range_end, "members": [], "buffer": PackedFloat32Array(), "source_buffer": PackedFloat32Array(), "source_bounds": AABB()}
			var source_data: PackedFloat32Array = proxies[key].source_buffer
			var offset := source_data.size()
			source_data.append_array(BakedMultiMesh.make_buffer(segment_placements, thin_colours if flat else colours))
			proxies[key].source_buffer = source_data
			proxies[key].source_bounds = proxies[key].source_bounds.merge(bounds) if offset > 0 else bounds
			proxies[key].members.append({"group": record, "offset": offset, "count": segment_placements.size(), "aabb": bounds})
			record.proxy_keys.append(key)
			if record.proxy_key.is_empty():
				record.proxy_key = key
				record.offset = offset
		_index_record(rectangle, groups.size(), tower)
		groups.append(record)
		total_detail_instances += authored.size()
		total_proxy_instances += record.count
		major_face_instances += thin_placements.size()
	preparation_diagnostics = palette.diagnostics()
	preparation_diagnostics["build_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	preparation_diagnostics["detail_groups"] = groups.size()
	preparation_diagnostics["proxy_groups"] = proxies.size()
	preparation_diagnostics["major_face_instances"] = major_face_instances
	preparation_diagnostics["major_face_triangles"] = major_face_instances * 4


static func _structural(size: Vector3, material_name: String) -> bool:
	if material_name == "downtown_window":
		return true
	if material_name == "downtown_copper" and size.y >= 8.0:
		return true
	return size.x >= 5.0 and size.z >= 5.0 and (size.y >= 2.0 or absf(size.y - 0.3) < 0.02)


static func _material_key(material: StandardMaterial3D) -> String:
	return preload("res://scripts/city/pilot_resource_pool.gd").new().fingerprint(material)


static func _house_structural(size: Vector3, pane: bool) -> bool:
	# Keep authored walls, pitched roofs, doors and window panes. Small rails,
	# trim and domestic ornaments are subpixel at the Economy detail boundary.
	if pane:
		return true
	var broad_axes := int(size.x >= 0.8) + int(size.y >= 0.8) + int(size.z >= 0.8)
	return broad_axes >= 2


func set_economy_enabled(enabled: bool) -> void:
	if enabled and not _groups_built:
		_build_groups()
	if _initialized and economy_enabled == enabled:
		return
	_initialized = true
	if enabled and not economy_enabled:
		for record in groups:
			record.active = false
	economy_enabled = enabled
	refresh(true)


func set_render_profile(enabled: bool, extended_detail: bool) -> void:
	# Geometry distance is independent of texture/normal-map detail, and the
	# master preference remains authoritative when the player restores authorship.
	var scale := 1.6 if extended_detail else 1.0
	var changed := not is_equal_approx(scale, _detail_scale)
	_detail_scale = scale
	if changed:
		for record in groups:
			record.detail_radius = record.base_detail_radius * scale
			record.retain_radius = record.base_retain_radius * scale
	var was_enabled := economy_enabled
	set_economy_enabled(enabled)
	if changed and was_enabled and economy_enabled:
		refresh(true)


func set_authored_ranges_enabled(enabled: bool) -> void:
	if _authored_ranges_enabled == enabled:
		return
	_authored_ranges_enabled = enabled
	for entry in proxies.values():
		_update_proxy_range(entry, entry.node.multimesh.custom_aabb)


func _physics_process(delta: float) -> void:
	if not economy_enabled:
		return
	_timer += delta
	if _timer >= 0.25:
		_timer = 0.0
		if target.global_position.distance_squared_to(_last_position) > 16.0 * 16.0:
			refresh()


func refresh(force: bool = false) -> void:
	if not economy_enabled and not force:
		return
	var started := Time.get_ticks_usec()
	_pending_upload_bytes = 0
	_last_position = target.global_position
	var local_position := to_local(_last_position)
	var point := Vector2(local_position.x, local_position.z)
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
		var closest := point.clamp(bounds.position, bounds.end)
		var radius: float = record.retain_radius if record.active else record.detail_radius
		var wanted := not economy_enabled or point.distance_squared_to(closest) <= radius * radius
		var visible: bool = wanted and record.authored_visible
		if record.node.visible != visible:
			record.node.visible = visible
		if force or wanted != record.active:
			for key in record.proxy_keys:
				dirty[key] = true
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


func _index_record(bounds: Rect2, id: int, tower: bool) -> void:
	var cells: Dictionary = _cells["tower" if tower else "house"]
	for x in range(floori(bounds.position.x / DETAIL_CELL), floori(bounds.end.x / DETAIL_CELL) + 1):
		for z in range(floori(bounds.position.y / DETAIL_CELL), floori(bounds.end.y / DETAIL_CELL) + 1):
			var tile := Vector2i(x, z)
			if not cells.has(tile):
				cells[tile] = []
			cells[tile].append(id)


func _nearby_ids(point: Vector2) -> Array:
	# Previously active groups must leave through the retention radius even
	# after a reset/teleport skips cells. Far inactive groups need no polling.
	var candidates := _active_ids.duplicate()
	for kind in ["tower", "house"]:
		# New groups only enter through their detail radius. Previously active
		# groups are already in candidates and use their larger retention radius.
		var radius := (DETAIL_RADIUS if kind == "tower" else HOUSE_DETAIL_RADIUS) * _detail_scale
		var cells: Dictionary = _cells[kind]
		for x in range(floori((point.x - radius) / DETAIL_CELL), floori((point.x + radius) / DETAIL_CELL) + 1):
			for z in range(floori((point.y - radius) / DETAIL_CELL), floori((point.y + radius) / DETAIL_CELL) + 1):
				for id in cells.get(Vector2i(x, z), []):
					candidates[id] = true
	return candidates.keys()


func _rebuild_proxy(entry: Dictionary) -> void:
	var data := PackedFloat32Array()
	var bounds := AABB()
	var has_bounds := false
	if economy_enabled:
		var partial := false
		for segment in entry.members:
			if segment.group.active and segment.count > 0:
				partial = true
		if not partial:
			# Most sectors are entirely distant: share their immutable packed data
			# instead of retaining another complete copy of the distant city.
			data = entry.source_buffer
			bounds = entry.source_bounds
		else:
			for segment in entry.members:
				if not segment.group.active and segment.count > 0:
					data.append_array(entry.source_buffer.slice(segment.offset, segment.offset + segment.count * 16))
					bounds = bounds.merge(segment.aabb) if has_bounds else segment.aabb
					has_bounds = true
	entry.node.visible = not data.is_empty()
	# Only sectors whose near/far membership changed are uploaded again.
	entry.buffer = data
	var multimesh: MultiMesh = entry.node.multimesh
	var count := data.size() / 16
	if multimesh.instance_count != count:
		multimesh.instance_count = count
	multimesh.custom_aabb = bounds
	_update_proxy_range(entry, bounds)
	if count > 0 and DisplayServer.get_name() != "headless":
		multimesh.buffer = data
		_pending_upload_bytes += data.size() * 4


func _update_proxy_range(entry: Dictionary, bounds: AABB) -> void:
	if entry.range_end <= 0.0:
		return
	# Godot measures from the combined AABB center. Its enclosing radius
	# keeps each source eligible at its own authored distance.
	var world_extent := (global_transform * bounds).size
	entry.node.visibility_range_end = entry.range_end + world_extent.length() * 0.5 if _authored_ranges_enabled else 0.0


static func unpack_transform(data: PackedFloat32Array, index: int) -> Transform3D:
	var at := index * 16
	return Transform3D(Basis(Vector3(data[at], data[at + 4], data[at + 8]), Vector3(data[at + 1], data[at + 5], data[at + 9]), Vector3(data[at + 2], data[at + 6], data[at + 10])), Vector3(data[at + 3], data[at + 7], data[at + 11]))
