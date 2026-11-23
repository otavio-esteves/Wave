extends Node

# Keep authored shapes, but only nearby building/tree bodies occupy the physics
# broad phase. Terrain, streets and curbs stay active everywhere.
const RADIUS := 320.0
const TILE := 128.0
const RETAIN_RADIUS := RADIUS + TILE
const BAKED_SHAPES := &"baked_solid_shapes"
var target: PlayerCar
var bodies: Array[Dictionary] = []
var active_bodies := 0
var active_shapes := 0
var total_shapes := 0
var _timer := 0.0
var _last_position := Vector3.INF


static func prepare(city: Node3D, local_position: Vector3) -> void:
	# Called by the world before City enters the tree: distant solids never
	# populate the physics space during startup, rather than being removed later.
	var point := Vector2(local_position.x, local_position.z)
	var authored_shapes := 0
	for body in city.get_children():
		if body is StaticBody3D and str(body.name).begins_with("Solids_"):
			var bounds := _bounds(str(body.name))
			var wanted := point.distance_squared_to(point.clamp(bounds.position, bounds.end)) <= RETAIN_RADIUS * RETAIN_RADIUS
			body.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE
			body.process_mode = Node.PROCESS_MODE_INHERIT if wanted else Node.PROCESS_MODE_DISABLED
			var original_count := shape_count(body)
			if not body.is_inside_tree():
				compact_shapes(body)
			authored_shapes += original_count
	city.set_meta("authored_solid_shape_count", authored_shapes)


static func bake_shapes(body: StaticBody3D) -> void:
	# Shape owners are native runtime state. Store their inputs in the packed map.
	var shapes: Array[Shape3D] = []
	var placements: Array[Transform3D] = []
	var disabled := PackedByteArray()
	for child in body.get_children():
		if not _is_plain_shape(child) or child.shape == null:
			continue
		shapes.append(child.shape)
		placements.append(child.transform)
		disabled.append(int(child.disabled))
		child.free()
	if not shapes.is_empty():
		body.set_meta(BAKED_SHAPES, {"shapes": shapes, "placements": placements, "disabled": disabled})


static func compact_shapes(body: StaticBody3D) -> void:
	if body.has_meta(BAKED_SHAPES):
		var baked: Dictionary = body.get_meta(BAKED_SHAPES)
		for index in baked.shapes.size():
			_add_shape(body, baked.shapes[index], baked.placements[index], baked.disabled[index] != 0)
		body.remove_meta(BAKED_SHAPES)
	# Older maps still provide their authored nodes.
	for child in body.get_children():
		if not _is_plain_shape(child):
			continue
		var shape: Shape3D = child.shape
		var placement: Transform3D = child.transform
		var disabled: bool = child.disabled
		child.free()
		if shape != null:
			_add_shape(body, shape, placement, disabled)


static func _is_plain_shape(node: Node) -> bool:
	return node is CollisionShape3D and node.get_script() == null and node.get_child_count() == 0


static func _add_shape(body: StaticBody3D, shape: Shape3D, placement: Transform3D, disabled: bool) -> void:
	if shape is ConvexPolygonShape3D and body.name.begins_with("Solids_"):
		var wall := _center_wall_hull(shape)
		if not wall.is_empty():
			shape = wall[0]
			placement *= wall[1]
	var owner_id := body.create_shape_owner(body)
	body.shape_owner_add_shape(owner_id, shape)
	body.shape_owner_set_transform(owner_id, placement)
	if disabled:
		body.shape_owner_set_disabled(owner_id, disabled)


static func _center_wall_hull(source: ConvexPolygonShape3D) -> Array:
	# Early pilot maps stored the corners of consecutive boxes for each
	# straight wall. Rebuild the extruded cross-section near the origin.
	var points := source.points
	if points.size() < 8 or points.size() % 8 != 0:
		return []
	var x_edge := points[4] - points[0]
	var z_edge := points[1] - points[0]
	if x_edge.length_squared() < 0.001 or z_edge.length_squared() < 0.001:
		return []
	var x_axis := Vector3(x_edge.x, 0.0, x_edge.z).normalized()
	if points.size() > 8:
		var span := points[points.size() - 8] - points[0]
		var direction := Vector3(span.x, 0.0, span.z).normalized()
		if direction != Vector3.ZERO:
			x_axis = direction if absf(x_axis.dot(direction)) > 0.707 else Vector3.UP.cross(direction)
	var origin := (points[0] + points[-1]) * 0.5
	var frame := Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)), origin)
	var inverse := frame.affine_inverse()
	var low := Vector3.INF
	var high := -Vector3.INF
	var local := PackedVector3Array()
	for point in points:
		var p := inverse * point
		local.append(p)
		low = low.min(p)
		high = high.max(p)
	var along := 0 if high.x - low.x >= high.z - low.z else 2
	var across := 2 - along
	var section := PackedVector2Array()
	for p in local:
		if minf(absf(p[across] - low[across]), absf(p[across] - high[across])) > 0.002:
			return []
		section.append(Vector2(p[along], p.y).snapped(Vector2(0.001, 0.001)))
	var outline := Geometry2D.convex_hull(section)
	if outline.size() < 4:
		return []
	var hull := PackedVector3Array()
	for index in outline.size() - 1:
		var p := Vector3.ZERO
		p[along] = outline[index].x
		p.y = outline[index].y
		p[across] = low[across]
		hull.append(p)
		p[across] = high[across]
		hull.append(p)
	var shape := ConvexPolygonShape3D.new()
	shape.margin = source.margin
	shape.points = hull
	return [shape, frame]


static func shape_count(body: StaticBody3D) -> int:
	var count := 0
	for owner_id in body.get_shape_owners():
		count += body.shape_owner_get_shape_count(owner_id)
	return count


static func _bounds(body_name: String) -> Rect2:
	var parts := body_name.split("_")
	return Rect2(Vector2(int(parts[1]), int(parts[2])) * TILE, Vector2.ONE * TILE).grow(32.0)


func _ready() -> void:
	process_physics_priority = -30
	var world := get_parent()
	target = world.get_node("PlayerCar")
	for body in world.get_node("City").get_children():
		if not body is StaticBody3D or not str(body.name).begins_with("Solids_"):
			continue
		var bounds := _bounds(str(body.name))
		var count := shape_count(body)
		total_shapes += count
		var active: bool = body.process_mode != Node.PROCESS_MODE_DISABLED
		bodies.append({"body": body, "bounds": bounds, "active": active, "shapes": count})
		active_bodies += 1 if active else 0
		active_shapes += count if active else 0
	target.car_reset.connect(refresh)
	refresh()


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.25:
		_timer = 0.0
		if target.global_position.distance_squared_to(_last_position) > 16.0 * 16.0:
			refresh()


func refresh() -> void:
	_last_position = target.global_position
	var local_position: Vector3 = get_parent().get_node("City").to_local(_last_position)
	var point := Vector2(local_position.x, local_position.z)
	for record in bodies:
		var bounds: Rect2 = record.bounds
		var closest := point.clamp(bounds.position, bounds.end)
		var radius := RETAIN_RADIUS if record.active else RADIUS
		var wanted := point.distance_squared_to(closest) <= radius * radius
		if wanted == record.active:
			continue
		record.body.process_mode = Node.PROCESS_MODE_INHERIT if wanted else Node.PROCESS_MODE_DISABLED
		record.active = wanted
		active_bodies += 1 if wanted else -1
		active_shapes += record.shapes if wanted else -record.shapes
