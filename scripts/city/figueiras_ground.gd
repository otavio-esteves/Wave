extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const SECTOR_SIZE := 112.0
const CONTACT_SHADE = preload("res://assets/shaders/car_contact_shadow.gdshader")
const TERRAIN_MATERIALS := ["asphalt", "curb", "sidewalk", "grass"]
const BAND_EDGES := [0.0, Layout.CURB_WIDTH, Layout.WALK_WIDTH]
var _surfaces: Dictionary = {}
var _support := PackedVector3Array()
var _columns: Array[float]
var _rows: Array[float]
var _vertices: Array[PackedVector3Array] = []
var _refined: Dictionary[Vector2i, PackedVector3Array] = {}


func build() -> void:
	_columns = _cuts(Layout.COLUMNS, Layout.COLUMN_HALF_WIDTHS, Layout.TERRAIN.position.x, Layout.TERRAIN.end.x, Layout.STREET_BOUNDS.position.x, Layout.STREET_BOUNDS.end.x, false)
	_rows = _cuts(Layout.ROWS, Layout.ROW_HALF_WIDTHS, Layout.TERRAIN.position.y, Layout.TERRAIN.end.y, Layout.STREET_BOUNDS.position.y, Layout.STREET_BOUNDS.end.y, true)
	var refine := _scenic_cells()
	var previous := PackedVector3Array()
	var previous_bands := PackedFloat32Array()
	for row_index in _rows.size():
		var z := _rows[row_index]
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
				var cell := Vector2i(index, row_index - 1)
				if refine.has(cell):
					_refine_cell(cell, a, b, c, d, refine)
				else:
					_append_cell(a, b, c, d, Vector4(previous_bands[index], previous_bands[index + 1], bands[index], bands[index + 1]))
		_vertices.append(row)
		previous = row
		previous_bands = bands


func _scenic_cells() -> Dictionary[Vector2i, bool]:
	var selected: Dictionary[Vector2i, bool] = {}
	for row in _rows.size() - 1:
		for column in _columns.size() - 1:
			var span := Vector2(_columns[column + 1] - _columns[column], _rows[row + 1] - _rows[row])
			if maxf(span.x, span.y) <= 2.1:
				continue
			var center := Vector2(_columns[column], _rows[row]) + span * 0.5
			var route := Layout.scenic_sample(center)
			var shore := Layout.lake_distance(center)
			if Layout.scenic_edge(route) < 11.5 or (shore > 0.73 and shore < 1.24) or Layout.creek_weight(center) > 0.11 or Layout.nursery_terrace(center).y > 0.14:
				selected[Vector2i(column, row)] = true
	return selected


func _refine_cell(cell: Vector2i, a: Vector3, b: Vector3, c: Vector3, d: Vector3, refined: Dictionary) -> void:
	# Both sides of a shared edge use the same heights. Coarse neighbours
	# retain their straight edge, so there is no step or gap at the transition.
	const STEPS := 3
	var points := PackedVector3Array()
	var bands := PackedFloat32Array()
	for row in STEPS + 1:
		for column in STEPS + 1:
			var u := float(column) / STEPS
			var v := float(row) / STEPS
			var point := a.lerp(b, u).lerp(c.lerp(d, u), v)
			var planar := (column == 0 and not refined.has(cell + Vector2i.LEFT)) or (column == STEPS and not refined.has(cell + Vector2i.RIGHT))
			planar = planar or (row == 0 and not refined.has(cell + Vector2i.UP)) or (row == STEPS and not refined.has(cell + Vector2i.DOWN))
			var location := Vector2(point.x, point.z)
			if not planar:
				point.y = Layout.height_at(location)
			points.append(point)
			bands.append(Layout.ground_band(location))
	var start := _support.size()
	for row in STEPS:
		for column in STEPS:
			var first := row * (STEPS + 1) + column
			var next := first + STEPS + 1
			_append_cell(points[first], points[first + 1], points[next], points[next + 1],
				Vector4(bands[first], bands[first + 1], bands[next], bands[next + 1]))
	_refined[cell] = _support.slice(start)


func _append_cell(a: Vector3, b: Vector3, c: Vector3, d: Vector3, bands: Vector4) -> void:
	var center := (a + d) * 0.5
	var faces := PackedVector3Array([a, b, c, b, d, c])
	_support.append_array(faces)
	var low := _material_index(minf(minf(bands.x, bands.y), minf(bands.z, bands.w)))
	var high := _material_index(maxf(maxf(bands.x, bands.y), maxf(bands.z, bands.w)))
	var palette := TERRAIN_MATERIALS
	if low <= 2 and high >= 1 and not Layout.STREET_BOUNDS.grow(3.0).has_point(Vector2(center.x, center.z)):
		palette = ["asphalt", "scenic_gutter", "scenic_shoulder", "grass"]
	if low == high:
		_write_faces(faces, center, palette[low])
	else:
		_split_triangle([_sample(a, bands.x), _sample(b, bands.y), _sample(c, bands.z)], center, low, high, palette)
		_split_triangle([_sample(b, bands.y), _sample(d, bands.w), _sample(c, bands.z)], center, low, high, palette)


func _material_index(band: float) -> int:
	return BAND_EDGES.bsearch(band)


func _sample(point: Vector3, band: float) -> Vector4:
	return Vector4(point.x, point.y, point.z, band)


func _split_triangle(vertices: Array[Vector4], center: Vector3, low: int, high: int, palette: Array) -> void:
	# Clip the visual bands on the collision triangle itself. Curves insert no new collision seams.
	for index in range(low, high + 1):
		var polygon := vertices
		if index > 0:
			polygon = _clip_band(polygon, BAND_EDGES[index - 1], true)
		if index < TERRAIN_MATERIALS.size() - 1:
			polygon = _clip_band(polygon, BAND_EDGES[index], false)
		var points := PackedVector3Array()
		for vertex in polygon:
			points.append(Vector3(vertex.x, vertex.y, vertex.z))
		var faces := _triangulate(points)
		if not faces.is_empty():
			_write_faces(faces, center, palette[index])


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
			var a := _vertices[row][col]
			var d := _vertices[row + 1][col + 1]
			var terrain_faces: PackedVector3Array = _refined.get(Vector2i(col, row), PackedVector3Array())
			if terrain_faces.is_empty():
				var b := _vertices[row][col + 1]
				var c := _vertices[row + 1][col]
				terrain_faces = PackedVector3Array([a, b, c, b, d, c])
			var faces := PackedVector3Array()
			for first in range(0, terrain_faces.size(), 3):
				var polygon := terrain_faces.slice(first, first + 3)
				for index in 3:
					polygon[index].y += lift
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
	var heights := PackedFloat32Array()
	for row in _vertices:
		for vertex in row:
			heights.append(vertex.y)
	support.set_meta("terrain_grid", {"columns": PackedFloat32Array(_columns), "rows": PackedFloat32Array(_rows),
		"heights": heights, "refined": _refined})
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = shape
	support.add_child(floor_shape)
	map.add_child(support)


func _write_faces(faces: PackedVector3Array, middle: Vector3, kind: String, patch_rect := Rect2()) -> void:
	var sector := (Vector2(middle.x, middle.z) / SECTOR_SIZE).floor()
	var surface_material := kind
	var road_variant := 0.0
	if kind in ["scenic_gutter", "scenic_shoulder"]:
		surface_material = "asphalt"
		road_variant = 1.0 if kind == "scenic_gutter" else 2.0
	elif kind == "yellow":
		surface_material = "white"
	var key := "%s_%d_%d" % [surface_material, int(sector.x), int(sector.y)]
	if not _surfaces.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var origin := Vector3((sector.x + 0.5) * SECTOR_SIZE, middle.y, (sector.y + 0.5) * SECTOR_SIZE)
		_surfaces[key] = {"tool": surface, "material": surface_material, "origin": origin}
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
		var shelter := Layout.gallery_shadow(location) if surface_material == "asphalt" else 0.0
		tool.set_uv2(Vector2(road_variant, shelter))
		var tone := 0.5 + 0.37 * cos(point.x * 0.037 + point.z * 0.031) * sin(point.z * 0.027)
		var tint := Color.WHITE
		if kind == "grass":
			var lowland := smoothstep(190.0, 306.0, point.z)
			var highland := smoothstep(48.0, 74.0, point.y)
			var warm := Color("e9ce8f").lerp(Color("c2c994"), lowland)
			var cool := Color("899985").lerp(Color("869483"), highland)
			tint = cool.lerp(warm, tone)
			tint = tint.lerp(Color("829879"), Layout.creek_weight(location) * 0.63)
		elif kind == "white":
			tint = Color("ede2c7")
		elif kind == "yellow":
			tint = Color("e3ad4f")
		elif kind in ["asphalt", "asphalt_repair", "sidewalk", "curb", "paving", "cobbles", "scenic_gutter", "scenic_shoulder"]:
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
