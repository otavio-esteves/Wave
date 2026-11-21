extends Node

# Ground overlays include crossings (up to 29 mm) and plaza paving (up to 52 mm).
const RECEIVER_LIFT := 0.056
const MOVE_THRESHOLD_SQUARED := 0.000225
const TURN_THRESHOLD := 0.006

var _car: PlayerCar
var _shadow: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _material: Material
var _half_size: Vector2
var _floor_to_world: Transform3D
var _world_to_floor: Transform3D
var _columns := PackedFloat32Array()
var _rows := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _vertices := PackedVector3Array()
var _last_position := Vector2(INF, INF)
var _last_heading := 0.0


static func install(car: PlayerCar, terrain: StaticBody3D) -> void:
	var shadow := car.get_node("ContactShadow") as MeshInstance3D
	var quad := shadow.mesh as QuadMesh
	if quad == null:
		return
	var support := terrain.get_child(0) as CollisionShape3D
	var shape := support.shape as ConcavePolygonShape3D
	if shape == null:
		return
	var projector := new()
	if not projector._index_floor(shape.get_faces()):
		projector.free()
		return
	projector.name = &"TerrainProjection"
	projector.process_physics_priority = car.process_physics_priority + 1
	projector._car = car
	projector._shadow = shadow
	projector._material = quad.material
	projector._half_size = quad.size * 0.5
	projector._floor_to_world = support.global_transform
	projector._world_to_floor = support.global_transform.affine_inverse()
	shadow.top_level = true
	shadow.mesh = projector._mesh
	shadow.add_child(projector)


func _index_floor(faces: PackedVector3Array) -> bool:
	# FigueirasGround bakes two triangles per grid cell in row order:
	# top-left, top-right, bottom-left, top-right, bottom-right, bottom-left.
	if faces.size() < 6 or faces.size() % 6 != 0:
		return false
	_columns.append(faces[0].x)
	for first in range(0, faces.size(), 6):
		if faces[first].z != faces[0].z:
			break
		if faces[first + 1].x <= _columns[-1]:
			return false
		_columns.append(faces[first + 1].x)

	var stride := (_columns.size() - 1) * 6
	if stride == 0 or faces.size() % stride != 0:
		return false
	_rows.append(faces[0].z)
	for first in range(0, faces.size(), stride):
		var next := faces[first + 2].z
		if faces[first].z != _rows[-1] or next <= _rows[-1]:
			return false
		_rows.append(next)

	# Keep one height per vertex. The original collision array stays with physics.
	var width := _columns.size()
	_heights.resize(width * _rows.size())
	for row in _rows.size() - 1:
		for column in width - 1:
			var first := row * stride + column * 6
			var upper_left := faces[first]
			var lower_left := faces[first + 2]
			if upper_left.x != _columns[column] or upper_left.z != _rows[row] or lower_left.z != _rows[row + 1]:
				return false
			_heights[row * width + column] = upper_left.y
			_heights[(row + 1) * width + column] = lower_left.y
		_heights[(row + 1) * width - 1] = faces[(row + 1) * stride - 5].y
		_heights[(row + 2) * width - 1] = faces[(row + 1) * stride - 2].y
	return true


func _physics_process(_delta: float) -> void:
	# PlayerCar still owns contact visibility, including the existing graphics
	# and does the physics step before this cosmetic update.
	if not _shadow.visible or not _car.is_on_floor():
		return
	var position := _car.global_position
	var location := Vector2(position.x, position.z)
	var heading := _car.get_heading()
	if location.distance_squared_to(_last_position) < MOVE_THRESHOLD_SQUARED and absf(angle_difference(_last_heading, heading)) < TURN_THRESHOLD:
		return
	_last_position = location
	_last_heading = heading

	var pose := Transform3D(Basis(Vector3.UP, heading), position)
	var origin := Vector3(-_half_size.x, 0.0, -_half_size.y)
	var dimensions := Vector3(2.0 * _half_size.x, 0.0, 2.0 * _half_size.y)
	var bounds := (_world_to_floor * pose) * AABB(origin, dimensions)
	var floor_to_shadow := pose.affine_inverse() * _floor_to_world
	_vertices.clear()
	for row in range(maxi(0, _rows.bsearch(bounds.position.z) - 1), mini(_rows.size() - 1, _rows.bsearch(bounds.end.z))):
		for column in range(maxi(0, _columns.bsearch(bounds.position.x) - 1), mini(_columns.size() - 1, _columns.bsearch(bounds.end.x))):
			var a := floor_to_shadow * _floor_vertex(column, row)
			var b := floor_to_shadow * _floor_vertex(column + 1, row)
			var c := floor_to_shadow * _floor_vertex(column, row + 1)
			var d := floor_to_shadow * _floor_vertex(column + 1, row + 1)
			_append_triangle(a, b, c)
			_append_triangle(b, d, c)

	_shadow.global_transform = pose
	_mesh.clear_surfaces()
	if _vertices.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for point in _vertices:
		_mesh.surface_set_uv(Vector2(point.x, point.z) / (_half_size * 2.0) + Vector2(0.5, 0.5))
		_mesh.surface_add_vertex(point + Vector3.UP * RECEIVER_LIFT)
	_mesh.surface_end()


func _floor_vertex(column: int, row: int) -> Vector3:
	return Vector3(_columns[column], _heights[row * _columns.size() + column], _rows[row])


func _append_triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var polygon := PackedVector3Array([a, b, c])
	polygon = _clip(polygon, 0, -_half_size.x, 1.0)
	polygon = _clip(polygon, 0, _half_size.x, -1.0)
	polygon = _clip(polygon, 2, -_half_size.y, 1.0)
	polygon = _clip(polygon, 2, _half_size.y, -1.0)
	for index in range(1, polygon.size() - 1):
		if (polygon[index] - polygon[0]).cross(polygon[index + 1] - polygon[0]).length_squared() < 0.000000000001:
			continue
		_vertices.append(polygon[0])
		_vertices.append(polygon[index])
		_vertices.append(polygon[index + 1])


func _clip(polygon: PackedVector3Array, axis: int, edge: float, direction: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in polygon.size():
		var a := polygon[index - 1]
		var b := polygon[index]
		var a_inside := (a[axis] - edge) * direction >= 0.0
		var b_inside := (b[axis] - edge) * direction >= 0.0
		if a_inside != b_inside:
			result.append(a.lerp(b, (edge - a[axis]) / (b[axis] - a[axis])))
		if b_inside:
			result.append(b)
	return result
