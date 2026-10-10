extends "res://scripts/corridor/corridor_builder.gd"

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var road_faces := PackedVector3Array()
var sidewalk_faces := PackedVector3Array()
var paint_faces := PackedVector3Array()
var street_samples: Array[Dictionary] = []
var sites_valid := true
var tree_count := 0
var driveway_faces := PackedVector3Array()
var address_faces := PackedVector3Array()
var parcel_count := 0
var parked_count := 0
var occlusion_tool: SurfaceTool
var parcels: Array[Dictionary] = []
var driveway_connections: Array[Dictionary] = []
var road_tiles: Dictionary = {}
var ramp_tiles: Dictionary = {}
var grass_count := 0
var garden_frontages := 0


func build_city() -> Node3D:
	batch_size = 112.0
	begin("PilotCity", "Colliders")
	_palette()
	_premium_palette()
	_tree_palette()
	tree_count = 0
	parcel_count = 0
	parked_count = 0
	occlusion_tool = SurfaceTool.new()
	occlusion_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	road_faces.clear()
	sidewalk_faces.clear()
	paint_faces.clear()
	driveway_faces.clear()
	address_faces.clear()
	sites_valid = true
	street_samples.clear()
	parcels.clear()
	driveway_connections.clear()
	road_tiles.clear()
	ramp_tiles.clear()
	grass_count = 0
	garden_frontages = 0
	for edge in Layout.edges():
		street_samples.append({"points": Layout.edge_points(edge.a, edge.b), "width": edge.width})
	var ground := Layout.terrain_faces()
	_mesh("Terrain", ground, "grass", 0.075)
	_support("Terrain", ground)
	for edge in Layout.edges():
		_street(edge)
	for id in Layout.NODE_COUNT:
		_junction(Layout.node(id))
	_blocks()
	_outer_frontages()
	_prepare_distance_field()
	_joined_sidewalks()
	for access in [Layout.square_access(), Layout.workshop_access()]:
		for index in access.size() - 1:
			_ribbon(road_faces, access[index], access[index + 1], -3.5, 3.5, Layout.ROAD_LIFT)
	_mesh("Streets", road_faces, "asphalt", 0.25)
	_mesh("Sidewalks", sidewalk_faces, "sidewalk", 0.18)
	_settle_markings()
	_mesh("RoadMarkings", paint_faces, "white", 1.0)
	_support("Streets", road_faces)
	_support("Sidewalks", sidewalk_faces)
	_mesh("LotDriveways", driveway_faces, "paving", 0.25)
	_mesh("HouseNumbers", address_faces, "charcoal", 1.0)
	_street_life()
	_boundary()
	_landscape()
	_meadow_grass()
	occlusion_tool.generate_normals()
	occlusion_tool.index()
	var shade := MeshInstance3D.new()
	shade.name = "TerrainContactShading"
	shade.mesh = occlusion_tool.commit()
	shade.material_override = materials["grass"]
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(shade)
	var city := finish()
	for child in city.get_children():
		if child is MultiMeshInstance3D and child.material_override.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			child.multimesh.billboard_radius = 6.0
	for child in city.get_children():
		if child is MultiMeshInstance3D and child.material_override.resource_name == "wild_grass":
			child.visibility_range_end = 75.0
			child.visibility_range_end_margin = 12.0
		if child is MultiMeshInstance3D and child.material_override.resource_name.begins_with("skyline"):
			child.visibility_range_end = 650.0
	city.set_meta("block_count", Layout.BLOCK_COUNT)
	city.set_meta("planned_block_count", Layout.PLANNED_BLOCK_COUNT)
	city.set_meta("generator_version", 7)
	city.set_meta("area_m2", 4.0 * Layout.HALF_WIDTH * Layout.HALF_DEPTH)
	city.set_meta("grass_tuft_count", grass_count)
	city.set_meta("garden_frontages", garden_frontages)
	city.set_meta("parcel_footprints", parcels)
	city.set_meta("volumetric_tree_count", tree_count)
	city.set_meta("parcel_count", parcel_count)
	city.set_meta("parked_vehicle_count", parked_count)
	return city


func save_city(output: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if error != OK:
		return error
	var city := build_city()
	if not sites_valid:
		city.free()
		return ERR_INVALID_DATA
	var packed := PackedScene.new()
	error = packed.pack(city)
	if error == OK:
		error = ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS if output.ends_with(".scn") else 0)
	city.free()
	return error


func _street(edge: Dictionary) -> void:
	var points := Layout.edge_points(edge.a, edge.b)
	var half: float = edge.width / 2.0
	for index in points.size() - 1:
		var a := points[index]
		var b := points[index + 1]
		_band(road_faces, points, index, -half, half, Layout.ROAD_LIFT)
		# Broad bevels and shared vertex frames prevent lips and cracks catching the car.
		var in_crossing := a.distance_to(points[0]) < 14.0 or a.distance_to(points[-1]) < 14.0
		if index in [7, points.size() - 9]:
			for stripe in range(ceili(edge.width - 1.4)):
				var left := -half + 0.7 + stripe
				_band(paint_faces, points, index, left, minf(left + 0.5, half - 0.7), 0.043)
		elif not in_crossing and index % 5 < 2:
			_band(paint_faces, points, index, -0.055, 0.055, 0.045)


func _band(faces: PackedVector3Array, points: PackedVector3Array, index: int, left: float, right: float, lift: float, right_lift: float = NAN, curb: bool = false) -> void:
	var n0 := (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).cross(Vector3.UP).normalized()
	var n1 := (points[mini(index + 2, points.size() - 1)] - points[index]).cross(Vector3.UP).normalized()
	if is_nan(right_lift):
		right_lift = lift
	var end_left := lift
	var end_right := right_lift
	if curb:
		var first := _curb_blend(points, index)
		var last := _curb_blend(points, index + 1)
		end_left = lerpf(Layout.ROAD_LIFT, lift, last)
		end_right = lerpf(Layout.ROAD_LIFT, right_lift, last)
		lift = lerpf(Layout.ROAD_LIFT, lift, first)
		right_lift = lerpf(Layout.ROAD_LIFT, right_lift, first)
	_ribbon(faces, points[index], points[index + 1], left, right, lift, right_lift, n0, n1, end_left, end_right)


func _curb_blend(points: PackedVector3Array, index: int) -> float:
	var crossing := minf(points[index].distance_to(points[0]), points[index].distance_to(points[-1]))
	var drive := absf(float(index) / (points.size() - 1) - 0.5) * points[0].distance_to(points[-1])
	return minf(smoothstep(14.0, 18.0, crossing), smoothstep(points[0].distance_to(points[-1]) * 0.055 + 2.0, points[0].distance_to(points[-1]) * 0.055 + 6.0, drive))


func _ribbon(faces: PackedVector3Array, start: Vector3, end: Vector3, left: float, right: float, lift: float, right_lift: float = NAN, start_normal: Vector3 = Vector3.ZERO, end_normal: Vector3 = Vector3.ZERO, end_left_lift: float = NAN, end_right_lift: float = NAN) -> void:
	var normal := (end - start).cross(Vector3.UP).normalized()
	if start_normal == Vector3.ZERO:
		start_normal = normal
	if end_normal == Vector3.ZERO:
		end_normal = normal
	if is_nan(right_lift):
		right_lift = lift
	if is_nan(end_left_lift):
		end_left_lift = lift
	if is_nan(end_right_lift):
		end_right_lift = right_lift
	var a := start + start_normal * left
	var b := start + start_normal * right
	var c := end + end_normal * left
	var d := end + end_normal * right
	a.y = Layout.height_at(a.x, a.z) + lift
	b.y = Layout.height_at(b.x, b.z) + right_lift
	c.y = Layout.height_at(c.x, c.z) + end_left_lift
	d.y = Layout.height_at(d.x, d.z) + end_right_lift
	_triangle(faces, a, c, b)
	_triangle(faces, b, c, d)


func _triangle(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Clockwise front faces viewed from above, for Godot render and physics.
	if (b - a).cross(c - a).length_squared() < 0.000000001:
		return
	faces.append_array(PackedVector3Array([a, c, b] if (b - a).cross(c - a).y > 0.0 else [a, b, c]))


func _junction(center: Vector3) -> void:
	for index in 24:
		var a := center + Vector3(cos(TAU * index / 24), 0, sin(TAU * index / 24)) * 11.5
		var b := center + Vector3(cos(TAU * (index + 1) / 24), 0, sin(TAU * (index + 1) / 24)) * 11.5
		a.y = Layout.height_at(a.x, a.z) + Layout.ROAD_LIFT
		b.y = Layout.height_at(b.x, b.z) + Layout.ROAD_LIFT
		_triangle(road_faces, center + Vector3.UP * Layout.ROAD_LIFT, a, b)


func _mesh(label: String, faces: PackedVector3Array, material: String, uv_scale: float, shadow_center: Vector2 = Vector2.ZERO, shadow_size: Vector2 = Vector2.ZERO) -> void:
	var tool := occlusion_tool if shadow_size != Vector2.ZERO else SurfaceTool.new()
	if shadow_size == Vector2.ZERO:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in faces:
		tool.set_uv(Vector2(point.x, point.z) * uv_scale)
		var tint := Color.WHITE
		if material == "grass":
			var variation := 0.88 + 0.06 * sin(point.x * 0.071) * cos(point.z * 0.053) + 0.04 * sin(point.x * 0.21 + point.z * 0.16)
			tint = Color(variation, variation, variation * 0.96, 1)
		elif material == "asphalt":
			var wear := 0.94 + 0.035 * sin(point.x * 0.13 + point.z * 0.17) + 0.025 * cos(point.z * 0.34)
			tint = Color(wear, wear, wear)
		if shadow_size != Vector2.ZERO:
			var relative := (Vector2(point.x, point.z) - shadow_center).abs() / (shadow_size * 0.5)
			var occlusion := lerpf(0.46, 1.0, smoothstep(0.60, 1.0, maxf(relative.x, relative.y)))
			tint *= Color(occlusion, occlusion, occlusion)
		tool.set_color(tint)
		tool.add_vertex(point)
	if shadow_size != Vector2.ZERO:
		return
	tool.generate_normals()
	tool.index()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.material_override = materials[material]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(node)


func _support(label: String, faces: PackedVector3Array) -> void:
	var collider := CollisionShape3D.new()
	collider.name = label
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collider.shape = shape
	_colliders.add_child(collider)


func _blocks() -> void:
	for row in Layout.ROW_COUNT - 1:
		for column in Layout.COLUMN_COUNT - 1:
			var id := row * (Layout.COLUMN_COUNT - 1) + column
			var u: float = (Layout.COLUMNS[column] + Layout.COLUMNS[column + 1]) / 2
			var v: float = (Layout.ROWS[row] + Layout.ROWS[row + 1]) / 2
			var block := Node3D.new()
			block.name = "Block%d" % id
			block.position = Layout.position(u, v)
			block.set_meta("label", Layout.block_name(id))
			scene_root.add_child(block)
			if id in Layout.PARK_BLOCKS:
				_square(u, v)
			elif id == Layout.WORKSHOP_BLOCK:
				_service(u + 18, v)
				_projected_patch("WorkshopYard", Layout.position(u + 33, v), Vector2(28, 26), "paving", 0.032)
				for offset: float in [-24.0, 24.0]:
					var yaw := 0.0 if offset > 0 else PI
					var lot := _safe_site(Vector2(u - 3, v + offset), Vector2(u - 20, v + offset * 1.2), yaw, Vector2(21.5, 24))
					if lot.is_finite():
						_villa(lot.x, lot.y, yaw, 2)
			else:
				for side: float in [-1.0, 1.0]:
					var frontage_count := 2
					for step in frontage_count:
						var street_row := row if side < 0 else row + 1
						var start_id: int = street_row * Layout.COLUMN_COUNT + column
						var t := 0.5 if frontage_count == 1 else lerpf(0.30, 0.70, float(step))
						var road_uv := Layout.street_uv(start_id, start_id + 1, t)
						var tangent := (Layout.street_uv(start_id, start_id + 1, t + 0.001) - Layout.street_uv(start_id, start_id + 1, t - 0.001)).normalized()
						var lot := road_uv - Vector2(-tangent.y, tangent.x) * side * 23.0
						lot = lot.lerp(Vector2(u, v), 0.20)
						var frontage := Layout.position(lot.x + tangent.x * 0.5, lot.y + tangent.y * 0.5) - Layout.position(lot.x - tangent.x * 0.5, lot.y - tangent.y * 0.5)
						var yaw := atan2(-frontage.z, frontage.x) + (PI if side < 0 else 0.0)
						var tower := Layout.district(id) == 2 and (step + int(side)) % 2 != 0
						var footprint := Vector2(23, 27) if tower else (Vector2(15.5, 18.5) if Layout.district(id) == 0 else Vector2(21.5, 24))
						lot = _safe_site(lot, Vector2(u, v), yaw, footprint)
						if not lot.is_finite():
							continue
						if tower:
							_tower(lot.x, lot.y, yaw, 4 + (id + step) % 3)
						else:
							_villa(lot.x, lot.y, yaw, (id * 7 + step + row) % 9) if Layout.district(id) != 0 else _cottage(lot.x, lot.y, yaw, (id * 3 + step + row) % 5)
			_block_gardens(u, v, id)
			# Gardens occupy block interiors while leaving the street sight lines clear.
			for side: float in [-1.0, 1.0]:
				_garden_tree(Layout.position(u + side * 22, v + (10 if id == 3 else 0)), 9.0)


func _house(u: float, v: float, width: float, height: float, depth: float, yaw: float, facade: int) -> void:
	var origin := Layout.position(u, v)
	var base := origin.y
	var low := origin.y
	for dx in [-width / 2, width / 2]:
		for dz in [-depth / 2, depth / 2]:
			var corner := origin + Basis(Vector3.UP, yaw) * Vector3(dx, 0, dz)
			base = maxf(base, Layout.height_at(corner.x, corner.z))
			low = minf(low, Layout.height_at(corner.x, corner.z))
	# A visible plinth levels the house, instead of tilting its walls with the hill.
	base += 0.12
	add_box(Vector3(origin.x, (base + low - 0.2) / 2, origin.z), Vector3(width + 0.3, base - low + 0.2, depth + 0.3), "brick", true, yaw)
	origin.y = base
	_building(origin, width, height, depth, yaw, facade)


func _square(u: float, v: float) -> void:
	var center := Layout.position(u, v)
	parcels.append({"center": Vector2(center.x, center.z), "yaw": 0.0, "size": Vector2(52, 44), "kind": "park"})
	_projected_patch("Square", center, Vector2(40, 36), "paving", 0.035)
	# Planting beds leave the central approach open for vehicle manoeuvres.
	for side: float in [-1.0, 1.0]:
		for offset: float in [-11.0, 11.0]:
			var bed := Layout.position(u + side * 14, v + offset)
			add_box(bed + Vector3.UP * 0.22, Vector3(7.0, 0.44, 5.0), "stone", true)
			add_box(bed + Vector3.UP * 0.46, Vector3(6.6, 0.12, 4.6), "hedge")
			_garden_tree(bed + Vector3.UP * 0.5, 8.0)
		var bench := Layout.position(u + side * 12, v)
		add_box(bench + Vector3.UP * 0.45, Vector3(3, 0.18, 0.8), "timber", true)
		add_box(bench + Vector3(0, 0.8, -0.35), Vector3(3, 0.55, 0.12), "timber", true)
	var pavilion := _foundation(u, v - 11, 11, 7, 0)
	for dx: float in [-4.6, 4.6]:
		add_part(pavilion, Vector3(dx, 1.8, 0), Vector3(0.18, 3.6, 6), "charcoal", 0, true)
	for slat in 15:
		add_part(pavilion, Vector3(-5.0 + slat * 0.72, 3.5, 0), Vector3(0.18, 0.26, 7.0), "timber", 0)


func _ground_ao(_center: Vector2, _size: Vector2, _material: String, _height: float, _uv_scale: float) -> void:
	# Foundations frame this blockout. Flat-world AO overlays do not fit its hills.
	pass


func _projected_patch(label: String, center: Vector3, size: Vector2, material: String, lift: float, occlusion: bool = false) -> void:
	var faces := PackedVector3Array()
	var minimum := Vector2(center.x, center.z) - size / 2
	var maximum := minimum + size
	# Clip the existing terrain triangles, retaining their exact planar heights.
	# Sampling a different grid makes paving intersect the ground on the hill.
	for z_index in range(floori(minimum.y / 4), ceili(maximum.y / 4)):
		for x_index in range(floori(minimum.x / 4), ceili(maximum.x / 4)):
			var x := x_index * 4.0
			var z := z_index * 4.0
			var a := Vector3(x, Layout.height_at(x, z), z)
			var b := Vector3(x + 4, Layout.height_at(x + 4, z), z)
			var c := Vector3(x, Layout.height_at(x, z + 4), z + 4)
			var d := Vector3(x + 4, Layout.height_at(x + 4, z + 4), z + 4)
			for triangle in [[a, b, c], [b, d, c]]:
				var polygon: Array[Vector3] = []
				polygon.assign(triangle)
				polygon = _clip(polygon, 0, minimum.x, true)
				polygon = _clip(polygon, 0, maximum.x, false)
				polygon = _clip(polygon, 2, minimum.y, true)
				polygon = _clip(polygon, 2, maximum.y, false)
				for index in range(1, polygon.size() - 1):
					_triangle(faces, polygon[0] + Vector3.UP * lift, polygon[index] + Vector3.UP * lift, polygon[index + 1] + Vector3.UP * lift)
	_mesh(label + str(scene_root.get_child_count()), faces, material, 0.075 if material == "grass" else 0.18, Vector2(center.x, center.z), size if occlusion else Vector2.ZERO)


func _clip(polygon: Array[Vector3], axis: int, limit: float, keep_greater: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var inside_a := a[axis] >= limit if keep_greater else a[axis] <= limit
		var inside_b := b[axis] >= limit if keep_greater else b[axis] <= limit
		if inside_a:
			result.append(a)
		if inside_a != inside_b:
			result.append(a.lerp(b, (limit - a[axis]) / (b[axis] - a[axis])))
	return result


func _boundary() -> void:
	for side in [-1.0, 1.0]:
		for x in range(-int(Layout.HALF_WIDTH) + 8, int(Layout.HALF_WIDTH) - 7, 8):
			var z: float = side * (Layout.HALF_DEPTH - 8)
			add_box(Vector3(x, Layout.height_at(x, z) + 0.6, z), Vector3(8, 1.2, 0.35), "hedge", true)
		for z in range(-int(Layout.HALF_DEPTH) + 8, int(Layout.HALF_DEPTH) - 7, 8):
			var x: float = side * (Layout.HALF_WIDTH - 8)
			add_box(Vector3(x, Layout.height_at(x, z) + 0.6, z), Vector3(0.35, 1.2, 8), "hedge", true)


func _premium_palette() -> void:
	for item in [["ivory", "cbcbbf", 0.8], ["stone", "bcb9ad", 0.9], ["charcoal", "333e43", 0.65], ["timber", "8b6850", 0.8], ["hedge", "4b6750", 0.95], ["flower", "baa17c", 0.95], ["pool", "50888c", 0.2], ["skyline", "a0a5a1", 0.95], ["skyline_roof", "68757a", 0.95], ["skyline_glass", "607884", 0.8]]:
		var material := StandardMaterial3D.new()
		material.resource_name = item[0]
		material.albedo_color = Color(item[1])
		material.roughness = item[2]
		if item[0] in ["ivory", "stone", "timber", "hedge", "flower"]:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		materials[item[0]] = material
	materials["street_tree"].shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	materials["grass"].shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	materials["glass"].albedo_color = Color("3d5964")
	materials["glass"].roughness = 0.16
	materials["glass"].metallic = 0.38
	materials["grass"].albedo_color = Color("aab79d")
	materials["grass"].albedo_texture = load("res://assets/textures/neighborhood/lawn-realism-v1.png")
	materials["grass"].uv1_scale = Vector3.ONE * (0.5 / 0.075)
	materials["asphalt"].albedo_color = Color("a6afb5")
	materials["white"].albedo_color = Color("e1e1d3")
	materials["sidewalk"].albedo_color = Color("b8b7aa")
	var paving: StandardMaterial3D = materials["sidewalk"].duplicate()
	paving.resource_name = "paving"
	paving.albedo_color = Color("c2c7c2")
	materials["paving"] = paving
	materials["hill"].albedo_color = Color("6b7c75")
	# World-meter projection avoids stretched textures on differently sized buildings.
	for entry in [["ivory", "stucco", 0.8], ["stone", "limestone", 0.5], ["timber", "timber", 0.65], ["sidewalk", "paving", 0.25], ["paving", "paving", 0.25]]:
		var surface: StandardMaterial3D = materials[entry[0]]
		surface.albedo_texture = load("res://assets/textures/neighborhood/%s-albedo.res" % entry[1])
		surface.normal_texture = load("res://assets/textures/neighborhood/%s-normal.res" % entry[1])
		surface.normal_enabled = true
		surface.normal_scale = 0.3
		surface.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		surface.uv1_triplanar = true
		surface.uv1_world_triplanar = true
		surface.uv1_scale = Vector3.ONE * float(entry[2])
		surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials["asphalt"].albedo_texture = load("res://assets/textures/neighborhood/asphalt-realism-v1.png")
	materials["asphalt"].albedo_color = Color("777e82")
	materials["asphalt"].uv1_scale = Vector3.ONE * 2.0
	materials["asphalt"].roughness = 0.92



func _foundation(u: float, v: float, width: float, depth: float, yaw: float) -> Vector3:
	var origin := Layout.position(u, v)
	var footprint := Vector2(absf(cos(yaw)) * width + absf(sin(yaw)) * depth, absf(sin(yaw)) * width + absf(cos(yaw)) * depth)
	_projected_patch("FoundationShade", origin, footprint + Vector2(6, 6), "grass", 0.011, true)
	var high := origin.y
	var low := origin.y
	for x_step in ceili(width / 2) + 1:
		for z_step in ceili(depth / 2) + 1:
			var dx := lerpf(-width / 2, width / 2, x_step / float(ceili(width / 2)))
			var dz := lerpf(-depth / 2, depth / 2, z_step / float(ceili(depth / 2)))
			var corner := origin + Basis(Vector3.UP, yaw) * Vector3(dx, 0, dz)
			high = maxf(high, Layout.height_at(corner.x, corner.z))
			low = minf(low, Layout.height_at(corner.x, corner.z))

	high += 0.12
	add_box(Vector3(origin.x, (high + low - 0.2) / 2, origin.z), Vector3(width + 0.4, high - low + 0.2, depth + 0.4), "stone", true, yaw)
	origin.y = high
	return origin


func _window(origin: Vector3, offset: Vector3, size: Vector2, yaw: float, side: bool = false) -> void:
	# Opaque inset glazing avoids transparent facade sorting and fill-rate cost.
	var extent := Vector3(0.16, size.y + 0.22, size.x + 0.22) if side else Vector3(size.x + 0.22, size.y + 0.22, 0.16)
	add_part(origin, offset, extent, "charcoal", yaw)
	var pane := Vector3(0.18, size.y, size.x) if side else Vector3(size.x, size.y, 0.18)
	add_part(origin, offset, pane, "glass", yaw)
	if not side:
		add_part(origin, offset + Vector3(0, 0, 0.10), Vector3(0.065, size.y, 0.04), "charcoal", yaw)
		add_part(origin, offset + Vector3(0, size.y * 0.30, 0.11), Vector3(size.x, 0.04, 0.03), "ivory", yaw)


func _villa(u: float, v: float, yaw: float, variant: int) -> void:
	parcel_count += 1
	var origin := _foundation(u, v, 17, 13, yaw)
	var wall: String = ["ivory", "sage", "cream", "rose", "ivory", "stone", "cream", "sage", "ivory"][variant % 9]
	var upper_x := -2.5 if variant % 2 == 0 else 2.5
	add_part(origin, Vector3(0, 1.65, 0), Vector3(16, 3.3, 12), wall, yaw, true)
	add_part(origin, Vector3(upper_x, 4.9, -1.0), Vector3(10.5, 3.2, 9.5), "stone" if variant % 3 == 1 else wall, yaw, true)
	add_part(origin, Vector3(0, 3.35, 0.4), Vector3(17.4, 0.28, 13.2), "ivory", yaw)
	add_part(origin, Vector3(upper_x, 6.6, -1.0), Vector3(11.5, 0.3, 10.5), "charcoal", yaw)
	if variant in [3, 6, 8]:
		# Roof terraces and pergolas vary the silhouette without enlarging the lot.
		for x: float in [-4, 4]:
			add_part(origin, Vector3(upper_x + x, 7.4, -1.0), Vector3(0.12, 1.6, 0.12), "timber", yaw)
		for slat in 9:
			add_part(origin, Vector3(upper_x - 4.2 + slat * 1.05, 8.25, -1.0), Vector3(0.14, 0.15, 5.0), "timber", yaw)
	# Roof coping, solar panels and rainwater pipes add believable scale.
	for side: float in [-1, 1]:
		add_part(origin, Vector3(upper_x + side * 5.5, 6.87, -1), Vector3(0.16, 0.36, 10.5), "ivory", yaw)
		add_part(origin, Vector3(side * 7.85, 1.62, -5.7), Vector3(0.09, 3.2, 0.09), "charcoal", yaw)
	for panel in 3:
		add_part(origin, Vector3(upper_x - 2.7 + panel * 2.5, 6.82, -1.8), Vector3(2.15, 0.08, 3.2), "glass", yaw)
	for x: float in [-4.5, 0.0, 4.5]:
		_window(origin, Vector3(x, 1.65, 6.10), Vector2(3.6, 2.3), yaw)
	for x: float in [-2.5, 2.5]:
		_window(origin, Vector3(upper_x + x, 4.9, 3.84), Vector2(3.8, 2.3), yaw)
	for side: float in [-1.0, 1.0]:
		for z: float in [-3.5, 1.5]:
			_window(origin, Vector3(side * 8.10, 1.75, z), Vector2(2.3, 1.65), yaw, true)
	# Recessed entrance, vertical stone feature and parapet caps give facade scale.
	add_part(origin, Vector3(6.6, 1.55, 6.15), Vector3(1.25, 2.9, 0.24), "timber", yaw)
	add_part(origin, Vector3(6.94, 1.45, 6.29), Vector3(0.045, 0.48, 0.035), "metal", yaw)
	add_part(origin, Vector3(-7.5, 1.65, 6.13), Vector3(0.65, 3.3, 0.30), "stone", yaw)
	for side: float in [-1.0, 1.0]:
		add_part(origin, Vector3(side * 7.9, 3.08, 0), Vector3(0.16, 0.08, 12.1), "charcoal", yaw)
	for x: float in [-4.5, 0.0, 4.5]:
		add_part(origin, Vector3(x, 0.42, 6.20), Vector3(3.85, 0.12, 0.40), "stone", yaw)
	# Timber screen and cantilevered balcony provide depth in the driving view.
	for slat in 10:
		add_part(origin, Vector3(upper_x - 4.5 + slat * 0.21, 4.95, 4.02), Vector3(0.09, 2.9, 0.20), "timber", yaw)
	add_part(origin, Vector3(upper_x, 3.45, 5.20), Vector3(11.1, 0.22, 3.2), "ivory", yaw)
	add_part(origin, Vector3(upper_x, 4.04, 6.70), Vector3(10.7, 1.0, 0.12), "glass", yaw)
	add_part(origin, Vector3(upper_x, 4.57, 6.70), Vector3(11.0, 0.06, 0.08), "charcoal", yaw)
	for x: float in [-5.3, 0.0, 5.3]:
		add_part(origin, Vector3(upper_x + x, 4.02, 6.75), Vector3(0.07, 1.1, 0.08), "charcoal", yaw)
	# Low garden walls begin behind the sidewalk safety strip; entrance stays open.
	for x: float in [-10.3, 10.3]:
		_ground_part(origin, Vector3(x, 0.48, 1.0), Vector3(0.3, 0.96, 17), "stone", yaw, true)
		_ground_part(origin, Vector3(x, 1.00, 1.0), Vector3(0.8, 0.55, 15.5), "hedge", yaw)
	_ground_part(origin, Vector3(5.8, 0.22, 9.0), Vector3(4.3, 0.44, 1.7), "stone", yaw, true)
	_ground_part(origin, Vector3(5.8, 0.50, 9.0), Vector3(4.0, 0.30, 1.5), "hedge", yaw)
	_front_garden(origin, yaw, variant, false)
	_lot_finish(origin, yaw, Vector2(21, 24), variant)
	var tree := origin + Basis(Vector3.UP, yaw) * Vector3(-7.0, 0, 9.0)
	tree.y = Layout.height_at(tree.x, tree.z)
	_garden_tree(tree, 6.5)
	if variant % 3 == 2:
		add_part(origin, Vector3(0, 0.03, -9.0), Vector3(8.5, 0.12, 4.2), "pool", yaw)
		for x: float in [-4.4, 4.4]:
			add_part(origin, Vector3(x, 0.08, -9), Vector3(0.4, 0.15, 4.8), "ivory", yaw)


func _tower(u: float, v: float, yaw: float, floors: int) -> void:
	parcel_count += 1
	var origin := _foundation(u, v, 19, 15, yaw)
	var height := 3.1 * floors + 3.6
	add_part(origin, Vector3(0, height / 2, 0), Vector3(17, height, 13), "ivory", yaw, true)
	add_part(origin, Vector3(-6.5, height / 2, 0.08), Vector3(3.7, height, 13.3), "stone", yaw)
	add_part(origin, Vector3(6.5, height / 2, 0.08), Vector3(1.1, height, 13.3), "charcoal", yaw)
	for floor_index in floors:
		var y := 4.8 + floor_index * 3.1
		for side: float in [-1.0, 1.0]:
			for x: float in [-3.0, 2.1]:
				_window(origin, Vector3(x, y, side * 6.61), Vector2(4.1, 2.1), yaw)
			add_part(origin, Vector3(0, y - 1.35, side * 7.0), Vector3(18.3, 0.20, 2.0), "ivory", yaw)
			add_part(origin, Vector3(0, y - 0.79, side * 7.9), Vector3(16.8, 0.95, 0.12), "glass", yaw)
			add_part(origin, Vector3(0, y - 0.27, side * 7.91), Vector3(17.0, 0.06, 0.08), "charcoal", yaw)
			for x: float in [-7.7, -4.0, 0.0, 4.0, 7.7]:
				add_part(origin, Vector3(x, y - 0.8, side * 7.95), Vector3(0.06, 1.05, 0.08), "charcoal", yaw)
		for side: float in [-1.0, 1.0]:
			for z: float in [-3.6, 2.0]:
				_window(origin, Vector3(side * 8.61, y, z), Vector2(2.7, 1.9), yaw, true)
		add_part(origin, Vector3(0, y + 1.1, 0), Vector3(17.3, 0.14, 13.3), "stone", yaw)
	_window(origin, Vector3(1.5, 1.6, 6.65), Vector2(6.3, 2.9), yaw)
	add_part(origin, Vector3(0, 3.15, 8.4), Vector3(18, 0.35, 4.2), "stone", yaw)
	add_part(origin, Vector3(0, height + 0.22, 0), Vector3(18.4, 0.44, 14.4), "ivory", yaw)
	add_part(origin, Vector3(-3, height + 1.0, -2), Vector3(7, 1.6, 7), "charcoal", yaw)
	for x: float in [-6.5, 6.5]:
		add_part(origin, Vector3(x, height + 0.5, 4.5), Vector3(4.1, 0.65, 2), "hedge", yaw)
	_front_garden(origin, yaw, floors, true)
	_lot_finish(origin, yaw, Vector2(21, 23), floors)


func _service(u: float, v: float) -> void:
	var site := Layout.position(u, v)
	parcels.append({"center": Vector2(site.x, site.z), "yaw": PI / 2, "size": Vector2(22, 28), "kind": "workshop"})
	parcel_count += 1
	var origin := _foundation(u, v, 20, 13, PI / 2)
	add_part(origin, Vector3(0, 2.3, 0), Vector3(19, 4.6, 12), "stone", PI / 2, true)
	for x: float in [-5.5, 0.0, 5.5]:
		_window(origin, Vector3(x, 2.0, 6.1), Vector2(4.7, 3.4), PI / 2)
	add_part(origin, Vector3(0, 4.4, 7), Vector3(21, 0.28, 4), "charcoal", PI / 2)
	for side: float in [-1.0, 1.0]:
		add_part(origin, Vector3(side * 9, 2.0, 8.5), Vector3(0.15, 4, 0.15), "charcoal", PI / 2, true)


func _front_garden(origin: Vector3, yaw: float, variant: int, tower: bool) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var entrance := origin + basis * Vector3(0, 0, 10.4)
	var nearest := Vector3.ZERO
	var distance := INF
	var road_width := 10.0
	for street in street_samples:
		for p: Vector3 in street.points:
			var delta := p.distance_squared_to(entrance)
			if delta < distance:
				distance = delta
				nearest = p
				road_width = street.width
	var direction := (nearest - entrance).normalized()
	var end := nearest - direction * (road_width / 2 + 0.4)
	var start := origin + basis * Vector3(0, 0, 6.8)
	_add_driveway(start, end, 2.1)
	# All new solid details stay inside the lot envelope checked by _safe_site.
	for side: float in [-1, 1]:
		_ground_part(origin, Vector3(side * 7.2, 0.48, 10.2), Vector3(5.5, 0.95, 0.25), "stone", yaw)
		for slat in 14:
			_ground_part(origin, Vector3(side * 7.2 - 2.5 + slat * 0.38, 1.02, 10.2), Vector3(0.05, 0.92, 0.07), "charcoal", yaw)
		_ground_part(origin, Vector3(side * 4.3, 1.0, 10.2), Vector3(0.38, 2.0, 0.38), "stone", yaw)
		_ground_part(origin, Vector3(side * 4.3, 1.65, 10.42), Vector3(0.18, 0.28, 0.06), "light", yaw, false)
	var address := origin + basis * Vector3(4.31, 1.02, 10.43)
	_address(str(140 + variant * 12 + int(absf(origin.x)) % 20), address, yaw)
	_ground_part(origin, Vector3(-4.3, 0.94, 10.48), Vector3(0.29, 0.18, 0.16), "charcoal", yaw)
	_ground_part(origin, Vector3(-4.3, 0.98, 10.57), Vector3(0.19, 0.022, 0.015), "metal", yaw)
	if not tower:
		for z: float in [-3.4, -1.4, 0.6]:
			add_part(origin, Vector3(8.14, 2.6, z), Vector3(0.26, 0.42, 0.78), "ivory", yaw)
			for rib in 5:
				add_part(origin, Vector3(8.29, 2.43 + rib * 0.072, z), Vector3(0.03, 0.025, 0.64), "charcoal", yaw)
		for side: float in [-1, 1]:
			_ground_part(origin, Vector3(side * 5.5, 0.32, 8.6), Vector3(0.75, 0.64, 0.75), "stone", yaw)
			var plant := origin + basis * Vector3(side * 5.5, 0, 8.6)
			plant.y = Layout.height_at(plant.x, plant.z) + 0.88
			add_instance("foliage", "hedge", plant, Vector3(0.62, 0.6, 0.62), yaw)


func _address(number: String, position: Vector3, yaw: float) -> void:
	position.y = Layout.height_at(position.x, position.z) + 1.04
	var text := TextMesh.new()
	text.text = number
	text.font_size = 32
	text.pixel_size = 0.006
	text.depth = 0.006
	var transform := Transform3D(Basis(Vector3.UP, yaw), position)
	for point in text.get_faces():
		address_faces.append(transform * point)
	var marker := Node3D.new()
	marker.name = "Address%d" % scene_root.get_child_count()
	marker.transform = transform
	marker.set_meta("number", number)
	scene_root.add_child(marker)


func _tree_palette() -> void:
	for item in ["tree_bark", "tree_leaves"]:
		var material := StandardMaterial3D.new()
		material.resource_name = item
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		if item == "tree_leaves":
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.albedo_texture = load("res://assets/textures/neighborhood/leaf-cluster-v1.png")
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.45
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		materials[item] = material
	for variant in 3:
		var tree: Dictionary = preload("res://scripts/city/neighborhood_tree_mesh.gd").new().build(variant)
		meshes["tree_bark%d" % variant] = tree.bark
		meshes["tree_leaves%d" % variant] = tree.leaves


func _garden_tree(position: Vector3, height: float, solid: bool = true) -> void:
	if solid:
		_projected_patch("TreeShade", position, Vector2(height * 0.50, height * 0.50), "grass", 0.008, true)
	var variant := int(absf(position.x * 1.17 + position.z * 0.79)) % 3
	var shape_variation := int(absf(position.z * 0.43)) % 5
	var yaw := fposmod(position.x * 1.73 + position.z * 0.81, TAU)
	var scale := Vector3(height * (0.82 + 0.07 * shape_variation), height, height * (1.13 - 0.06 * shape_variation))
	add_instance("tree_bark%d" % variant, "tree_bark", position, scale, yaw)
	add_instance("tree_leaves%d" % variant, "tree_leaves", position, scale, yaw)
	# Preserve the prior trunk's physical envelope; leaves do not obstruct driving.
	if solid:
		add_collision(position + Vector3.UP * 1.2, Vector3(0.4, 2.4, 0.4))
	tree_count += 1


func _street_life() -> void:
	for edge in Layout.edges():
		var points := Layout.edge_points(edge.a, edge.b)
		for fraction: float in [0.18, 0.67]:
			var index := floori((points.size() - 1) * fraction)
			var p := points[index]
			var normal := (points[index + 1] - points[index - 1]).cross(Vector3.UP).normalized()
			for side: float in [-1.0, 1.0]:
				var origin := p + normal * side * (float(edge.width) / 2 + 4.2)
				origin.y = Layout.height_at(origin.x, origin.z)
				if fraction < 0.2:
					_garden_tree(origin, 7.5)
				else:
					var drain := p + normal * side * (float(edge.width) / 2 - 0.35)
					drain.y = Layout.height_at(drain.x, drain.z) + 0.034
					var yaw := atan2(-normal.z, normal.x)
					add_box(drain, Vector3(0.55, 0.012, 0.85), "charcoal", false, yaw, false)
					for rib in 6:
						add_part(drain, Vector3(0, 0.010, -0.33 + rib * 0.13), Vector3(0.52, 0.012, 0.025), "metal", yaw)
					add_instance("cylinder", "charcoal", origin + Vector3.UP * 3.5, Vector3(0.09, 7, 0.09))
					add_box(origin + Vector3.UP * 6.9 - normal * side * 0.8, Vector3(1.8, 0.08, 0.18), "charcoal")
					add_box(origin + Vector3.UP * 6.84 - normal * side * 1.5, Vector3(0.45, 0.05, 0.22), "light", false, 0, false)
					var lamp := Marker3D.new()
					lamp.name = "StreetLamp%d" % scene_root.get_child_count()
					lamp.position = origin + Vector3.UP * 6.75 - normal * side * 1.5
					scene_root.add_child(lamp)
					add_collision(origin + Vector3.UP, Vector3(0.18, 2, 0.18))


func _landscape() -> void:
	var faces := PackedVector3Array()
	for z in range(-880, 880, 16):
		for x in range(-1024, 1024, 16):
			if x >= -Layout.HALF_WIDTH and x + 16 <= Layout.HALF_WIDTH and z >= -Layout.HALF_DEPTH and z + 16 <= Layout.HALF_DEPTH:
				continue
			var a := Vector3(x, _land_height(x, z), z)
			var b := Vector3(x + 16, _land_height(x + 16, z), z)
			var c := Vector3(x, _land_height(x, z + 16), z + 16)
			var d := Vector3(x + 16, _land_height(x + 16, z + 16), z + 16)
			_background_triangle(faces, [a, c, b])
			_background_triangle(faces, [b, c, d])
	_mesh("BackgroundLandscape", faces, "grass", 0.045)
	for side: float in [-1.0, 1.0]:
		for index in 26:
			var p := Vector3(-Layout.HALF_WIDTH + 70 + index * 56.0, 0, side * (Layout.HALF_DEPTH - 55 + 8 * sin(index)))
			p.y = Layout.height_at(p.x, p.z)
			_garden_tree(p, 10.0 + (index % 3))
		for index in 20:
			var p := Vector3(side * (Layout.HALF_WIDTH - 55), 0, -Layout.HALF_DEPTH + 70 + index * 57.0)
			p.y = Layout.height_at(p.x, p.z)
			_garden_tree(p, 9.0 + (index % 3))

	for group in 12:
		var angle := TAU * group / 12.0
		var center := Vector3(cos(angle) * 850, 0, sin(angle) * 700)
		for index in 7:
			var offset := Vector3(cos(index * 2.4 + group) * (9 + index * 2.8), 0, sin(index * 2.4 + group) * (8 + index * 2.1))
			var point := center + offset
			point.y = _land_height(point.x, point.z)
			_garden_tree(point, 12.0 + (index + group) % 5, false)
	# A low-detail neighboring skyline sits beyond the playable boundary.
	for index in 22:
		var x := -700.0 + index * 66.0
		var z := -690.0 - 38.0 * sin(index * 1.73)
		var position := Vector3(x, _land_height(x, z), z)
		var width := 12.0 + index % 4 * 3.0
		var height := 7.0 + index % 5 * 3.3
		add_box(position + Vector3.UP * height / 2, Vector3(width, height, 13), "skyline", false)
		add_box(position + Vector3.UP * (height + 0.2), Vector3(width + 0.7, 0.4, 14), "skyline_roof", false)
		for floor_index in int(height / 3):
			for window in 4:
				add_box(position + Vector3(-width * 0.35 + window * width * 0.23, 1.9 + floor_index * 3, 6.55), Vector3(1.6, 1.6, 0.1), "skyline_glass", false, 0, false)


func _land_height(x: float, z: float) -> float:
	var outside := maxf(maxf(absf(x) - Layout.HALF_WIDTH, absf(z) - Layout.HALF_DEPTH), 0)
	var hills := 37.0 * exp(-pow((x + 370) / 175, 2) - pow((z - 80) / 240, 2))
	hills += 48.0 * exp(-pow((x - 390) / 200, 2) - pow((z + 290) / 190, 2))
	hills += 32.0 * exp(-pow((x + 30) / 200, 2) - pow((z + 400) / 150, 2))
	return Layout.height_at(x, z) + smoothstep(0.0, 110.0, outside) * (hills + 3 * sin(x / 70) * sin(z / 110))


func _safe_site(initial: Vector2, interior: Vector2, yaw: float, footprint: Vector2) -> Vector2:
	# Search setback and frontage together; avoid neighboring parcels as well as roads.
	var inverse := Basis(Vector3.UP, yaw).inverse()
	var lateral := Vector2(cos(yaw), -sin(yaw))
	for attempt in 26:
		for shift: float in [0.0, 3.0, -3.0, 6.0, -6.0, 9.0, -9.0]:
			var uv := initial.lerp(interior, float(attempt) * 0.032) + lateral * shift
			var origin := Layout.position(uv.x, uv.y)
			if _parcel_overlaps(origin, yaw, footprint):
				continue
			var clear := true
			for street in street_samples:
				for point: Vector3 in street.points:
					if absf(point.x - origin.x) > footprint.length() + 15 or absf(point.z - origin.z) > footprint.length() + 15:
						continue
					var local := inverse * (point - origin)
					var distance := Vector2(maxf(absf(local.x) - footprint.x / 2, 0), maxf(absf(local.z) - footprint.y / 2, 0)).length()
					if distance < float(street.width) / 2 + 5.5:
						clear = false
						break
				if not clear:
					break
			if clear:
				parcels.append({"center": Vector2(origin.x, origin.z), "yaw": yaw, "size": footprint})
				return uv
	# A tight frontage becomes a garden instead of forcing overlapping buildings.
	garden_frontages += 1
	return Vector2.INF


func _outer_frontages() -> void:
	# Complete the opposite side of the existing streets without adding blocks.
	var frontages: Array[Dictionary] = []
	for row in [0, Layout.ROW_COUNT - 1]:
		for column in Layout.COLUMN_COUNT - 1:
			frontages.append({"a": row * Layout.COLUMN_COUNT + column, "b": row * Layout.COLUMN_COUNT + column + 1, "side": -1.0 if row == 0 else 1.0})
	for column in [0, Layout.COLUMN_COUNT - 1]:
		for row in Layout.ROW_COUNT - 1:
			frontages.append({"a": row * Layout.COLUMN_COUNT + column, "b": (row + 1) * Layout.COLUMN_COUNT + column, "side": 1.0 if column == 0 else -1.0})
	for frontage in frontages:
		for step in 3:
			var t := 0.23 + step * 0.27
			var uv := Layout.street_uv(frontage.a, frontage.b, t)
			var tangent := (Layout.street_uv(frontage.a, frontage.b, t + 0.001) - Layout.street_uv(frontage.a, frontage.b, t - 0.001)).normalized()
			var outward := Vector2(-tangent.y, tangent.x) * float(frontage.side)
			var lot := uv + outward * (25.0 + 2.0 * sin(frontage.a + step * 2.4))
			var forward := Layout.position(uv.x + tangent.x, uv.y + tangent.y) - Layout.position(uv.x, uv.y)
			var yaw := atan2(-forward.z, forward.x) + (PI if float(frontage.side) > 0 else 0.0)
			lot = _safe_site(lot, lot + outward * 12, yaw, Vector2(15.5, 18.5))
			if not lot.is_finite():
				continue
			_cottage(lot.x, lot.y, yaw, (frontage.a + step) % 5)


func _cottage(u: float, v: float, yaw: float, variant: int) -> void:
	parcel_count += 1
	var origin := _foundation(u, v, 12.0, 9.0, yaw)
	var wall: String = ["ivory", "sage", "cream", "stone", "rose"][variant]
	var height := 3.4 if variant % 2 == 0 else 6.4
	add_part(origin, Vector3(0, height / 2, 0), Vector3(11.5, height, 8.5), wall, yaw, true)
	add_part(origin, Vector3(0, height + 0.09, 0), Vector3(12.4, 0.18, 9.3), "ivory", yaw)
	if variant in [1, 2, 4]:
		add_part(origin, Vector3(0, height + 0.95, 0), Vector3(12.2, 1.8, 9.1), "roof", yaw, false, "roof")
		for side: float in [-1, 1]:
			add_part(origin, Vector3(side * 6.05, height + 0.05, 0), Vector3(0.12, 0.12, 9.2), "charcoal", yaw)
	else:
		for side: float in [-1, 1]:
			add_part(origin, Vector3(side * 5.9, height + 0.38, 0), Vector3(0.22, 0.6, 9.2), wall, yaw)
		add_part(origin, Vector3(0, height + 0.8, -2), Vector3(2.5, 1.4, 2.5), "stone", yaw)
	for floor_index in (2 if height > 4 else 1):
		for x: float in [-3.4, 1.2]:
			_window(origin, Vector3(x, 1.75 + floor_index * 3, 4.34), Vector2(2.4, 1.55), yaw)
			add_part(origin, Vector3(x, 0.89 + floor_index * 3, 4.48), Vector3(2.65, 0.1, 0.35), "stone", yaw)
		for side: float in [-1, 1]:
			_window(origin, Vector3(side * 5.84, 1.8 + floor_index * 3, -1.0), Vector2(2.1, 1.5), yaw, true)
	add_part(origin, Vector3(4.0, 1.4, 4.37), Vector3(1.2, 2.8, 0.18), "timber", yaw)
	add_part(origin, Vector3(4.0, 2.9, 5.0), Vector3(2.5, 0.16, 1.8), "charcoal", yaw)
	for side: float in [-1, 1]:
		_ground_part(origin, Vector3(side * 7.2, 0.55, 0), Vector3(0.25, 1.1, 17.5), "stone", yaw, true)
		_ground_part(origin, Vector3(side * 4.6, 0.5, 8.4), Vector3(4.4, 1.0, 0.25), wall, yaw, true)
		_ground_part(origin, Vector3(side * 2.4, 0.85, 8.4), Vector3(0.34, 1.7, 0.34), "stone", yaw)
	_address(str(200 + parcel_count * 2), origin + Basis(Vector3.UP, yaw) * Vector3(2.42, 1.0, 8.6), yaw)
	# A separate approach follows the same exact terrain as the larger homes.
	var entrance := origin + Basis(Vector3.UP, yaw) * Vector3(0, 0, 4.6)
	var closest := Vector3.ZERO
	var nearest := INF
	var width := 12.0
	for street in street_samples:
		for point: Vector3 in street.points:
			if entrance.distance_squared_to(point) < nearest:
				nearest = entrance.distance_squared_to(point)
				closest = point
				width = street.width
	var end := closest + (entrance - closest).normalized() * (width / 2 + 0.5)
	_add_driveway(entrance, end, 1.8)
	_lot_finish(origin, yaw, Vector2(14, 18), variant)
	var tree := origin + Basis(Vector3.UP, yaw) * Vector3(-5, 0, 6.3)
	tree.y = Layout.height_at(tree.x, tree.z)
	_garden_tree(tree, 5.8 + variant * 0.3)


func _lot_finish(origin: Vector3, yaw: float, size: Vector2, variant: int) -> void:
	# Paths, planting and parked cars remain within each parcel's safety envelope.
	var basis := Basis(Vector3.UP, yaw)
	for side: float in [-1, 1]:
		for index in 3:
			var position := origin + basis * Vector3(side * (size.x / 2 - 1.1), 0, -size.y / 2 + 2.5 + index * 3.0)
			position.y = Layout.height_at(position.x, position.z)
			add_instance("foliage", "hedge", position + Vector3.UP * 0.55, Vector3(0.8, 0.6, 1.1), yaw)
	if size.x > 18:
		var parking := origin + basis * Vector3(4.2, 0, -9.4)
		_projected_patch("GardenTerrace", parking, Vector2(8.0, 4.0), "paving", 0.04)
		if variant % 2 == 0:
			_parked_car(parking, yaw + PI / 2, variant)
	else:
		var parking := origin + basis * Vector3(3.5, 0, 6.4)
		if variant % 3 == 0:
			_parked_car(parking, yaw, variant)


func _parked_car(position: Vector3, yaw: float, variant: int) -> void:
	parked_count += 1
	var vehicle := Node3D.new()
	vehicle.name = "ParkedVehicle%d" % parked_count
	vehicle.position = Vector3(position.x, Layout.height_at(position.x, position.z) + 0.38, position.z)
	vehicle.rotation.y = yaw
	scene_root.add_child(vehicle)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.position.y = 0.06
	body.mesh = load("res://assets/models/hatch_1000/body.tres")
	for surface in body.mesh.get_surface_count():
		var source := body.mesh.surface_get_material(surface) as StandardMaterial3D
		if source.resource_name == "Hatch1000_paint":
			var paint: StandardMaterial3D = source.duplicate()
			paint.vertex_color_use_as_albedo = false
			paint.albedo_color = [Color("b8c0c3"), Color("79383b"), Color("d9d3c0")][variant % 3]
			body.set_surface_override_material(surface, paint)
	body.visibility_range_end = 95
	vehicle.add_child(body)
	for x: float in [-0.77, 0.77]:
		for z: float in [-1.13, 1.13]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel%s%s" % ["Left" if x < 0 else "Right", "Front" if z < 0 else "Rear"]
			wheel.mesh = load("res://assets/models/hatch_1000/wheel.tres")
			wheel.position = Vector3(x, -0.04, z)
			wheel.rotation.z = PI / 2
			wheel.visibility_range_end = 95
			vehicle.add_child(wheel)
	add_collision(vehicle.position + Vector3.UP * 0.3, Vector3(1.8, 1.2, 4.0), yaw)


func _block_gardens(u: float, v: float, id: int) -> void:
	if id in Layout.PARK_BLOCKS or id == Layout.WORKSHOP_BLOCK:
		return
	# Small shared gardens fill the interior; they do not close the street approaches.
	var center := Layout.position(u, v)
	_projected_patch("GardenWalk", center, Vector2(22, 4), "paving", 0.038)
	for side: float in [-1, 1]:
		for step in 3:
			var point := Layout.position(u + side * (9 + step * 3 + 3 * sin(id)), v + (6 + id % 5) * sin(step * 1.4 + id))
			add_instance("foliage", "hedge", point + Vector3.UP * 0.5, Vector3(1.2 + id % 3 * 0.3, 0.45 + id % 4 * 0.1, 1.2), step * 0.7)
			if step == 1:
				_garden_tree(point, 6.5 + id % 4)
		var bench := Layout.position(u + side * 7, v + 2.2)
		add_box(bench + Vector3.UP * 0.5, Vector3(2.2, 0.12, 0.65), "timber", true)
		add_box(bench + Vector3(0, 0.82, 0.28), Vector3(2.2, 0.65, 0.08), "charcoal")


func _settle_markings() -> void:
	# Road ribbons span several terrain triangles. Project paint onto the saved
	# road/sidewalk planes rather than a second terrain approximation.
	var tiles: Dictionary = {}
	var support := road_faces.duplicate()
	support.append_array(sidewalk_faces)
	for index in range(0, support.size(), 3):
		var a := support[index]
		var b := support[index + 1]
		var c := support[index + 2]
		var minimum := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var maximum := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		for x in range(floori(minimum.x / 8), floori(maximum.x / 8) + 1):
			for z in range(floori(minimum.y / 8), floori(maximum.y / 8) + 1):
				var key := Vector2i(x, z)
				if not tiles.has(key):
					tiles[key] = []
				tiles[key].append(index)
	var projected := PackedVector3Array()
	for index in range(0, paint_faces.size(), 3):
		var triangle: Array[Vector3] = [paint_faces[index], paint_faces[index + 1], paint_faces[index + 2]]
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for p in triangle:
			minimum = minimum.min(Vector2(p.x, p.z))
			maximum = maximum.max(Vector2(p.x, p.z))
		var candidates: Dictionary = {}
		for x in range(floori(minimum.x / 8), floori(maximum.x / 8) + 1):
			for z in range(floori(minimum.y / 8), floori(maximum.y / 8) + 1):
				for face: int in tiles.get(Vector2i(x, z), []):
					candidates[face] = true
		for face: int in candidates:
			var a := support[face]
			var b := support[face + 1]
			var c := support[face + 2]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var ac := Vector2(c.x - a.x, c.z - a.z)
			var determinant := ab.cross(ac)
			if absf(determinant) < 0.000001:
				continue
			var polygon: Array[Vector3] = triangle.duplicate()
			for edge in [[a, b], [b, c], [c, a]]:
				polygon = _clip_plane(polygon, edge[0], edge[1], signf(determinant))
			for vertex in polygon.size():
				var p := polygon[vertex]
				var ap := Vector2(p.x - a.x, p.z - a.z)
				var u := ap.cross(ac) / determinant
				var v := ab.cross(ap) / determinant
				p.y = a.y + (b.y - a.y) * u + (c.y - a.y) * v + 0.008
				polygon[vertex] = p
			for corner in range(1, polygon.size() - 1):
				_triangle(projected, polygon[0], polygon[corner], polygon[corner + 1])
	paint_faces = projected


func _clip_plane(polygon: Array[Vector3], start: Vector3, end: Vector3, winding: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var edge := Vector2(end.x - start.x, end.z - start.z)
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var da := edge.cross(Vector2(a.x - start.x, a.z - start.z)) * winding
		var db := edge.cross(Vector2(b.x - start.x, b.z - start.z)) * winding
		if da >= -0.000001:
			result.append(a)
		if (da >= 0) != (db >= 0) and absf(da - db) > 0.000001:
			result.append(a.lerp(b, clampf(da / (da - db), 0, 1)))
	return result


func _add_driveway(start: Vector3, end: Vector3, width: float) -> void:
	driveway_connections.append({"a": Vector2(start.x, start.z), "b": Vector2(end.x, end.z), "width": width})
	var steps := maxi(1, ceili(start.distance_to(end) / 2))
	for index in steps:
		_ribbon(driveway_faces, start.lerp(end, float(index) / steps), start.lerp(end, float(index + 1) / steps), -width, width, 0.04)


func _index_field(tiles: Dictionary, item: Dictionary, reach: float) -> void:
	var a: Vector2 = item.a
	var b: Vector2 = item.b
	var minimum := a.min(b) - Vector2.ONE * reach
	var maximum := a.max(b) + Vector2.ONE * reach
	for x in range(floori(minimum.x / 16), floori(maximum.x / 16) + 1):
		for z in range(floori(minimum.y / 16), floori(maximum.y / 16) + 1):
			var key := Vector2i(x, z)
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(item)


func _prepare_distance_field() -> void:
	for street in street_samples:
		for index in street.points.size() - 1:
			var a: Vector3 = street.points[index]
			var b: Vector3 = street.points[index + 1]
			_index_field(road_tiles, {"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "width": float(street.width) / 2, "junction": false}, float(street.width) / 2 + 4.0)
	for id in Layout.NODE_COUNT:
		var p := Layout.node(id)
		_index_field(road_tiles, {"a": Vector2(p.x, p.z), "b": Vector2(p.x, p.z), "width": 11.5, "junction": true}, 19.0)
	for access in [Layout.square_access(), Layout.workshop_access()]:
		for index in access.size() - 1:
			var a: Vector3 = access[index]
			var b: Vector3 = access[index + 1]
			_index_field(road_tiles, {"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "width": 3.5, "junction": false}, 7.5)
	for connection in driveway_connections:
		_index_field(ramp_tiles, connection, connection.width + 3.0)


func _road_distance(point: Vector2) -> float:
	var nearest := 32.0
	for item: Dictionary in road_tiles.get(Vector2i(floori(point.x / 16), floori(point.y / 16)), []):
		var a: Vector2 = item.a
		var b: Vector2 = item.b
		var closest := a if a == b else Geometry2D.get_closest_point_to_segment(point, a, b)
		nearest = minf(nearest, point.distance_to(closest) - float(item.width))
	return nearest


func _ramp_factor(point: Vector2) -> float:
	var key := Vector2i(floori(point.x / 16), floori(point.y / 16))
	var factor := 1.0
	for connection: Dictionary in ramp_tiles.get(key, []):
		var closest := Geometry2D.get_closest_point_to_segment(point, connection.a, connection.b)
		factor = minf(factor, smoothstep(connection.width + 0.2, connection.width + 2.0, point.distance_to(closest)))
	for item: Dictionary in road_tiles.get(key, []):
		if item.junction:
			factor = minf(factor, smoothstep(13.0, 18.0, point.distance_to(item.a)))
	return factor


func _joined_sidewalks() -> void:
	# One signed distance field unites street edges, corners and accessible ramps.
	# Its one-metre cells share the same diagonal as the four-metre terrain.
	var samples: Dictionary = {}
	for key: Vector2i in road_tiles:
		for x in range(key.x * 16, key.x * 16 + 16):
			for z in range(key.y * 16, key.y * 16 + 16):
				var points: Array[Vector3] = []
				for corner: Vector2i in [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1)]:
					if not samples.has(corner):
						samples[corner] = _road_distance(Vector2(corner))
					points.append(Vector3(corner.x, samples[corner], corner.y))
				for triangle: Array in [[points[0], points[1], points[2]], [points[1], points[3], points[2]]]:
					var minimum: float = minf(triangle[0].y, minf(triangle[1].y, triangle[2].y))
					var maximum: float = maxf(triangle[0].y, maxf(triangle[1].y, triangle[2].y))
					if minimum >= 3.0 or maximum <= 0.0:
						continue
					for band: Vector2 in [Vector2(0, 0.6), Vector2(0.6, 2.7), Vector2(2.7, 3.0)]:
						var polygon: Array[Vector3] = []
						polygon.assign(triangle)
						polygon = _clip(polygon, 1, band.x, true)
						polygon = _clip(polygon, 1, band.y, false)
						for index in range(1, polygon.size() - 1):
							_triangle(sidewalk_faces, _sidewalk_point(polygon[0]), _sidewalk_point(polygon[index]), _sidewalk_point(polygon[index + 1]))


func _sidewalk_point(point: Vector3) -> Vector3:
	var lift := 0.12
	if point.y < 0.6:
		lift = lerpf(Layout.ROAD_LIFT, 0.12, point.y / 0.6)
	elif point.y > 2.7:
		lift = lerpf(0.12, Layout.ROAD_LIFT, (point.y - 2.7) / 0.3)
	lift = lerpf(Layout.ROAD_LIFT, lift, _ramp_factor(Vector2(point.x, point.z)))
	return Vector3(point.x, Layout.height_at(point.x, point.z) + lift, point.z)


func _background_triangle(faces: PackedVector3Array, triangle: Array) -> void:
	var polygon: Array[Vector3] = []
	polygon.assign(triangle)
	var sections: Array = [_clip(polygon, 0, -Layout.HALF_WIDTH, false), _clip(polygon, 0, Layout.HALF_WIDTH, true)]
	var middle := _clip(_clip(polygon, 0, -Layout.HALF_WIDTH, true), 0, Layout.HALF_WIDTH, false)
	sections.append(_clip(middle, 2, -Layout.HALF_DEPTH, false))
	sections.append(_clip(middle, 2, Layout.HALF_DEPTH, true))
	for section: Array in sections:
		for index in range(1, section.size() - 1):
			var points: Array[Vector3] = [section[0], section[index], section[index + 1]]
			for point_index in 3:
				points[point_index].y = _land_height(points[point_index].x, points[point_index].z)
			_triangle(faces, points[0], points[1], points[2])


func _parcel_overlaps(origin: Vector3, yaw: float, size: Vector2) -> bool:
	var center := Vector2(origin.x, origin.z)
	var axes: Array[Vector2] = [Vector2(cos(yaw), -sin(yaw)), Vector2(sin(yaw), cos(yaw))]
	for parcel in parcels:
		var other: Vector2 = parcel.center
		if center.distance_to(other) > size.length() + Vector2(parcel.size).length():
			continue
		var other_axes: Array[Vector2] = [Vector2(cos(parcel.yaw), -sin(parcel.yaw)), Vector2(sin(parcel.yaw), cos(parcel.yaw))]
		var separated := false
		for axis: Vector2 in [axes[0], axes[1], other_axes[0], other_axes[1]]:
			var radius := absf(axis.dot(axes[0])) * size.x / 2 + absf(axis.dot(axes[1])) * size.y / 2
			var other_radius: float = absf(axis.dot(other_axes[0])) * parcel.size.x / 2 + absf(axis.dot(other_axes[1])) * parcel.size.y / 2
			if absf((center - other).dot(axis)) > radius + other_radius + 1.2:
				separated = true
				break
		if not separated:
			return true
	return false


func _meadow_grass() -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "wild_grass"
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = 1.0
	materials["wild_grass"] = material
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 3:
		var basis := Basis(Vector3.UP, blade * PI / 3)
		for point: Vector3 in [Vector3(-0.12, 0, 0), Vector3(0.08, 0.9, 0.05), Vector3(0.12, 0, 0)]:
			tool.set_normal(basis * Vector3.FORWARD)
			tool.set_color(Color("5e783c") if point.y < 0.1 else Color("899556"))
			tool.add_vertex(basis * point)
	tool.index()
	meshes["grass_blades"] = tool.commit()
	var random := RandomNumberGenerator.new()
	random.seed = 90418
	for cluster in 2400:
		var center := Vector2(random.randf_range(-Layout.HALF_WIDTH + 20, Layout.HALF_WIDTH - 20), random.randf_range(-Layout.HALF_DEPTH + 20, Layout.HALF_DEPTH - 20))
		if _road_distance(center) < 5.0:
			continue
		var occupied := false
		for parcel in parcels:
			var local := Vector2(cos(parcel.yaw), -sin(parcel.yaw))
			var across := Vector2(sin(parcel.yaw), cos(parcel.yaw))
			var offset: Vector2 = center - parcel.center
			if absf(offset.dot(local)) < parcel.size.x / 2 + 4 and absf(offset.dot(across)) < parcel.size.y / 2 + 4:
				occupied = true
				break
		if occupied:
			continue
		if cluster % 13 == 0:
			var rock := Vector3(center.x, Layout.height_at(center.x, center.y), center.y)
			add_instance("foliage", "stone", rock + Vector3.UP * 0.14, Vector3(0.7, 0.23, 0.45), random.randf_range(0, TAU), false)
		if cluster % 7 == 0:
			for flower in 5:
				var spot := center + Vector2(random.randf_range(-1, 1), random.randf_range(-1, 1))
				var foot := Vector3(spot.x, Layout.height_at(spot.x, spot.y), spot.y)
				add_instance("foliage", "flower", foot + Vector3.UP * 0.23, Vector3(0.12, 0.1, 0.12), 0, false)
		for tuft in 22:
			var point := center + Vector2(random.randf_range(-3, 3), random.randf_range(-3, 3))
			if _road_distance(point) < 3.5:
				continue
			var position := Vector3(point.x, Layout.height_at(point.x, point.y), point.y)
			var size := random.randf_range(0.18, 0.38)
			add_instance("grass_blades", "wild_grass", position, Vector3.ONE * size, random.randf_range(0, TAU), false)
			grass_count += 1


func _ground_part(origin: Vector3, offset: Vector3, size: Vector3, material: String, yaw: float, solid: bool = false) -> void:
	var axis := 0 if size.x > size.z else 2
	var steps := maxi(1, ceili(size[axis] / 2.0))
	var basis := Basis(Vector3.UP, yaw)
	for index in steps:
		var part_size := size
		part_size[axis] /= steps
		var part_offset := offset
		part_offset[axis] += -size[axis] / 2 + part_size[axis] * (index + 0.5)
		var center := origin + basis * Vector3(part_offset.x, 0, part_offset.z)
		var high := Layout.height_at(center.x, center.z)
		var low := high
		for dx: float in [-part_size.x / 2, part_size.x / 2]:
			for dz: float in [-part_size.z / 2, part_size.z / 2]:
				var corner := center + basis * Vector3(dx, 0, dz)
				high = maxf(high, Layout.height_at(corner.x, corner.z))
				low = minf(low, Layout.height_at(corner.x, corner.z))
		center.y = (high + low) / 2 + part_offset.y
		part_size.y += high - low + 0.025
		add_box(center, part_size, material, solid, yaw)
