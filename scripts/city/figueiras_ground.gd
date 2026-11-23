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
var _bridge: Dictionary[Vector2i, PackedVector3Array] = {}
var _bridge_triangle_count := 0


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
			var sample := Layout.ground_sample(point)
			row.append(Vector3(x, sample.x, z))
			bands.append(sample.y)
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
	_bridge_triangle_count = _build_deck(Layout.scenic_routes()[2], Layout.vale_bridge_station(), Layout.VALE_BRIDGE_HALF_SPAN)
	var bridges := Layout.district_bridges()
	for road in bridges:
		_build_deck(road, bridges[road], Layout.Baixada.BRIDGE_HALF_SPAN)


func _build_deck(route: Layout.Route, crossing: float, span: float) -> int:
	var faces := PackedVector3Array()
	var previous := PackedVector3Array()
	const SECTIONS := 16
	const ACROSS := 4
	for section in SECTIONS + 1:
		var station := crossing + lerpf(-span, span, float(section) / SECTIONS)
		var row := PackedVector3Array()
		for column in ACROSS + 1:
			var lateral := lerpf(-route.edge_at(station, -1.0), route.edge_at(station, 1.0), float(column) / ACROSS)
			row.append(Layout.surface_point(route.offset_at(station, lateral)))
		if section > 0:
			for column in ACROSS:
				_index_deck_triangle(PackedVector3Array([previous[column], previous[column + 1], row[column]]), faces)
				_index_deck_triangle(PackedVector3Array([previous[column + 1], row[column + 1], row[column]]), faces)
		previous = row
	_support.append_array(faces)
	_write_faces(faces, Layout.surface_point(route.point_at(crossing)), "asphalt")
	return faces.size() / 3


func _index_deck_triangle(triangle: PackedVector3Array, faces: PackedVector3Array) -> void:
	if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).y > 0.0:
		triangle.reverse()
	faces.append_array(triangle)
	var bounds := Rect2(Vector2(triangle[0].x, triangle[0].z), Vector2.ZERO)
	for point in triangle:
		bounds = bounds.expand(Vector2(point.x, point.z))
	for row in range(_rows.bsearch(bounds.position.y, false) - 1, _rows.bsearch(bounds.end.y)):
		for col in range(_columns.bsearch(bounds.position.x, false) - 1, _columns.bsearch(bounds.end.x)):
			var polygon := _clip(triangle, 0, _columns[col], true)
			polygon = _clip(polygon, 0, _columns[col + 1], false)
			polygon = _clip(polygon, 2, _rows[row], true)
			polygon = _clip(polygon, 2, _rows[row + 1], false)
			var local_faces := _triangulate(polygon)
			if not local_faces.is_empty():
				var cell := Vector2i(col, row)
				var indexed := _bridge.get(cell, PackedVector3Array()) as PackedVector3Array
				indexed.append_array(local_faces)
				_bridge[cell] = indexed


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
			var bank_width := 20.0 if int(route.x) == Layout.PASSO_ROUTE else 11.5
			if Layout.DEPOT.grow(10.0).has_point(center) or Layout.urban_edge(Layout.urban_sample(center)) < 13.0 or Layout.scenic_edge(route) < bank_width or (shore > 0.73 and shore < 1.24) or Layout.creek_weight(center) > 0.11 or Layout.nursery_terrace(center).y > 0.14 or Layout.Baixada.edge(Layout.district_sample(center)) < 11.5:
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
				var sample := Layout.ground_sample(location)
				point.y = sample.x
				bands.append(sample.y)
			else:
				bands.append(Layout.ground_band(location))
			points.append(point)
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
	var position := Vector2(center.x, center.z)
	if low <= 2 and high >= 1 and not Layout.STREET_BOUNDS.grow(3.0).has_point(position) and Layout.Baixada.edge(Layout.district_sample(position)) > 8.0:
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


func surface_point(site: Vector2, lift := 0.0) -> Vector3:
	if not Layout.TERRAIN.has_point(site):
		return Layout.surface_point(site, lift)
	var x := clampi(_columns.bsearch(site.x) - 1, 0, _columns.size() - 2)
	var z := clampi(_rows.bsearch(site.y) - 1, 0, _rows.size() - 2)
	var cell := Vector2i(x, z)
	for index in [_bridge, _refined]:
		if index.has(cell):
			var height := _triangle_height(index[cell], site)
			if height < INF:
				return Vector3(site.x, height + lift, site.y)
	var u := inverse_lerp(_columns[x], _columns[x + 1], site.x)
	var v := inverse_lerp(_rows[z], _rows[z + 1], site.y)
	var a := _vertices[z][x].y
	var b := _vertices[z][x + 1].y
	var c := _vertices[z + 1][x].y
	var d := _vertices[z + 1][x + 1].y
	var elevation := a + (b - a) * u + (c - a) * v if u + v <= 1.0 else d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)
	return Vector3(site.x, elevation + lift, site.y)


func _triangle_height(faces: PackedVector3Array, site: Vector2) -> float:
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ac := Vector2(c.x - a.x, c.z - a.z)
		var sample := site - Vector2(a.x, a.z)
		var area := ab.cross(ac)
		if absf(area) < 0.00001:
			continue
		var u := sample.cross(ac) / area
		var v := ab.cross(sample) / area
		if u >= -0.0002 and v >= -0.0002 and u + v <= 1.0002:
			return a.y + u * (b.y - a.y) + v * (c.y - a.y)
	return INF


func _cell_faces(cell: Vector2i) -> PackedVector3Array:
	if _refined.has(cell):
		return _refined[cell]
	var a := _vertices[cell.y][cell.x]
	var b := _vertices[cell.y][cell.x + 1]
	var c := _vertices[cell.y + 1][cell.x]
	var d := _vertices[cell.y + 1][cell.x + 1]
	return PackedVector3Array([a, b, c, b, d, c])


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
			var cell := Vector2i(col, row)
			var terrain_faces := _cell_faces(cell)
			var floor_size := terrain_faces.size()
			var has_deck := _bridge.has(cell) and kind in ["white", "yellow"]
			if has_deck:
				terrain_faces.append_array(_bridge[cell])
			var faces := PackedVector3Array()
			for first in range(0, terrain_faces.size(), 3):
				var polygon := terrain_faces.slice(first, first + 3)
				if has_deck and first < floor_size:
					var center := (polygon[0] + polygon[1] + polygon[2]) / 3.0
					if Layout.bridge_opening(Vector2(center.x, center.z)) > 0.06:
						continue
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
	for kind: String in ["shade_tree", "shade_parked", "shade_building"]:
		var material := ShaderMaterial.new()
		material.resource_name = "figueiras_" + kind
		material.shader = CONTACT_SHADE
		material.render_priority = -1
		material.set_shader_parameter("opacity", 0.22 if kind == "shade_tree" else 0.31)
		material.set_shader_parameter("rectangular", kind == "shade_building")
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
	_save_landscape_backdrop(map)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_support)
	var support := StaticBody3D.new()
	support.name = "StreetAndTerrainSupport"
	support.set_meta("vale_bridge_collision_triangles", _bridge_triangle_count)
	var heights := PackedFloat32Array()
	for row in _vertices:
		for vertex in row:
			heights.append(vertex.y)
	var layered := _refined.duplicate()
	for cell in _bridge:
		var faces := _cell_faces(cell)
		faces.append_array(_bridge[cell])
		layered[cell] = faces
	support.set_meta("terrain_grid", {"columns": PackedFloat32Array(_columns), "rows": PackedFloat32Array(_rows),
		"heights": heights, "refined": layered})
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = shape
	support.add_child(floor_shape)
	map.add_child(support)


func _save_landscape_backdrop(map: Node3D) -> void:
	# A visual continuation of the baked perimeter keeps the edge of the
	# playable terrain hidden from the ridge and lakeside overlooks.
	var perimeter := PackedVector3Array()
	for column in _columns.size() - 1:
		perimeter.append(_vertices[0][column])
	for row in _rows.size() - 1:
		perimeter.append(_vertices[row][-1])
	for column in range(_columns.size() - 1, 0, -1):
		perimeter.append(_vertices[-1][column])
	for row in range(_rows.size() - 1, 0, -1):
		perimeter.append(_vertices[row][0])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := perimeter
	var center := Layout.TERRAIN.get_center()
	var previous_colors := PackedColorArray()
	for edge in perimeter:
		previous_colors.append(_terrain_tint(edge))
	# Retain every baked boundary vertex for the join. The rest of the terrain
	# keeps only the outline points needed for silhouettes at this distance.
	var indices := _backdrop_profile(perimeter)
	var rings := [1.09, 1.20, 1.32, 1.45, 1.60, 1.77, 1.95, 2.16, 2.38, 2.65, 2.99, 3.42, 3.96, 4.59, 5.32]
	for radius: float in rings:
		var points := PackedVector3Array()
		var colors := PackedColorArray()
		for index in indices:
			var edge := perimeter[index]
			var offset := Vector2(edge.x, edge.z) - center
			var position := center + offset * radius
			var runout := lerpf(edge.y, Layout.horizon_height(position), smoothstep(1.0, 1.62, radius))
			var point := Vector3(position.x, runout, position.y)
			points.append(point)
			colors.append(_terrain_tint(point))
		var seam := is_equal_approx(radius, rings[0])
		for index in indices.size():
			var next := (index + 1) % indices.size()
			var first := indices[index] if seam else index
			var end := (perimeter.size() if next == 0 else indices[next]) if seam else index + 1
			for inner in range(first, end):
				var neighbor := (inner + 1) % previous.size()
				_backdrop_vertex(surface, previous[inner], previous_colors[inner])
				_backdrop_vertex(surface, points[index], colors[index])
				_backdrop_vertex(surface, previous[neighbor], previous_colors[neighbor])
			_backdrop_vertex(surface, previous[end % previous.size()], previous_colors[end % previous.size()])
			_backdrop_vertex(surface, points[index], colors[index])
			_backdrop_vertex(surface, points[next], colors[next])
		previous = points
		previous_colors = colors
	surface.generate_normals()
	surface.index()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var backdrop := MeshInstance3D.new()
	backdrop.name = "EncostasAoFundo"
	backdrop.mesh = surface.commit()
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map.add_child(backdrop)
	map.set_meta("backdrop_triangles", perimeter.size() + indices.size() * (2 * rings.size() - 1))


func _backdrop_profile(perimeter: PackedVector3Array) -> PackedInt32Array:
	var indices := PackedInt32Array([0])
	var corners := [_columns.size() - 1, _columns.size() + _rows.size() - 2,
		2 * _columns.size() + _rows.size() - 3]
	for index in range(1, perimeter.size()):
		var point := perimeter[index]
		var previous := perimeter[indices[-1]]
		if index in corners or Vector2(point.x - previous.x, point.z - previous.z).length_squared() >= 18.0 * 18.0:
			indices.append(index)
	return indices


func _backdrop_vertex(surface: SurfaceTool, point: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(point)


func _terrain_tint(point: Vector3) -> Color:
	var location := Vector2(point.x, point.z)
	var cover := Layout.canopy_cover(location)
	var growth := 0.5 + 0.5 * sin(point.x * 0.064 - point.z * 0.058) * sin(point.z * 0.040 + point.x * 0.015)
	var wooded := smoothstep(0.37, 0.75, cover)
	var moisture := clampf(growth * 0.55 + smoothstep(43.0, 91.0, point.y) * 0.24 + Layout.creek_weight(location) * 0.28, 0.0, 1.0)
	var meadow := Color("7a7753").lerp(Color("627b50"), moisture)
	var forest := Color("4f6242").lerp(Color("365a43"), moisture)
	var tint := meadow.lerp(forest, wooded)
	tint.a = wooded
	return tint


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
	elif kind == "horto_paving":
		uv_scale = 0.20
	elif kind == "grass" or kind == "mulch":
		uv_scale = 0.26
	for point in faces:
		var location := Vector2(point.x, point.z)
		tool.set_uv((location - patch_rect.position) / patch_rect.size if localized else location * uv_scale)
		var shelter := Layout.rain_shelter(location) if surface_material in ["asphalt", "loading_concrete"] else 0.0
		var primary := Layout.passo_cut_mask(location) if kind == "grass" else road_variant
		tool.set_uv2(Vector2(primary, shelter))
		var tint := Color.WHITE
		if kind == "grass":
			tint = _terrain_tint(point)
		elif kind == "scenic_shoulder" or kind == "scenic_gutter":
			tint = _terrain_tint(point)
			tint.a = smoothstep(0.15, Layout.WALK_WIDTH, Layout.road_distance(location))
		elif kind == "white":
			tint = Color("ede2c7")
		elif kind == "yellow":
			tint = Color("e3ad4f")
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
					for offset in [Layout.AVENUE_MEDIAN_HALF, Layout.AVENUE_TRAVEL_HALF, Layout.AVENUE_MEDIAN_HALF + Layout.AVENUE_LANE]:
						cuts[center + side * offset] = true
			for offset in [0.0, Layout.CURB_WIDTH, 1.35, Layout.WALK_WIDTH, walk, 5.6, 8.5, 11.0]:
				cuts[center + side * (half + offset)] = true
	var result: Array[float] = []
	result.assign(cuts.keys())
	result.sort()
	return result
