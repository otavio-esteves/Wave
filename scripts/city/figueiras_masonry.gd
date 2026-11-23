extends RefCounted

const Openings = preload("res://scripts/city/figueiras_openings.gd")
const SECTOR_SIZE := 96.0
const REVEAL := 0.27
const CORNER := 0.17


class Wall:
	var pose: Transform3D
	var size: Vector3
	var finish: String
	var faces: Array[Array] = [[], [], [], []]

	func _init(origin: Vector3, rotation: float, dimensions: Vector3, material: String) -> void:
		pose = Transform3D(Basis(Vector3.UP, rotation), origin)
		size = dimensions
		finish = material

	func width(face: int) -> float:
		return size.x if face % 2 == 0 else size.z

	func front(face: int) -> float:
		return (size.z if face % 2 == 0 else size.x) * 0.5


class Opening:
	var rect: Rect2
	var arch: bool
	var depth: float

	func _init(center: Vector2, size: Vector2, arched: bool, inset: float) -> void:
		rect = Rect2(center - size * 0.5, size)
		arch = arched
		depth = inset


var _walls: Array[Wall] = []
var _lot: Array[Wall] = []
var _opening_count := 0


func add_wall(origin: Vector3, yaw: float, size: Vector3, finish: String) -> void:
	var wall := Wall.new(origin, yaw, size, finish)
	_walls.append(wall)
	_lot.append(wall)


func finish_lot() -> void:
	_lot.clear()


func recess(origin: Vector3, offset: Vector3, yaw: float, size: Vector2, arched: bool, depth := REVEAL) -> Vector3:
	if _lot.is_empty():
		return offset
	var pose := Basis(Vector3.UP, yaw)
	var point := origin + pose * offset
	for wall in _lot:
		for face in 4:
			var facing := wall.pose.basis * _face_basis(face)
			if facing.z.dot(pose.z) < 0.999:
				continue
			var local := facing.inverse() * (point - wall.pose.origin)
			var front := wall.front(face)
			if absf(local.z - front) > 0.065:
				continue
			var half_width := wall.width(face) * 0.5 - CORNER
			var opening := Opening.new(Vector2(local.x, local.y), size, arched, depth)
			var bounds := Rect2(-half_width, 0.0, half_width * 2.0, wall.size.y)
			if not bounds.encloses(opening.rect):
				continue
			if wall.faces[face].any(func(other: Opening) -> bool: return other.rect.intersects(opening.rect, true)):
				continue
			wall.faces[face].append(opening)
			_opening_count += 1
			return offset - Vector3.BACK * (depth + local.z - front)
	return offset


func bake(city: Node3D, materials: Dictionary[String, ShaderMaterial]) -> void:
	var groups: Dictionary[Vector2i, Array] = {}
	for wall in _walls:
		var center := wall.pose.origin
		var tile := Vector2i((Vector2(center.x, center.z) / SECTOR_SIZE).floor())
		if not groups.has(tile):
			groups[tile] = []
		groups[tile].append(wall)
	var finish := materials["cream"].duplicate() as ShaderMaterial
	finish.resource_name = "figueiras_wall_recessed"
	finish.set_shader_parameter("baked_facade", true)
	finish.set_shader_parameter("instance_tint", true)
	finish.set_shader_parameter("facade_brick", materials["brick"].get_shader_parameter("color_texture"))
	finish.set_shader_parameter("facade_factory_brick", materials["baixada_brick"].get_shader_parameter("color_texture"))
	finish.set_shader_parameter("facade_brick_normal", materials["brick"].get_shader_parameter("normal_texture"))
	for tile: Vector2i in groups:
		var walls: Array = groups[tile]
		var center := Vector3.ZERO
		for wall: Wall in walls:
			center += wall.pose.origin
		center /= walls.size()
		var shell := _surface()
		var silhouette := _surface()
		for wall: Wall in walls:
			var paint: Color = materials[wall.finish].get_shader_parameter("wall_color")
			var surface := materials[wall.finish]
			var layer := int(surface.get_shader_parameter("atlas_tile")) if surface.get_shader_parameter("pattern_atlas") else (4 if wall.finish == "brick" else 5)
			# The paint alpha selects the finish inside the shared sector mesh.
			paint.a = (layer + 0.5) * 0.125
			var placement := wall.pose
			placement.origin -= center
			_wall(shell, silhouette, wall, placement, paint)
		shell.index()
		shell.generate_tangents()
		silhouette.index()
		silhouette.generate_tangents()
		var hull := silhouette.commit()
		var proxy := MeshInstance3D.new()
		proxy.name = "DistantMasonry_%d_%d" % [tile.x, tile.y]
		proxy.position = center
		proxy.mesh = hull
		proxy.material_override = finish
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.visibility_range_begin = 168.0
		proxy.visibility_range_begin_margin = 12.0
		proxy.set_meta("masonry_lod", true)
		city.add_child(proxy)
		proxy.owner = city
		var node := MeshInstance3D.new()
		node.name = "Masonry_%d_%d" % [tile.x, tile.y]
		node.position = center
		node.mesh = shell.commit()
		node.material_override = finish
		node.set_meta("shadow_proxy_mesh", hull)
		node.visibility_parent = NodePath("../" + proxy.name)
		city.add_child(node)
		node.owner = city
	city.set_meta("masonry_walls", _walls.size())
	city.set_meta("masonry_recesses", _opening_count)
	_walls.clear()
	_opening_count = 0


static func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


static func _face_basis(face: int) -> Basis:
	return Basis(Vector3.UP, face * PI * 0.5)


static func _wall(shell: SurfaceTool, shadow: SurfaceTool, wall: Wall, pose: Transform3D, paint: Color) -> void:
	for face in 4:
		var placement := pose * Transform3D(_face_basis(face), Vector3.ZERO)
		var span := wall.width(face) * 0.5
		var edge := wall.front(face)
		var height := wall.size.y
		var bounds := Rect2(-span + CORNER, 0.0, (span - CORNER) * 2.0, height)
		_front(shell, placement, edge, bounds, height, wall.faces[face], paint)
		_quad(shell, placement, Vector3(span - CORNER, 0, edge), Vector3(span - CORNER, height, edge),
			Vector3(span, height, edge - CORNER), Vector3(span, 0, edge - CORNER), height, paint)
		_rectangle(shadow, placement, edge, Rect2(-span, 0.0, span * 2.0, height), height, paint)
	var x := wall.size.x * 0.5
	var z := wall.size.z * 0.5
	var y := wall.size.y
	_quad(shadow, pose, Vector3(-x, y, -z), Vector3(x, y, -z), Vector3(x, y, z), Vector3(-x, y, z), y, paint)
	_quad(shell, pose, Vector3(-x + CORNER, y, -z), Vector3(x - CORNER, y, -z),
		Vector3(x - CORNER, y, z), Vector3(-x + CORNER, y, z), y, paint)
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * (x - CORNER), y, -z)
		var b := Vector3(side * x, y, -z + CORNER)
		var c := Vector3(side * x, y, z - CORNER)
		var d := Vector3(side * (x - CORNER), y, z)
		if side > 0.0:
			_quad(shell, pose, a, b, c, d, y, paint)
		else:
			_quad(shell, pose, d, c, b, a, y, paint)


static func _front(surface: SurfaceTool, pose: Transform3D, edge: float, bounds: Rect2, height: float, holes: Array, paint: Color) -> void:
	var rows := PackedFloat32Array([0.0, height])
	holes.sort_custom(func(a: Opening, b: Opening) -> bool: return a.rect.position.x < b.rect.position.x)
	for hole: Opening in holes:
		rows.append(hole.rect.position.y)
		rows.append(hole.rect.end.y)
	rows.sort()
	for row in rows.size() - 1:
		var low := rows[row]
		var high := rows[row + 1]
		if high - low < 0.0001:
			continue
		var middle := (low + high) * 0.5
		var left := bounds.position.x
		for hole: Opening in holes:
			if middle <= hole.rect.position.y or middle >= hole.rect.end.y:
				continue
			_rectangle(surface, pose, edge, Rect2(left, low, hole.rect.position.x - left, high - low), height, paint)
			left = hole.rect.end.x
		_rectangle(surface, pose, edge, Rect2(left, low, bounds.end.x - left, high - low), height, paint)
	for hole: Opening in holes:
		_lining(surface, pose, edge, height, hole, paint)


static func _lining(surface: SurfaceTool, pose: Transform3D, edge: float, height: float, hole: Opening, paint: Color) -> void:
	var opening := Openings.aperture(hole.arch)
	var center := hole.rect.get_center()
	for index in opening.size():
		var a := center + opening[index] * hole.rect.size
		var b := center + opening[(index + 1) % opening.size()] * hole.rect.size
		var inner_a := center.lerp(a, 0.955)
		var inner_b := center.lerp(b, 0.955)
		# Deep jambs and heads are shaded even under an overcast sky.
		var sill := is_equal_approx(a.y, hole.rect.position.y) and is_equal_approx(a.y, b.y)
		var recess_tint := paint.darkened(0.24 if sill else 0.36)
		_quad(surface, pose, Vector3(a.x, a.y, edge), Vector3(b.x, b.y, edge),
			Vector3(inner_b.x, inner_b.y, edge - hole.depth), Vector3(inner_a.x, inner_a.y, edge - hole.depth), height, recess_tint)
		if hole.arch and index > 0 and index < opening.size() - 2:
			_quad(surface, pose, Vector3(a.x, a.y, edge), Vector3(a.x, hole.rect.end.y, edge),
				Vector3(b.x, hole.rect.end.y, edge), Vector3(b.x, b.y, edge), height, paint)


static func _rectangle(surface: SurfaceTool, pose: Transform3D, z: float, area: Rect2, height: float, paint: Color) -> void:
	if area.size.x < 0.0001:
		return
	_quad(surface, pose, Vector3(area.position.x, area.position.y, z), Vector3(area.position.x, area.end.y, z),
		Vector3(area.end.x, area.end.y, z), Vector3(area.end.x, area.position.y, z), height, paint)


static func _quad(surface: SurfaceTool, pose: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, height: float, paint: Color) -> void:
	_triangle(surface, pose, a, b, c, height, paint)
	_triangle(surface, pose, a, c, d, height, paint)


static func _triangle(surface: SurfaceTool, pose: Transform3D, a: Vector3, b: Vector3, c: Vector3, height: float, paint: Color) -> void:
	var axis := (c - a).cross(b - a)
	if axis.length_squared() < 0.0000000001:
		return
	var normal := axis.normalized()
	surface.set_normal(pose.basis * normal)
	surface.set_color(paint)
	for point in [a, b, c]:
		var uv := Vector2(point.z if absf(normal.x) > 0.75 else point.x, -point.y)
		if absf(normal.y) > 0.65:
			uv.y = point.z
		surface.set_uv(uv)
		surface.set_uv2(Vector2(point.y, height - point.y))
		surface.add_vertex(pose * point)
