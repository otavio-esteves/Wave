extends "res://scripts/corridor/corridor_builder.gd"

# Terrain, street surfaces, spatial queries and exact physical support.

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var road_faces := PackedVector3Array()
var sidewalk_faces := PackedVector3Array()
var paint_faces := PackedVector3Array()
var street_samples: Array[Dictionary] = []
var street_point_tiles: Dictionary = {}
var sites_valid := true
var tree_count := 0
var driveway_faces := PackedVector3Array()
const SurfaceChunks = preload("res://scripts/city/pilot_surface_chunks.gd")
const MeshLOD = preload("res://scripts/city/pilot_mesh_lod.gd")
const FloorHLOD = preload("res://scripts/city/pilot_floor_hlod.gd")
var surface_batches: Dictionary = {}
var parcel_count := 0
var parked_count := 0
var parcels: Array[Dictionary] = []
var parcel_tiles: Dictionary = {}
var driveway_connections: Array[Dictionary] = []
var road_tiles: Dictionary = {}
var ramp_tiles: Dictionary = {}
var grass_count := 0
var garden_frontages := 0
var street_detail_count := 0
var skyscraper_count := 0
var district_parcels := [0, 0, 0]
var review_benches: Array[Dictionary] = []


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
	# Patches share one material/tile batch instead of thousands of draw objects.
	var kind := label if label in ["Terrain", "Streets", "Sidewalks", "SidewalksFar", "RoadMarkings", "LotDriveways", "BackgroundLandscape"] else ("Planting" if material == "garden_soil" else "Paving")
	if shadow_size != Vector2.ZERO:
		kind = "TerrainContactShading"
	for index in range(0, faces.size(), 3):
		var tile := SurfaceChunks.key(faces[index], faces[index + 1], faces[index + 2])
		var batch_key := "%s:%s:%d:%d" % [kind, material, tile.x, tile.y]
		if not surface_batches.has(batch_key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface_batches[batch_key] = {"tool": surface, "kind": kind, "material": material, "tile": tile}
		var tool: SurfaceTool = surface_batches[batch_key].tool
		for vertex in 3:
			var point := faces[index + vertex]
			tool.set_uv(Vector2(point.x, point.z) * uv_scale)
			var tint := Color.WHITE
			if material == "grass":
				var variation := 0.86 + 0.12 * sin(point.x * 0.009 + sin(point.z * 0.013)) * cos(point.z * 0.008) + 0.06 * sin(point.x * 0.047 + point.z * 0.023)
				tint = Color(variation, variation, variation * 0.96, 1)
			elif material == "asphalt":
				var wear := 0.94 + 0.035 * sin(point.x * 0.13 + point.z * 0.17) + 0.025 * cos(point.z * 0.34)
				var region := Color("b4a390") if point.x < -424 else (Color("a4aaa6") if point.x < 676 else Color("87949c"))
				var repaired := smoothstep(0.35, 0.85, sin(point.x * 0.018 + point.z * 0.025))
				tint = region * Color(wear, wear, wear) * lerpf(0.9, 1.08, repaired)
			elif material == "sidewalk":
				var slab := int(floor(point.x / 1.3) + floor(point.z / 1.3)) % 7
				var variation := 0.92 + slab * 0.014
				tint = (Color("c3b79e") if point.x < -424 else Color("bcc4c5")) * Color(variation, variation, variation)
			if shadow_size != Vector2.ZERO:
				var relative := (Vector2(point.x, point.z) - shadow_center).abs() / (shadow_size * 0.5)
				var occlusion := lerpf(0.46, 1.0, smoothstep(0.60, 1.0, maxf(relative.x, relative.y)))
				tint *= Color(occlusion, occlusion, occlusion)
			tool.set_color(tint)
			tool.add_vertex(point)


func _flush_surfaces() -> void:
	for batch in surface_batches.values():
		var tool: SurfaceTool = batch.tool
		tool.generate_normals()
		tool.index()
		var node := MeshInstance3D.new()
		node.name = "%s_%d_%d" % [batch.kind, batch.tile.x, batch.tile.y]
		# Different paving materials can occupy the same tile. Avoid Godot's
		# process-dependent @MeshInstance3D@ names on the second surface.
		if scene_root.has_node(NodePath(node.name)):
			node.name = "%s_%s_%d_%d" % [batch.kind, batch.material, batch.tile.x, batch.tile.y]
		node.mesh = MeshLOD.bake(tool.commit()) if batch.kind in ["Terrain", "Streets", "Sidewalks", "SidewalksFar", "BackgroundLandscape"] else tool.commit()
		node.material_override = materials[batch.material]
		node.set_meta("surface_kind", batch.kind)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if batch.kind == "TerrainContactShading":
			node.visibility_range_end = 180.0
		elif batch.kind in ["RoadMarkings", "LotDriveways", "Paving", "Planting"]:
			node.visibility_range_end = 420.0
		scene_root.add_child(node)
	var floor_nodes := scene_root.get_children()
	for node in FloorHLOD.bake(floor_nodes):
		scene_root.add_child(node)
	for node in floor_nodes:
		if not node is MeshInstance3D:
			continue
		var kind: String = node.get_meta("surface_kind", "")
		if kind == "SidewalksFar":
			scene_root.remove_child(node)
			node.free()
		elif kind in ["Terrain", "Streets", "Sidewalks", "BackgroundLandscape"]:
			node.visibility_range_end = FloorHLOD.NEAR_DISTANCE
	surface_batches.clear()


func _support(label: String, faces: PackedVector3Array) -> void:
	var chunks := SurfaceChunks.split(faces)
	for tile in chunks:
		var body_name := "Support_%d_%d" % [tile.x, tile.y]
		var body := scene_root.get_node_or_null(body_name) as StaticBody3D
		if body == null:
			body = StaticBody3D.new()
			body.name = body_name
			scene_root.add_child(body)
		var collider := CollisionShape3D.new()
		collider.name = label
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(chunks[tile].vertices)
		collider.shape = shape
		body.add_child(collider)


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
			for sample in _nearby_street_points(origin):
				var point: Vector3 = sample.position
				var local := inverse * (point - origin)
				var distance := Vector2(maxf(absf(local.x) - footprint.x / 2, 0), maxf(absf(local.z) - footprint.y / 2, 0)).length()
				if distance < float(sample.width) / 2 + 5.5:
					clear = false
					break
			if clear:
				_register_parcel({"center": Vector2(origin.x, origin.z), "yaw": yaw, "size": footprint})
				return uv
	# A tight frontage becomes a garden instead of forcing overlapping buildings.
	garden_frontages += 1
	return Vector2.INF


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
	sidewalk_faces = _sample_sidewalks(1)


func _sample_sidewalks(step: int) -> PackedVector3Array:
	var output := PackedVector3Array()
	# One signed distance field unites street edges, corners and accessible ramps.
	# Its one-metre cells share the same diagonal as the eight-metre terrain.
	var samples: Dictionary = {}
	for key: Vector2i in road_tiles:
		for x in range(key.x * 16 / step, (key.x * 16 + 16) / step):
			for z in range(key.y * 16 / step, (key.y * 16 + 16) / step):
				var points: Array[Vector3] = []
				for corner: Vector2i in [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1)]:
					if not samples.has(corner):
						samples[corner] = _road_distance(Vector2(corner * step))
					points.append(Vector3(corner.x * step, samples[corner], corner.y * step))
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
							_triangle(output, _sidewalk_point(polygon[0]), _sidewalk_point(polygon[index]), _sidewalk_point(polygon[index + 1]))

	return output


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
	for parcel in _nearby_parcels(center):
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


func _ground_part(origin: Vector3, offset: Vector3, size: Vector3, material: String, yaw: float, solid: bool = false) -> void:
	var axis := 0 if size.x > size.z else 2
	var steps := maxi(1, ceili(size[axis] / 2.0))
	var basis := Basis(Vector3.UP, yaw)
	var hull := PackedVector3Array()
	var shape_origin := Vector3(origin.x, 0, origin.z)
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
		add_box(center, part_size, material, false, yaw)
		if solid:
			for dx: float in [-part_size.x / 2, part_size.x / 2]:
				for dy: float in [-part_size.y / 2, part_size.y / 2]:
					for dz: float in [-part_size.z / 2, part_size.z / 2]:
						hull.append(center + basis * Vector3(dx, dy, dz) - shape_origin)
	if solid:
		# One convex wall envelope replaces the chain of two-metre physics boxes.
		# Authored road, terrain and curb support retain their exact triangles.
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		var collider := CollisionShape3D.new()
		collider.name = "Solid_%03d" % _colliders.get_child_count()
		collider.position = shape_origin
		collider.shape = shape
		_colliders.add_child(collider)


func _nearby_street_points(origin: Vector3) -> Array:
	var result: Array = []
	var tile := Vector2i(floori(origin.x / 64), floori(origin.z / 64))
	for x in range(-1, 2):
		for z in range(-1, 2):
			result.append_array(street_point_tiles.get(tile + Vector2i(x, z), []))
	return result


func _register_parcel(parcel: Dictionary) -> void:
	parcels.append(parcel)
	var key := Vector2i(floori(parcel.center.x / 64), floori(parcel.center.y / 64))
	if not parcel_tiles.has(key):
		parcel_tiles[key] = []
	parcel_tiles[key].append(parcel)


func _nearby_parcels(center: Vector2) -> Array:
	var result: Array = []
	var key := Vector2i(floori(center.x / 64), floori(center.y / 64))
	for x in range(-2, 3):
		for z in range(-2, 3):
			result.append_array(parcel_tiles.get(key + Vector2i(x, z), []))
	return result
