extends Node3D

# Preserve tower setbacks, roofs, antennae and occupied windows at distance.
# Nearby batches use the full authored facade; no geometry/collision is deleted.
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
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


func _ready() -> void:
	var world := get_parent()
	target = world.get_node("PlayerCar")
	var city: Node3D = world.get_node("City")
	transform = city.transform
	target.car_reset.connect(refresh)
	set_economy_enabled(bool(world.get_node("/root/WaveSettings").graphics["city_lod"]))


func _build_groups() -> void:
	_groups_built = true
	var city: Node3D = get_parent().get_node("City")
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var material_keys: Dictionary = {}
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
		# Sector serialization may duplicate equivalent materials. Merge only
		# matching facade properties, retaining their exact per-instance colours.
		var mesh_key := "box" if source_mesh is BoxMesh else str(source_mesh.get_rid())
		if not material_keys.has(material):
			material_keys[material] = _material_key(material)
		var key := "%s/%s/%s/%s" % ["tower" if tower else "house", tile, mesh_key, material_keys[material]]
		if not proxies.has(key):
			var batch := MultiMeshInstance3D.new()
			batch.name = "FarBuilding_%d" % proxies.size()
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.use_colors = true
			batch.multimesh.mesh = cube if source_mesh is BoxMesh else source_mesh
			batch.material_override = material
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Each proxy has at most one 512 m sector; fog covers the horizon.
			# It must not lose its silhouette when a far batch centre crosses a range.
			batch.visible = false
			add_child(batch)
			proxies[key] = {"node": batch, "members": [], "buffer": PackedFloat32Array(), "source_buffer": PackedFloat32Array(), "source_bounds": AABB()}
		var placements: Array[Transform3D] = []
		var colours := PackedColorArray()
		var mesh_size: Vector3 = source_mesh.get_aabb().size
		var authored: Array[Transform3D] = node.multimesh.instance_transforms
		var tints: PackedColorArray = node.multimesh.instance_tints
		for index in authored.size():
			var placement := authored[index]
			var size := Vector3(placement.basis.x.length(), placement.basis.y.length(), placement.basis.z.length()) * mesh_size
			var structural := _structural(size, material.resource_name) if tower else _house_structural(size, source_mesh is QuadMesh)
			if not structural or not node.visible:
				continue
			if source_mesh is BoxMesh:
				placement.basis *= Basis.from_scale(mesh_size)
			placements.append(local_transform * placement)
			colours.append(tints[index] if index < tints.size() else Color.WHITE)
		# Compact immutable data avoids retaining a second city-sized collection
		# of boxed Transform3D values and repacking every affected sector at runtime.
		var source_data: PackedFloat32Array = proxies[key].source_buffer
		var offset := source_data.size()
		source_data.append_array(BakedMultiMesh.make_buffer(placements, colours))
		proxies[key].source_buffer = source_data
		proxies[key].source_bounds = proxies[key].source_bounds.merge(bounds) if offset > 0 else bounds
		var record := {"node": node, "bounds": rectangle, "aabb": bounds, "active": true, "authored_visible": node.visible, "offset": offset, "count": placements.size(), "proxy_key": key, "detail_radius": DETAIL_RADIUS if tower else HOUSE_DETAIL_RADIUS, "retain_radius": RETAIN_RADIUS if tower else HOUSE_RETAIN_RADIUS}
		_index_record(rectangle, groups.size(), tower)
		groups.append(record)
		proxies[key].members.append(record)
		total_detail_instances += authored.size()
		total_proxy_instances += placements.size()


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
			dirty[record.proxy_key] = true
			active_detail_batches += int(wanted) if force else (1 if wanted else -1)
		record.active = wanted
		if wanted:
			_active_ids[id] = true
		else:
			_active_ids.erase(id)
	for key in dirty:
		_rebuild_proxy(proxies[key])


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
		var radius := DETAIL_RADIUS if kind == "tower" else HOUSE_DETAIL_RADIUS
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
		for record in entry.members:
			if record.active and record.count > 0:
				partial = true
		if not partial:
			# Most sectors are entirely distant: share their immutable packed data
			# instead of retaining another complete copy of the distant city.
			data = entry.source_buffer
			bounds = entry.source_bounds
		else:
			for record in entry.members:
				if not record.active and record.count > 0:
					data.append_array(entry.source_buffer.slice(record.offset, record.offset + record.count * 16))
					bounds = bounds.merge(record.aabb) if has_bounds else record.aabb
					has_bounds = true
	entry.node.visible = not data.is_empty()
	# Only sectors whose near/far membership changed are uploaded again.
	entry.buffer = data
	var multimesh: MultiMesh = entry.node.multimesh
	var count := data.size() / 16
	if multimesh.instance_count != count:
		multimesh.instance_count = count
	multimesh.custom_aabb = bounds
	if count > 0 and DisplayServer.get_name() != "headless":
		multimesh.buffer = data


static func unpack_transform(data: PackedFloat32Array, index: int) -> Transform3D:
	var at := index * 16
	return Transform3D(Basis(Vector3(data[at], data[at + 4], data[at + 8]), Vector3(data[at + 1], data[at + 5], data[at + 9]), Vector3(data[at + 2], data[at + 6], data[at + 10])), Vector3(data[at + 3], data[at + 7], data[at + 11]))
