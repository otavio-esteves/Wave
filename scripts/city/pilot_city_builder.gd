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


func build_city() -> Node3D:
	batch_size = 112.0
	begin("PilotCity", "Colliders")
	_palette()
	_premium_palette()
	_tree_palette()
	tree_count = 0
	road_faces.clear()
	sidewalk_faces.clear()
	paint_faces.clear()
	driveway_faces.clear()
	address_faces.clear()
	sites_valid = true
	street_samples.clear()
	for edge in Layout.edges():
		street_samples.append({"points": Layout.edge_points(edge.a, edge.b), "width": edge.width})
	var ground := Layout.terrain_faces()
	_mesh("Terrain", ground, "grass", 0.075)
	_support("Terrain", ground)
	for edge in Layout.edges():
		_street(edge)
	for id in 12:
		_junction(Layout.node(id))
	_blocks()
	for access in [Layout.square_access(), Layout.workshop_access()]:
		for index in access.size() - 1:
			_ribbon(road_faces, access[index], access[index + 1], -3.5, 3.5, Layout.ROAD_LIFT)
	_mesh("Streets", road_faces, "asphalt", 0.25)
	_mesh("Sidewalks", sidewalk_faces, "sidewalk", 0.18)
	_mesh("RoadMarkings", paint_faces, "white", 1.0)
	_support("Streets", road_faces)
	_support("Sidewalks", sidewalk_faces)
	_mesh("LotDriveways", driveway_faces, "paving", 0.25)
	_mesh("HouseNumbers", address_faces, "charcoal", 1.0)
	_street_life()
	_boundary()
	_landscape()
	var city := finish()
	for child in city.get_children():
		if child is MultiMeshInstance3D and child.material_override.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			child.multimesh.billboard_radius = 6.0
	city.set_meta("block_count", Layout.BLOCK_COUNT)
	city.set_meta("planned_block_count", Layout.PLANNED_BLOCK_COUNT)
	city.set_meta("generator_version", 4)
	city.set_meta("volumetric_tree_count", tree_count)
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
		error = ResourceSaver.save(packed, output)
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
		var driveway := absf(float(index) / (points.size() - 1) - 0.5) < 0.055
		if not in_crossing and not driveway:
			for side: float in [-1.0, 1.0]:
				_band(sidewalk_faces, points, index, side * half, side * (half + 0.6), Layout.ROAD_LIFT, 0.12, true)
				_band(sidewalk_faces, points, index, side * (half + 0.6), side * (half + 2.7), 0.12, NAN, true)
				_band(sidewalk_faces, points, index, side * (half + 2.7), side * (half + 3.0), 0.12, Layout.ROAD_LIFT, true)
				_band(paint_faces, points, index, side * (half + 0.62), side * (half + 0.72), 0.123, NAN, true)
		if not in_crossing and index % 5 < 2:
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
	faces.append_array(PackedVector3Array([a, c, b] if (b - a).cross(c - a).y > 0.0 else [a, b, c]))


func _junction(center: Vector3) -> void:
	for index in 24:
		var a := center + Vector3(cos(TAU * index / 24), 0, sin(TAU * index / 24)) * 9.0
		var b := center + Vector3(cos(TAU * (index + 1) / 24), 0, sin(TAU * (index + 1) / 24)) * 9.0
		a.y = Layout.height_at(a.x, a.z) + Layout.ROAD_LIFT
		b.y = Layout.height_at(b.x, b.z) + Layout.ROAD_LIFT
		_triangle(road_faces, center + Vector3.UP * Layout.ROAD_LIFT, a, b)


func _mesh(label: String, faces: PackedVector3Array, material: String, uv_scale: float) -> void:
	var tool := SurfaceTool.new()
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
		tool.set_color(tint)
		tool.add_vertex(point)
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
	for row in 2:
		for column in 3:
			var id := row * 3 + column
			var u: float = (Layout.COLUMNS[column] + Layout.COLUMNS[column + 1]) / 2
			var v: float = (Layout.ROWS[row] + Layout.ROWS[row + 1]) / 2
			var block := Node3D.new()
			block.name = "Block%d" % id
			block.position = Layout.position(u, v)
			block.set_meta("label", Layout.BLOCK_NAMES[id])
			scene_root.add_child(block)
			if id == 3:
				_square(u, v)
			elif id == 5:
				_service(u + 18, v)
				_projected_patch("WorkshopYard", Layout.position(u + 33, v), Vector2(28, 26), "paving", 0.032)
				for offset: float in [-24.0, 24.0]:
					_villa(u - 3, v + offset, 0 if offset > 0 else PI, 2)
			else:
				for side: float in [-1.0, 1.0]:
					var frontage_count := 1 if column in [0, 2] else 2
					for step in frontage_count:
						var street_row := row if side < 0 else row + 1
						var start_id: int = street_row * 4 + column
						var t := 0.5 if frontage_count == 1 else lerpf(0.28, 0.72, float(step))
						var road_uv := Layout.street_uv(start_id, start_id + 1, t)
						var tangent := (Layout.street_uv(start_id, start_id + 1, t + 0.001) - Layout.street_uv(start_id, start_id + 1, t - 0.001)).normalized()
						var lot := road_uv - Vector2(-tangent.y, tangent.x) * side * 23.0
						lot = lot.lerp(Vector2(u, v), 0.20)
						var frontage := Layout.position(lot.x + tangent.x * 0.5, lot.y + tangent.y * 0.5) - Layout.position(lot.x - tangent.x * 0.5, lot.y - tangent.y * 0.5)
						var yaw := atan2(-frontage.z, frontage.x) + (PI if side < 0 else 0.0)
						lot = _safe_site(lot, Vector2(u, v), yaw, Vector2(19, 19) if id == 4 or id == 2 and side > 0 else Vector2(21.5, 24))
						if id == 4 or id == 2 and side > 0:
							_tower(lot.x, lot.y, yaw, 5 + (id + step) % 4)
						else:
							_villa(lot.x, lot.y, yaw, (id + step) % 3)
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


func _projected_patch(label: String, center: Vector3, size: Vector2, material: String, lift: float) -> void:
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
	_mesh(label + str(scene_root.get_child_count()), faces, material, 0.18)


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
		for x in range(-216, 217, 12):
			var z: float = side * 164.0
			add_box(Vector3(x, Layout.height_at(x, z) + 0.6, z), Vector3(12, 1.2, 0.35), "hedge", true)
		for z in range(-156, 157, 12):
			var x: float = side * 218.0
			add_box(Vector3(x, Layout.height_at(x, z) + 0.6, z), Vector3(0.35, 1.2, 12), "hedge", true)


func _premium_palette() -> void:
	for item in [["ivory", "cbcbbf", 0.8], ["stone", "bcb9ad", 0.9], ["charcoal", "333e43", 0.65], ["timber", "8b6850", 0.8], ["hedge", "4b6750", 0.95], ["flower", "baa17c", 0.95], ["pool", "50888c", 0.2]]:
		var material := StandardMaterial3D.new()
		material.resource_name = item[0]
		material.albedo_color = Color(item[1])
		material.roughness = item[2]
		if item[0] in ["ivory", "stone", "timber", "hedge", "flower"]:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		materials[item[0]] = material
	materials["street_tree"].shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	materials["grass"].shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	materials["glass"].albedo_color = Color("698d99")
	materials["glass"].roughness = 0.22
	materials["glass"].metallic = 0.20
	materials["grass"].albedo_color = Color("cbd0bd")
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
	materials["asphalt"].albedo_color = Color("9ea3a5")
	materials["asphalt"].uv1_scale = Vector3.ONE * 2.0
	materials["asphalt"].roughness = 0.92



func _foundation(u: float, v: float, width: float, depth: float, yaw: float) -> Vector3:
	var origin := Layout.position(u, v)
	var high := origin.y
	var low := origin.y
	for dx: float in [-width / 2, width / 2]:
		for dz: float in [-depth / 2, depth / 2]:
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
	var origin := _foundation(u, v, 17, 13, yaw)
	var upper_x := -2.5 if variant % 2 == 0 else 2.5
	add_part(origin, Vector3(0, 1.65, 0), Vector3(16, 3.3, 12), "ivory", yaw, true)
	add_part(origin, Vector3(upper_x, 4.9, -1.0), Vector3(10.5, 3.2, 9.5), "stone" if variant == 1 else "ivory", yaw, true)
	add_part(origin, Vector3(0, 3.35, 0.4), Vector3(17.4, 0.28, 13.2), "ivory", yaw)
	add_part(origin, Vector3(upper_x, 6.6, -1.0), Vector3(11.5, 0.3, 10.5), "charcoal", yaw)
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
		add_part(origin, Vector3(x, 0.48, 1.0), Vector3(0.3, 0.96, 17), "stone", yaw, true)
		add_part(origin, Vector3(x, 1.00, 1.0), Vector3(0.8, 0.55, 15.5), "hedge", yaw)
	add_part(origin, Vector3(5.8, 0.22, 9.0), Vector3(4.3, 0.44, 1.7), "stone", yaw, true)
	add_part(origin, Vector3(5.8, 0.50, 9.0), Vector3(4.0, 0.30, 1.5), "hedge", yaw)
	_front_garden(origin, yaw, variant, false)
	var tree := origin + Basis(Vector3.UP, yaw) * Vector3(-7.0, 0, 9.0)
	tree.y = Layout.height_at(tree.x, tree.z)
	_garden_tree(tree, 6.5)
	if variant == 2:
		add_part(origin, Vector3(0, 0.03, -9.0), Vector3(8.5, 0.12, 4.2), "pool", yaw)
		for x: float in [-4.4, 4.4]:
			add_part(origin, Vector3(x, 0.08, -9), Vector3(0.4, 0.15, 4.8), "ivory", yaw)


func _tower(u: float, v: float, yaw: float, floors: int) -> void:
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


func _service(u: float, v: float) -> void:
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
	var steps := maxi(1, ceili(start.distance_to(end) / 2))
	for index in steps:
		_ribbon(driveway_faces, start.lerp(end, float(index) / steps), start.lerp(end, float(index + 1) / steps), -2.1, 2.1, 0.04)
	# All new solid details stay inside the lot envelope checked by _safe_site.
	for side: float in [-1, 1]:
		add_part(origin, Vector3(side * 7.2, 0.48, 10.2), Vector3(5.5, 0.95, 0.25), "stone", yaw)
		for slat in 14:
			add_part(origin, Vector3(side * 7.2 - 2.5 + slat * 0.38, 1.02, 10.2), Vector3(0.05, 0.92, 0.07), "charcoal", yaw)
		add_part(origin, Vector3(side * 4.3, 1.0, 10.2), Vector3(0.38, 2.0, 0.38), "stone", yaw)
		add_part(origin, Vector3(side * 4.3, 1.65, 10.42), Vector3(0.18, 0.28, 0.06), "light", yaw, false)
	var address := origin + basis * Vector3(4.31, 1.02, 10.43)
	_address(str(140 + variant * 12 + int(absf(origin.x)) % 20), address, yaw)
	add_part(origin, Vector3(-4.3, 0.94, 10.48), Vector3(0.29, 0.18, 0.16), "charcoal", yaw)
	add_part(origin, Vector3(-4.3, 0.98, 10.57), Vector3(0.19, 0.022, 0.015), "metal", yaw)
	if not tower:
		for z: float in [-3.4, -1.4, 0.6]:
			add_part(origin, Vector3(8.14, 2.6, z), Vector3(0.26, 0.42, 0.78), "ivory", yaw)
			for rib in 5:
				add_part(origin, Vector3(8.29, 2.43 + rib * 0.072, z), Vector3(0.03, 0.025, 0.64), "charcoal", yaw)
		for side: float in [-1, 1]:
			add_part(origin, Vector3(side * 5.5, 0.32, 8.6), Vector3(0.75, 0.64, 0.75), "stone", yaw)
			add_instance("foliage", "hedge", origin + basis * Vector3(side * 5.5, 0.88, 8.6), Vector3(0.62, 0.6, 0.62), yaw)


func _address(number: String, position: Vector3, yaw: float) -> void:
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
	for variant in 1:
		var tree: Dictionary = preload("res://scripts/city/neighborhood_tree_mesh.gd").new().build(variant)
		meshes["tree_bark%d" % variant] = tree.bark
		meshes["tree_leaves%d" % variant] = tree.leaves


func _garden_tree(position: Vector3, height: float) -> void:
	var variant := 0
	var shape_variation := tree_count % 3
	var yaw := fposmod(position.x * 1.73 + position.z * 0.81, TAU)
	var scale := Vector3(height * (0.92 + 0.08 * shape_variation), height, height * (1.08 - 0.05 * shape_variation))
	add_instance("tree_bark%d" % variant, "tree_bark", position, scale, yaw)
	add_instance("tree_leaves%d" % variant, "tree_leaves", position, scale, yaw)
	# Preserve the prior trunk's physical envelope; leaves do not obstruct driving.
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
					add_collision(origin + Vector3.UP, Vector3(0.18, 2, 0.18))


func _landscape() -> void:
	var faces := PackedVector3Array()
	for z in range(-640, 640, 16):
		for x in range(-640, 640, 16):
			if x >= -224 and x < 224 and z >= -176 and z < 176:
				continue
			var a := Vector3(x, _land_height(x, z), z)
			var b := Vector3(x + 16, _land_height(x + 16, z), z)
			var c := Vector3(x, _land_height(x, z + 16), z + 16)
			var d := Vector3(x + 16, _land_height(x + 16, z + 16), z + 16)
			_triangle(faces, a, c, b)
			_triangle(faces, b, c, d)
	_mesh("BackgroundLandscape", faces, "grass", 0.045)
	for side: float in [-1.0, 1.0]:
		for index in 14:
			var p := Vector3(-196 + index * 29.0, 0, side * (145 + 5 * sin(index)))
			p.y = Layout.height_at(p.x, p.z)
			_garden_tree(p, 10.0 + (index % 3))
		for index in 10:
			var p := Vector3(side * 202, 0, -130 + index * 28.0)
			p.y = Layout.height_at(p.x, p.z)
			_garden_tree(p, 9.0 + (index % 3))


func _land_height(x: float, z: float) -> float:
	var outside := maxf(maxf(absf(x) - Layout.HALF_WIDTH, absf(z) - Layout.HALF_DEPTH), 0)
	var hills := 37.0 * exp(-pow((x + 370) / 175, 2) - pow((z - 80) / 240, 2))
	hills += 48.0 * exp(-pow((x - 390) / 200, 2) - pow((z + 290) / 190, 2))
	hills += 32.0 * exp(-pow((x + 30) / 200, 2) - pow((z + 400) / 150, 2))
	return Layout.height_at(x, z) + smoothstep(0.0, 110.0, outside) * (hills + 3 * sin(x / 70) * sin(z / 110))


func _safe_site(initial: Vector2, interior: Vector2, yaw: float, footprint: Vector2) -> Vector2:
	# Keep the full parcel envelope away from every curved street, including the
	# street beside a corner lot. Frontage setback alone misses the inside bend.
	var inverse := Basis(Vector3.UP, yaw).inverse()
	for attempt in 26:
		var uv := initial.lerp(interior, float(attempt) * 0.032)
		var origin := Layout.position(uv.x, uv.y)
		var clear := true
		for street in street_samples:
			for p: Vector3 in street.points:
				var local := inverse * (p - origin)
				var distance := Vector2(maxf(absf(local.x) - footprint.x / 2, 0), maxf(absf(local.z) - footprint.y / 2, 0)).length()
				if distance < float(street.width) / 2 + 8.0:
					clear = false
					break
			if not clear:
				break
		if clear:
			return uv
	sites_valid = false
	push_error("Parcel cannot maintain street clearance at " + str(initial))
	return initial.lerp(interior, 0.8)
