extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const SECTOR_SIZE := 112.0
const CONTACT_SHADE = preload("res://assets/shaders/car_contact_shadow.gdshader")
const TERRAIN_MATERIALS := ["asphalt", "curb", "sidewalk", "grass"]
var _surfaces: Dictionary = {}
var _support := PackedVector3Array()
var _columns: Array[float]
var _rows: Array[float]
var _vertices: Array[PackedVector3Array] = []


func build() -> void:
	_columns = _cuts(Layout.COLUMNS, Layout.COLUMN_HALF_WIDTHS, Layout.TERRAIN.position.x, Layout.TERRAIN.end.x, Layout.STREET_BOUNDS.position.x, Layout.STREET_BOUNDS.end.x, false)
	_rows = _cuts(Layout.ROWS, Layout.ROW_HALF_WIDTHS, Layout.TERRAIN.position.y, Layout.TERRAIN.end.y, Layout.STREET_BOUNDS.position.y, Layout.STREET_BOUNDS.end.y, true)
	var previous := PackedVector3Array()
	var previous_bands := PackedFloat32Array()
	for z in _rows:
		var row := PackedVector3Array()
		var bands := PackedFloat32Array()
		for x in _columns:
			var point := Vector2(x, z)
			row.append(Layout.surface_point(point))
			bands.append(Layout.ground_band(point))
		if not previous.is_empty():
			for index in _columns.size() - 1:
				var a := previous[index]
				var b := previous[index + 1]
				var c := row[index]
				var d := row[index + 1]
				var center := (a + d) * 0.5
				var faces := PackedVector3Array([a, b, c, b, d, c])
				_support.append_array(faces)
				var band_a := previous_bands[index]
				var band_b := previous_bands[index + 1]
				var band_c := bands[index]
				var band_d := bands[index + 1]
				var low := _material_index(minf(minf(band_a, band_b), minf(band_c, band_d)))
				var high := _material_index(maxf(maxf(band_a, band_b), maxf(band_c, band_d)))
				if low == high:
					_write_faces(faces, center, TERRAIN_MATERIALS[low])
				else:
					_split_triangle([_sample(a, band_a), _sample(b, band_b), _sample(c, band_c)], center, low, high)
					_split_triangle([_sample(b, band_b), _sample(d, band_d), _sample(c, band_c)], center, low, high)
		_vertices.append(row)
		previous = row
		previous_bands = bands


func _material_index(band: float) -> int:
	return clampi(ceili(band), 0, TERRAIN_MATERIALS.size() - 1)


func _sample(point: Vector3, band: float) -> Vector4:
	return Vector4(point.x, point.y, point.z, band)


func _split_triangle(vertices: Array[Vector4], center: Vector3, low: int, high: int) -> void:
	# Clip the visual bands on the collision triangle itself. Curves insert no new collision seams.
	for index in range(low, high + 1):
		var polygon := vertices
		if index > 0:
			polygon = _clip_band(polygon, index - 1.0, true)
		if index < TERRAIN_MATERIALS.size() - 1:
			polygon = _clip_band(polygon, float(index), false)
		var points := PackedVector3Array()
		for vertex in polygon:
			points.append(Vector3(vertex.x, vertex.y, vertex.z))
		var faces := _triangulate(points)
		if not faces.is_empty():
			_write_faces(faces, center, TERRAIN_MATERIALS[index])


func _clip_band(polygon: Array[Vector4], edge: float, minimum: bool) -> Array[Vector4]:
	var result: Array[Vector4] = []
	for index in polygon.size():
		var a := polygon[index - 1]
		var b := polygon[index]
		var inside_a := a.w > edge if minimum else a.w <= edge
		var inside_b := b.w > edge if minimum else b.w <= edge
		if inside_a != inside_b:
			result.append(a.lerp(b, (edge - a.w) / (b.w - a.w)))
		if inside_b:
			result.append(b)
	return result


func patch(rect: Rect2, kind: String, lift: float) -> void:
	_patch(rect, kind, lift, PackedVector2Array())


func patch_polygon(outline: PackedVector2Array, kind: String, lift: float) -> void:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	_patch(bounds, kind, lift, outline)


func _patch(rect: Rect2, kind: String, lift: float, outline: PackedVector2Array) -> void:
	# Clip the baked terrain triangles so paint and paving follow the same planes.
	for row in range(maxi(0, _rows.bsearch(rect.position.y, false) - 1), mini(_rows.size() - 1, _rows.bsearch(rect.end.y))):
		for col in range(maxi(0, _columns.bsearch(rect.position.x, false) - 1), mini(_columns.size() - 1, _columns.bsearch(rect.end.x))):
			var a := _vertices[row][col] + Vector3.UP * lift
			var b := _vertices[row][col + 1] + Vector3.UP * lift
			var c := _vertices[row + 1][col] + Vector3.UP * lift
			var d := _vertices[row + 1][col + 1] + Vector3.UP * lift
			var faces := PackedVector3Array()
			for points in [[a, b, c], [b, d, c]]:
				var polygon := PackedVector3Array(points)
				polygon = _clip(polygon, 0, rect.position.x, true)
				polygon = _clip(polygon, 0, rect.end.x, false)
				polygon = _clip(polygon, 2, rect.position.y, true)
				polygon = _clip(polygon, 2, rect.end.y, false)
				for index in outline.size():
					polygon = _clip_edge(polygon, outline[index - 1], outline[index])
				faces.append_array(_triangulate(polygon))
			if not faces.is_empty():
				_write_faces(faces, (a + d) * 0.5, kind, rect)


func _triangulate(polygon: PackedVector3Array) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for index in range(1, polygon.size() - 1):
		if (polygon[index] - polygon[0]).cross(polygon[index + 1] - polygon[0]).length_squared() > 0.00000001:
			faces.append_array(PackedVector3Array([polygon[0], polygon[index], polygon[index + 1]]))
	return faces


func _clip_edge(polygon: PackedVector3Array, start: Vector2, end: Vector2) -> PackedVector3Array:
	var result := PackedVector3Array()
	var edge := end - start
	for index in polygon.size():
		var a := polygon[index - 1]
		var b := polygon[index]
		var da := edge.cross(Vector2(a.x, a.z) - start)
		var db := edge.cross(Vector2(b.x, b.z) - start)
		if (da >= 0.0) != (db >= 0.0):
			result.append(a.lerp(b, da / (da - db)))
		if db >= 0.0:
			result.append(b)
	return result


func _clip(polygon: PackedVector3Array, axis: int, edge: float, minimum: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in polygon.size():
		var a := polygon[index - 1]
		var b := polygon[index]
		var inside_a := a[axis] >= edge if minimum else a[axis] <= edge
		var inside_b := b[axis] >= edge if minimum else b[axis] <= edge
		if inside_a != inside_b:
			result.append(a.lerp(b, (edge - a[axis]) / (b[axis] - a[axis])))
		if inside_b:
			result.append(b)
	return result


func save_into(map: Node3D, materials: Dictionary, finishes: Dictionary) -> void:
	var contact_materials: Dictionary[String, ShaderMaterial] = {}
	for kind: String in ["shade_tree", "shade_parked"]:
		var material := ShaderMaterial.new()
		material.resource_name = "figueiras_" + kind
		material.shader = CONTACT_SHADE
		material.render_priority = -1
		material.set_shader_parameter("opacity", 0.22 if kind == "shade_tree" else 0.31)
		contact_materials[kind] = material
	for key: String in _surfaces:
		var batch: Dictionary = _surfaces[key]
		var tool: SurfaceTool = batch.tool
		tool.generate_normals()
		var is_shade := contact_materials.has(batch.material)
		if not is_shade and materials[batch.material].normal_texture != null:
			tool.generate_tangents()
		tool.index()
		var node := MeshInstance3D.new()
		node.name = "Ground_" + key
		node.position = batch.origin
		node.mesh = tool.commit()
		node.material_override = contact_materials[batch.material] if is_shade else finishes.get(batch.material, materials[batch.material])
		if is_shade or batch.material in ["storm_drain", "utility_cover", "asphalt_repair", "tactile"]:
			node.visibility_range_end = 126.0
			node.visibility_range_end_margin = 16.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		map.add_child(node)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_support)
	var support := StaticBody3D.new()
	support.name = "StreetAndTerrainSupport"
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = shape
	support.add_child(floor_shape)
	map.add_child(support)


func _write_faces(faces: PackedVector3Array, middle: Vector3, kind: String, patch_rect := Rect2()) -> void:
	var sector := (Vector2(middle.x, middle.z) / SECTOR_SIZE).floor()
	var key := "%s_%d_%d" % [kind, int(sector.x), int(sector.y)]
	if not _surfaces.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var origin := Vector3((sector.x + 0.5) * SECTOR_SIZE, middle.y, (sector.y + 0.5) * SECTOR_SIZE)
		_surfaces[key] = {"tool": surface, "material": kind, "origin": origin}
	var tool: SurfaceTool = _surfaces[key].tool
	var origin: Vector3 = _surfaces[key].origin
	var uv_scale := 0.44
	var localized := kind.begins_with("shade_") or kind in ["white", "yellow", "utility_cover", "storm_drain"]
	if kind in ["sidewalk", "paving", "cobbles", "curb"]:
		uv_scale = 0.52
	elif kind == "grass" or kind == "mulch":
		uv_scale = 0.26
	for point in faces:
		var location := Vector2(point.x, point.z)
		tool.set_uv((location - patch_rect.position) / patch_rect.size if localized else location * uv_scale)
		var tone := 0.5 + 0.37 * cos(point.x * 0.037 + point.z * 0.031) * sin(point.z * 0.027)
		var tint := Color.WHITE
		if kind == "grass":
			tint = Color("879882").lerp(Color("ead9a3"), tone)
		elif kind in ["asphalt", "asphalt_repair", "sidewalk", "curb", "paving", "cobbles"]:
			tint = Layout.road_finish(location)
		tool.set_color(tint)
		tool.add_vertex(point - origin)


func _cuts(roads: Array, half_widths: Array, start: float, end: float, road_start: float, road_end: float, horizontal: bool) -> Array[float]:
	var cuts: Dictionary = {start: true, end: true}
	for coordinate in range(int(start), int(end), Layout.GROUND_STEP):
		cuts[float(coordinate)] = true
	for edge in [road_start, road_end]:
		for offset in [-Layout.WALK_WIDTH, -Layout.CURB_WIDTH, 0.0, Layout.CURB_WIDTH, Layout.WALK_WIDTH]:
			cuts[edge + offset] = true
	for index in roads.size():
		var center: float = roads[index]
		var half: float = half_widths[index]
		var walk := Layout.walk_width(center) if horizontal else Layout.WALK_WIDTH
		cuts[center] = true
		for side: float in [-1, 1]:
			cuts[center + side * half * 0.48] = true
			if horizontal and center == Layout.AVENUE:
				cuts[center + side * Layout.AVENUE_TRAVEL_HALF] = true
			for offset in [0.0, Layout.CURB_WIDTH, 1.35, Layout.WALK_WIDTH, walk, 5.6, 8.5, 11.0]:
				cuts[center + side * (half + offset)] = true
	var result: Array[float] = []
	result.assign(cuts.keys())
	result.sort()
	return result
