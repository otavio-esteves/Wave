extends "res://scripts/city/offline_scene_builder.gd"

# Authored 600 m layout. Only decoration varies deterministically, offline.
const LENGTH_M := 600.0
const SEED := 5547
const SIDE_STREETS: Array[float] = [-160.0, -360.0]
const HOUSE_LOTS: Array[float] = [-14.0, -34.0, -55.0, -74.0, -96.0, -122.0, -141.0, -188.0, -208.0, -229.0, -249.0, -270.0, -290.0, -311.0, -329.0, -345.0, -388.0, -408.0, -429.0, -450.0, -473.0, -495.0, -516.0, -538.0, -559.0, -581.0]
var rng := RandomNumberGenerator.new()


func build() -> Node3D:
	begin("CorridorMap", "CorridorColliders")
	rng.seed = SEED
	scene_root.set_meta("length_m", LENGTH_M)
	scene_root.set_meta("seed", SEED)
	scene_root.set_meta("generator_version", 2)
	_palette()
	_roads()
	_neighborhood()
	_workshop()
	_market()
	_furniture()
	_hero_details()
	_horizon()
	finish()
	for child in scene_root.get_children():
		if child is MultiMeshInstance3D:
			var material := child.material_override as StandardMaterial3D
			if material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
				# Cards rotate in the shader beyond their authored zero-depth bounds.
				child.multimesh.billboard_radius = 6.0
			if material.resource_name in ["plaster", "roof", "sidewalk", "metal"]:
				child.visibility_range_end = 420.0
			if material.resource_name.begins_with("sign"):
				child.visibility_range_end = 130.0
			if material.resource_name.begins_with("facade"):
				child.visibility_range_end = 210.0
				child.visibility_range_end_margin = 10.0
	_assign_owner(scene_root)
	return scene_root


func _palette() -> void:
	preload("res://scripts/city/city_building_kit.gd").palette(self)


func _roads() -> void:
	add_collision(Vector3(0, -0.3, -300), Vector3(260, 0.6, 820))
	_surface("Ground", Vector2(0, -300), Vector2(260, 820), 0.0, "grass", 0.16)
	for start in range(-624, 36, 60):
		_surface("Avenue", Vector2(0, start + 30), Vector2(12, 60), 0.018, "asphalt", 0.25)
	for z in SIDE_STREETS:
		_surface("SideStreet", Vector2(0, z), Vector2(160, 10), 0.022, "asphalt", 0.25)
	for side in [-1.0, 1.0]:
		for start in range(-620, 36, 4):
			var z := float(start + 2)
			if _opening(z, side):
				continue
			add_box(Vector3(side * 7.6, 0.065, z), Vector3(3.2, 0.13, 4), "sidewalk", true, 0.0, false)
			add_box(Vector3(side * 6.1, 0.14, z), Vector3(0.22, 0.28, 3.97), "plaster", true, 0.0, false)
		for z in SIDE_STREETS:
			for x in [-72.0, -48.0, -24.0, 24.0, 48.0, 72.0]:
				add_box(Vector3(x, 0.06, z + side * 6.4), Vector3(24, 0.12, 2.8), "sidewalk", true, 0.0, false)
	for z in range(-610, 25, 6):
		if _crossing(float(z), 8.0):
			continue
		for x in [-0.18, 0.18]:
			add_box(Vector3(x, 0.034, z), Vector3(0.11, 0.008, 3.4), "yellow", false, 0.0, false)
		for x in [-5.7, 5.7]:
			add_box(Vector3(x, 0.033, z), Vector3(0.09, 0.008, 5.4), "white", false, 0.0, false)
	for z in SIDE_STREETS:
		for stripe in 12:
			var x := -5.15 + stripe * 0.93
			for offset in [-8.0, 8.0]:
				add_box(Vector3(x, 0.037, z + offset), Vector3(0.6, 0.01, 2.4), "white", false, 0.0, false)
	for index in 38:
		var z := rng.randf_range(-600, 20)
		var x := rng.randf_range(-4.8, 4.8)
		_surface("Repair", Vector2(x, z), Vector2(rng.randf_range(0.8, 2.6), rng.randf_range(1.2, 4.7)), 0.030, "patch", 0.29, Color(0.9, 0.9, 0.9))
	for z in [-630.0, 42.0]:
		add_box(Vector3(0, 0.45, z), Vector3(19, 0.9, 0.5), "sidewalk", true)


func _opening(z: float, side: float) -> bool:
	return _crossing(z, 7.0) or (side < 0.0 and absf(z + 115.0) < 11.0) or (side > 0.0 and absf(z + 336.0) < 13.0)


func _crossing(z: float, margin: float) -> bool:
	for street in SIDE_STREETS:
		if absf(z - street) < margin:
			return true
	return false


func _surface(label: String, center: Vector2, size: Vector2, height: float, material: String, uv_scale: float, tint: Color = Color.WHITE) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector3] = [Vector3(center.x - size.x / 2, height, center.y - size.y / 2), Vector3(center.x + size.x / 2, height, center.y - size.y / 2), Vector3(center.x + size.x / 2, height, center.y + size.y / 2), Vector3(center.x - size.x / 2, height, center.y + size.y / 2)]
	for vertex in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(Vector3.UP)
		tool.set_color(tint)
		tool.set_uv(Vector2(corners[vertex].x, corners[vertex].z) * uv_scale)
		tool.add_vertex(corners[vertex])
	var instance := MeshInstance3D.new()
	instance.name = "%s_%d" % [label, scene_root.get_child_count()]
	instance.mesh = tool.commit()
	instance.material_override = materials[material]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(instance)


func _neighborhood() -> void:
	for side in [-1.0, 1.0]:
		for index in HOUSE_LOTS.size():
			var z := HOUSE_LOTS[index] + (5.0 if side > 0 else 0.0)
			if (side < 0 and absf(z + 115) < 26) or (side > 0 and absf(z + 336) < 19):
				continue
			var width := rng.randf_range(9.0, 13.5)
			var height := 6.8 if index % 5 == 2 else 3.8
			var depth := rng.randf_range(8.0, 12.0)
			var origin := Vector3(side * rng.randf_range(20.0, 24.5), 0, z)
			_building(origin, width, height, depth, PI / 2 if side < 0 else -PI / 2, 1 if height > 6 else 0)
			# Walls and open gates define a Brazilian front yard rather than a grid of boxes.
			var street_edge: float = side * 11.5
			add_box(Vector3(street_edge, 0.75, z - width * 0.33), Vector3(0.25, 1.5, width * 0.45), "plaster", true)
			add_box(Vector3(street_edge, 0.55, z + width * 0.35), Vector3(0.15, 1.1, width * 0.33), "metal", true)
			if index % 3 == 0:
				_tree(Vector3(side * 10.2, 0, z + width * 0.6), rng.randf_range(7.0, 10.0))
	# Empty lot and rear warehouses break the street rhythm.
	_surface("VacantLot", Vector2(-29, -462), Vector2(25, 16), 0.01, "brick", 0.18, Color(0.8, 0.83, 0.8))
	for z in [-80.0, -240.0, -440.0]:
		add_box(Vector3(64, 5.0, z), Vector3(25, 10, 22), "plaster", true)
		add_box(Vector3(64, 10.2, z), Vector3(26, 0.4, 23), "metal")


func _building(origin: Vector3, width: float, height: float, depth: float, yaw: float, facade: int) -> void:
	preload("res://scripts/city/city_building_kit.gd").building(self, origin, width, height, depth, yaw, facade)


func _workshop() -> void:
	var origin := Vector3(-32, 0, -115)
	_surface("WorkshopForecourt", Vector2(-21, -115), Vector2(30, 27), 0.025, "asphalt", 0.25)
	_building(origin, 19, 5.0, 11, PI / 2, 2)
	_ground_ao(Vector2(-28, -115), Vector2(16, 25), "asphalt", 0.027, 0.25)
	add_box(Vector3(-23, 3.8, -115), Vector3(4, 0.18, 20), "metal")
	for z in [-124.0, -106.0]:
		add_box(Vector3(-21, 1.9, z), Vector3(0.16, 3.8, 0.16), "metal", true)
	add_box(Vector3(-20.94, 3.96, -115), Vector3(0.16, 0.8, 20.2), "blue", false, 0, false)
	add_instance("facade", "sign0", Vector3(-20.84, 3.96, -115), Vector3(17, 0.76, 1), PI / 2, false)
	for z in [-122.0, -119.0]:
		for height in [0.35, 0.8]:
			add_instance("cylinder", "metal", Vector3(-19, height, z), Vector3(0.62, 0.35, 0.62), 0, false)
	_marker("Workshop", origin)


func _market() -> void:
	var origin := Vector3(29, 0, -336)
	_surface("MarketForecourt", Vector2(19, -336), Vector2(26, 27), 0.025, "asphalt", 0.25)
	_building(origin, 18, 5.2, 12, -PI / 2, 3)
	_ground_ao(Vector2(26, -336), Vector2(17, 24), "asphalt", 0.027, 0.25)
	add_box(Vector3(20.5, 3.7, -336), Vector3(5.0, 0.2, 19), "terracotta")
	for z in [-344.5, -327.5]:
		add_box(Vector3(18.0, 1.85, z), Vector3(0.16, 3.7, 0.16), "metal", true)
	add_box(Vector3(17.94, 3.86, -336), Vector3(0.16, 0.8, 19.2), "cream", false, 0, false)
	add_instance("facade", "sign1", Vector3(17.84, 3.86, -336), Vector3(16.5, 0.76, 1), -PI / 2, false)
	for index in 3:
		add_box(Vector3(18, 0.45, -329 + index * 1.0), Vector3(0.8, 0.9, 0.8), "wood")
	_marker("Market", origin)


func _hero_details() -> void:
	# Authored after all random decoration: preserve every existing lot/tree and
	# collider. Paint/trim shares the current spatial/material batches.
	_surface("WorkshopApron", Vector2(-24.3, -115), Vector2(4.0, 23), 0.033, "sidewalk", 0.18, Color(0.84, 0.85, 0.83))
	_surface("MarketApron", Vector2(18, -336), Vector2(8.5, 25), 0.033, "sidewalk", 0.18, Color(0.94, 0.91, 0.86))
	for entry in [[-26.38, -115.0, 19.0, "brick"], [22.88, -336.0, 18.0, "terracotta"]]:
		add_box(Vector3(entry[0], 0.25, entry[1]), Vector3(0.12, 0.5, entry[2]), entry[3], false, 0, false)
	for z in [-124.25, -105.75]:
		add_box(Vector3(-26.39, 2.3, z), Vector3(0.12, 4.6, 0.3), "blue", false, 0, false)
	for z in [-344.75, -327.25]:
		add_box(Vector3(22.88, 2.35, z), Vector3(0.12, 4.7, 0.3), "cream", false, 0, false)
	# Different use, different ground rhythm: workshop safety edge and market bays.
	for z in [-125.5, -104.5]:
		add_box(Vector3(-22.2, 0.041, z), Vector3(6.5, 0.006, 0.10), "yellow", false, 0, false)
		for stripe in 5:
			add_box(Vector3(-16.5 + stripe * 0.65, 0.041, z), Vector3(0.10, 0.006, 1.1), "yellow", false, 0.5, false)
	for z in [-344.0, -340.0, -332.0, -328.0]:
		add_box(Vector3(16, 0.042, z), Vector3(6.8, 0.006, 0.09), "white", false, 0, false)
	add_box(Vector3(12.6, 0.042, -336), Vector3(0.09, 0.006, 16), "white", false, 0, false)
	# Small curb-return accents stop before the open vehicle entrances.
	for entry in [[-6.23, -129.5], [-6.23, -100.5], [6.23, -350.5], [6.23, -321.5]]:
		add_box(Vector3(entry[0], 0.285, entry[1]), Vector3(0.24, 0.008, 2.0), "yellow", false, 0, false)
	_wear("WorkshopUse", [Vector2(-19.5, -118), Vector2(-18.5, -112), Vector2(-24.5, -123)], [Vector2(3.4, 1.5), Vector2(2.2, 1.2), Vector2(1.8, 2.8)], 0.025, "asphalt", 0.25, 0.46)
	_wear("WorkshopApronUse", [Vector2(-24.2, -117), Vector2(-24.0, -110)], [Vector2(2.7, 1.1), Vector2(1.5, 2.1)], 0.033, "sidewalk", 0.18, 0.54)
	_wear("MarketUse", [Vector2(10.5, -342), Vector2(11.0, -329)], [Vector2(2.2, 4.5), Vector2(1.8, 3.2)], 0.025, "asphalt", 0.25, 0.72)
	_wear("MarketApronUse", [Vector2(18.0, -343), Vector2(20.5, -329)], [Vector2(2.4, 3.4), Vector2(1.8, 2.6)], 0.033, "sidewalk", 0.18, 0.70)


func _wear(label: String, centers: Array[Vector2], sizes: Array[Vector2], base_height: float, material: String, uv_scale: float, dark: float) -> void:
	# Opaque vertex gradients with matching ground UVs, one draw batch per area
	# and material. No alpha overlap, runtime decals, texture or shader variants.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spot in centers.size():
		for wedge in 8:
			var a := Vector2(cos(TAU * wedge / 8), sin(TAU * wedge / 8)) * sizes[spot] / 2
			var b := Vector2(cos(TAU * (wedge + 1) / 8), sin(TAU * (wedge + 1) / 8)) * sizes[spot] / 2
			for point in [Vector2.ZERO, a, b]:
				var position: Vector2 = centers[spot] + point
				tool.set_normal(Vector3.UP)
				tool.set_color(Color(dark, dark, dark) if point == Vector2.ZERO else Color.WHITE)
				tool.set_uv(position * uv_scale)
				tool.add_vertex(Vector3(position.x, base_height + 0.004, position.y))
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = tool.commit()
	mesh.material_override = materials[material]
	mesh.visibility_range_end = 100.0
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(mesh)


func _tree(position: Vector3, height: float) -> void:
	_ground_ao(Vector2(position.x, position.z), Vector2(height * 0.9, height * 0.8), "grass", 0.007, 0.16)
	add_instance("facade", "street_tree", position + Vector3.UP * height / 2, Vector3(height * 0.82, height, 1), 0, false)
	add_collision(position + Vector3.UP, Vector3(0.45, 2, 0.45))


func _furniture() -> void:
	for side in [-1.0, 1.0]:
		var previous := Vector3.ZERO
		for index in 19:
			var z := 20.0 - index * 35.0
			var pole := Vector3(side * 8.4, 0, z)
			add_instance("cylinder", "plaster", pole + Vector3.UP * 4.2, Vector3(0.16, 8.4, 0.16))
			add_collision(pole + Vector3.UP * 2.5, Vector3(0.32, 5.0, 0.32))
			add_box(pole + Vector3.UP * 7.8, Vector3(2.2, 0.14, 0.16), "wood")
			add_box(pole + Vector3(-side * 1.3, 7.4, 0), Vector3(1.6, 0.13, 0.14), "metal")
			add_box(pole + Vector3(-side * 2.0, 7.25, 0), Vector3(0.55, 0.1, 0.28), "light", false, 0, false)
			if index > 0:
				for line in [-0.7, 0.0, 0.7]:
					_wire(previous + Vector3(line, 7.8, 0), pole + Vector3(line, 7.8, 0))
			previous = pole
	for z in SIDE_STREETS:
		add_box(Vector3(11.6, 1.7, z + 11), Vector3(0.08, 3.4, 0.08), "metal", true)
		add_box(Vector3(11.6, 2.75, z + 11), Vector3(2.0, 0.45, 0.12), "blue")
		add_instance("facade", "sign2", Vector3(11.6, 2.75, z + 11.08), Vector3(2, 0.45, 1), 0, false)
	for position in [Vector3(-11, 0, -86), Vector3(12, 0, -371), Vector3(-11, 0, -380), Vector3(23, 0, -565)]:
		_tree(position, 10.0)
	for side in [-1.0, 1.0]:
		for z in SIDE_STREETS:
			for x in [38.0, 60.0]:
				_building(Vector3(x * side, 0, z + 19), 11, 4.0, 9, 0, 0)


func _wire(start: Vector3, end: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 6:
		var a := start.lerp(end, float(index) / 6)
		var b := start.lerp(end, float(index + 1) / 6)
		a.y -= sin(PI * float(index) / 6) * 0.6
		b.y -= sin(PI * float(index + 1) / 6) * 0.6
		for v in [a, b, b + Vector3.UP * 0.025, a, b + Vector3.UP * 0.025, a + Vector3.UP * 0.025]:
			tool.set_normal(Vector3.RIGHT)
			tool.add_vertex(v)
	var material: StandardMaterial3D = materials["metal"]
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := MeshInstance3D.new()
	mesh.name = "Wire_%d" % scene_root.get_child_count()
	mesh.mesh = tool.commit()
	mesh.material_override = material
	mesh.visibility_range_end = 150
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(mesh)


func _horizon() -> void:
	for index in 12:
		var x := -320.0 + index * 62
		add_instance("horizon_hill", "hill", Vector3(x, -35, -800 - sin(index * 0.9) * 90), Vector3(120, 70 + sin(index * 1.7) * 25, 110), 0, false)
	for index in 22:
		add_box(Vector3(-180 + index * 17, 3.5, -745 - (index % 3) * 11), Vector3(12, 7 + (index % 4) * 2, 9), "hill", false, 0, false)


func _marker(label: String, position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = position
	scene_root.add_child(marker)


func _ground_ao(center: Vector2, size: Vector2, material: String, height: float, uv_scale: float) -> void:
	# Opaque vertex gradient over the same texture/UV as the ground; zero alpha cards.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 12:
		var first := Vector2(cos(TAU * index / 12), sin(TAU * index / 12)) * size / 2
		var second := Vector2(cos(TAU * (index + 1) / 12), sin(TAU * (index + 1) / 12)) * size / 2
		for vertex in [Vector2.ZERO, first, second]:
			var position: Vector2 = center + vertex
			tool.set_normal(Vector3.UP)
			tool.set_uv(position * uv_scale)
			tool.set_color(Color(0.54, 0.54, 0.54) if vertex == Vector2.ZERO else Color.WHITE)
			tool.add_vertex(Vector3(position.x, height, position.y))
	var mesh := MeshInstance3D.new()
	mesh.name = "GroundOcclusion_%d" % scene_root.get_child_count()
	mesh.mesh = tool.commit()
	mesh.material_override = materials[material]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(mesh)
