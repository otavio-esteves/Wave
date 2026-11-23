extends Node

# Keep the receiver above the baked paint and paving, which reach 54 mm.
const RECEIVER_LIFT := 0.056
const MOVE_THRESHOLD_SQUARED := 0.000225
const TURN_THRESHOLD := 0.006
const INITIAL_CAPACITY := 96
const RECEIVER_MARGIN := 1.18

var _car: PlayerCar
var _shadow: MeshInstance3D
var _mesh := ArrayMesh.new()
var _half_size: Vector2
var _floor_to_world: Transform3D
var _world_to_floor: Transform3D
var _columns := PackedFloat32Array()
var _rows := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _refined: Dictionary = {}
var _vertices := PackedVector3Array()
var _capacity := 0
var _last_vertex_count := 0
var _last_position := Vector2(INF, INF)
var _last_heading := 0.0
var _receiver_center := Vector2.INF
var _receiver_radius := 0.0
var receiver_updates := 0


static func install(car: PlayerCar, terrain: StaticBody3D) -> void:
	var shadow := car.get_node("ContactShadow") as MeshInstance3D
	var quad := shadow.mesh as QuadMesh
	if quad == null:
		return
	var projector := new()
	var floor_to_world := terrain.global_transform
	var indexed := false
	if terrain.has_meta("terrain_grid"):
		indexed = projector._read_grid(terrain.get_meta("terrain_grid"))
	elif terrain.get_child_count() > 0:
		var support := terrain.get_child(0) as CollisionShape3D
		if support != null and support.shape is ConcavePolygonShape3D:
			floor_to_world = support.global_transform
			indexed = projector._index_floor(support.shape.get_faces())
	if not indexed:
		projector.free()
		return
	projector.name = &"TerrainProjection"
	projector._car = car
	projector._shadow = shadow
	projector._half_size = quad.size * 0.5
	projector._receiver_radius = projector._half_size.length() + RECEIVER_MARGIN
	projector._floor_to_world = floor_to_world
	projector._world_to_floor = floor_to_world.affine_inverse()
	shadow.top_level = true
	shadow.mesh = projector._mesh
	shadow.set_instance_shader_parameter("projected_half_size", projector._half_size)
	shadow.add_child(projector)


func _read_grid(grid: Dictionary) -> bool:
	_columns = grid.columns
	_rows = grid.rows
	_heights = grid.heights
	_refined = grid.refined
	return _columns.size() >= 2 and _rows.size() >= 2 and _heights.size() == _columns.size() * _rows.size()


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


func _process(_delta: float) -> void:
	if not _shadow.visible or not _car.is_on_floor():
		return
	var position := _car.global_position
	var location := Vector2(position.x, position.z)
	var heading := _car.get_heading()
	if location.distance_squared_to(_last_position) < MOVE_THRESHOLD_SQUARED and absf(angle_difference(_last_heading, heading)) < TURN_THRESHOLD:
		return
	_last_position = location
	_last_heading = heading
	if location.distance_squared_to(_receiver_center) >= RECEIVER_MARGIN * RECEIVER_MARGIN:
		_receiver_center = location
		_rebuild_receiver(position)
	var local := location - _receiver_center
	_shadow.set_instance_shader_parameter("projected_frame", Vector4(local.x, local.y, cos(heading), sin(heading)))


func _rebuild_receiver(position: Vector3) -> void:
	# The shadow travels over a stationary section of the authoritative road
	# mesh. Only upload geometry again when it approaches the section's edge.
	var pose := Transform3D(Basis.IDENTITY, position)
	var origin := Vector3(-_receiver_radius, 0.0, -_receiver_radius)
	var dimensions := Vector3(_receiver_radius * 2.0, 0.0, _receiver_radius * 2.0)
	var bounds := (_world_to_floor * pose) * AABB(origin, dimensions)
	var floor_to_shadow := pose.affine_inverse() * _floor_to_world
	_vertices.clear()
	for row in range(maxi(0, _rows.bsearch(bounds.position.z) - 1), mini(_rows.size() - 1, _rows.bsearch(bounds.end.z))):
		for column in range(maxi(0, _columns.bsearch(bounds.position.x) - 1), mini(_columns.size() - 1, _columns.bsearch(bounds.end.x))):
			var cell := Vector2i(column, row)
			if _refined.has(cell):
				var faces: PackedVector3Array = _refined[cell]
				for first in range(0, faces.size(), 3):
					_append_triangle(floor_to_shadow * faces[first], floor_to_shadow * faces[first + 1], floor_to_shadow * faces[first + 2])
				continue
			var a := floor_to_shadow * _floor_vertex(column, row)
			var b := floor_to_shadow * _floor_vertex(column + 1, row)
			var c := floor_to_shadow * _floor_vertex(column, row + 1)
			var d := floor_to_shadow * _floor_vertex(column + 1, row + 1)
			_append_triangle(a, b, c)
			_append_triangle(b, d, c)

	_shadow.global_transform = pose
	_upload_projection()
	receiver_updates += 1


func _upload_projection() -> void:
	var count := _vertices.size()
	if count == 0 and _capacity == 0:
		return
	if count > _capacity:
		_capacity = maxi(_capacity, INITIAL_CAPACITY)
		while _capacity < count:
			_capacity *= 2
		_mesh.clear_surfaces()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var slots := PackedVector3Array()
		slots.resize(_capacity)
		arrays[Mesh.ARRAY_VERTEX] = slots
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		_mesh.surface_set_material(0, _shadow.material_override)
		_last_vertex_count = 0
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	if count > 0:
		minimum = _vertices[0]
		maximum = minimum
		for point in _vertices:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	_mesh.custom_aabb = AABB(minimum, maximum - minimum)
	# Clear any previously used slots at the end of the same upload. Their
	# degenerate triangles have no coverage.
	_vertices.resize(maxi(_last_vertex_count, count))
	if not _vertices.is_empty():
		_mesh.surface_update_vertex_region(0, 0, _vertices.to_byte_array())
	_last_vertex_count = count


func _floor_vertex(column: int, row: int) -> Vector3:
	return Vector3(_columns[column], _heights[row * _columns.size() + column], _rows[row])


func _append_triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var low := a.min(b).min(c)
	var high := a.max(b).max(c)
	if low.x >= _receiver_radius or high.x <= -_receiver_radius or low.z >= _receiver_radius or high.z <= -_receiver_radius:
		return
	if low.x >= -_receiver_radius and high.x <= _receiver_radius and low.z >= -_receiver_radius and high.z <= _receiver_radius:
		_write_triangle(a, b, c)
		return
	var polygon := PackedVector3Array([a, b, c])
	polygon = _clip(polygon, 0, -_receiver_radius, 1.0)
	polygon = _clip(polygon, 0, _receiver_radius, -1.0)
	polygon = _clip(polygon, 2, -_receiver_radius, 1.0)
	polygon = _clip(polygon, 2, _receiver_radius, -1.0)
	for index in range(1, polygon.size() - 1):
		_write_triangle(polygon[0], polygon[index], polygon[index + 1])


func _write_triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).length_squared() < 0.000000000001:
		return
	var lift := Vector3.UP * RECEIVER_LIFT
	_vertices.append(a + lift)
	_vertices.append(b + lift)
	_vertices.append(c + lift)


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
