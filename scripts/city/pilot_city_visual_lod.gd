extends Node3D

# Preserve tower setbacks, roofs, antennae and occupied windows at distance.
# Nearby batches use the full authored facade; no geometry/collision is deleted.
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
const DETAIL_RADIUS := 340.0
const RETAIN_RADIUS := 420.0
const PROXY_TILE := 512.0
var target: PlayerCar
var groups: Array[Dictionary] = []
var proxies: Dictionary = {}
var economy_enabled := false
var total_detail_instances := 0
var total_proxy_instances := 0
var active_detail_batches := 0
var _timer := 0.0
var _last_position := Vector3.INF


func _ready() -> void:
	var world := get_parent()
	target = world.get_node("PlayerCar")
	var city: Node3D = world.get_node("City")
	transform = city.transform
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for node in city.find_children("*", "MultiMeshInstance3D", true, false):
		var material := node.material_override as StandardMaterial3D
		if material == null or not material.resource_name.begins_with("downtown") or not node.multimesh.mesh is BoxMesh:
			continue
		var local_transform: Transform3D = city.global_transform.affine_inverse() * node.global_transform
		var bounds: AABB = local_transform * node.multimesh.custom_aabb
		var rectangle := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		var tile := Vector2i(floori(rectangle.get_center().x / PROXY_TILE), floori(rectangle.get_center().y / PROXY_TILE))
		# Sector serialization may duplicate equivalent materials. Merge only
		# matching facade properties, retaining their exact per-instance colours.
		var key := "%s/%s" % [tile, _material_key(material)]
		if not proxies.has(key):
			var batch := MultiMeshInstance3D.new()
			batch.name = "FarTower_%d" % proxies.size()
			batch.multimesh = BakedMultiMesh.new()
			batch.multimesh.mesh = cube
			batch.material_override = material
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Each proxy has at most one 512 m sector; fog covers the horizon.
			# It must not lose its silhouette when a far batch centre crosses a range.
			batch.visible = false
			add_child(batch)
			proxies[key] = {"node": batch, "members": []}
		var placements: Array[Transform3D] = []
		var colours := PackedColorArray()
		var mesh_size: Vector3 = node.multimesh.mesh.size
		var authored: Array[Transform3D] = node.multimesh.instance_transforms
		var tints: PackedColorArray = node.multimesh.instance_tints
		for index in authored.size():
			var placement := authored[index]
			var size := Vector3(placement.basis.x.length(), placement.basis.y.length(), placement.basis.z.length()) * mesh_size
			if not _structural(size, material.resource_name) or not node.visible:
				continue
			placement.basis *= Basis.from_scale(mesh_size)
			placements.append(local_transform * placement)
			colours.append(tints[index] if index < tints.size() else Color.WHITE)
		var record := {"node": node, "bounds": rectangle, "active": true, "authored_visible": node.visible, "placements": placements, "colours": colours, "proxy_key": key}
		groups.append(record)
		proxies[key].members.append(record)
		total_detail_instances += authored.size()
		total_proxy_instances += placements.size()
	target.car_reset.connect(refresh)
	set_economy_enabled(bool(world.get_node("/root/WaveSettings").graphics["city_lod"]))


static func _structural(size: Vector3, material_name: String) -> bool:
	if material_name == "downtown_window":
		return true
	if material_name == "downtown_copper" and size.y >= 8.0:
		return true
	return size.x >= 5.0 and size.z >= 5.0 and (size.y >= 2.0 or absf(size.y - 0.3) < 0.02)


static func _material_key(material: StandardMaterial3D) -> String:
	var values: Array = []
	for property in ["resource_name", "albedo_color", "albedo_texture", "roughness", "metallic", "shading_mode", "vertex_color_use_as_albedo", "cull_mode", "transparency", "normal_enabled", "normal_texture", "emission_enabled", "emission", "emission_energy_multiplier"]:
		values.append(material.get(property))
	return str(values)


func set_economy_enabled(enabled: bool) -> void:
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
	_last_position = target.global_position
	var local_position := to_local(_last_position)
	var point := Vector2(local_position.x, local_position.z)
	var dirty: Dictionary = {}
	active_detail_batches = 0
	for record in groups:
		var bounds: Rect2 = record.bounds
		var closest := point.clamp(bounds.position, bounds.end)
		var radius := RETAIN_RADIUS if record.active else DETAIL_RADIUS
		var wanted := not economy_enabled or point.distance_squared_to(closest) <= radius * radius
		var visible: bool = wanted and record.authored_visible
		if record.node.visible != visible:
			record.node.visible = visible
		if force or wanted != record.active:
			dirty[record.proxy_key] = true
		record.active = wanted
		active_detail_batches += 1 if wanted else 0
	for key in dirty:
		_rebuild_proxy(proxies[key])


func _rebuild_proxy(entry: Dictionary) -> void:
	var placements: Array[Transform3D] = []
	var colours := PackedColorArray()
	if economy_enabled:
		for record in entry.members:
			if not record.active:
				placements.append_array(record.placements)
				colours.append_array(record.colours)
	entry.node.visible = not placements.is_empty()
	# Only sectors whose near/far membership changed are uploaded again.
	entry.node.multimesh.instance_tints = colours
	entry.node.multimesh.instance_transforms = placements
