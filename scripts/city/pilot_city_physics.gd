extends Node

# Keep authored shapes, but only nearby building/tree bodies occupy the physics
# broad phase. Terrain, streets and curbs stay active everywhere.
const RADIUS := 320.0
const TILE := 128.0
const RETAIN_RADIUS := RADIUS + TILE
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
				_compact_shapes(body)
			authored_shapes += original_count
	city.set_meta("authored_solid_shape_count", authored_shapes)


static func _compact_shapes(body: StaticBody3D) -> void:
	# Shape owners already carry the native collision data; static authored
	# solids do not need an extra Node3D for every shape after instantiation.
	for child in body.get_children():
		if not child is CollisionShape3D or child.get_script() != null or child.get_child_count() != 0:
			continue
		var shape: Shape3D = child.shape
		var placement: Transform3D = child.transform
		var disabled: bool = child.disabled
		child.free()
		if shape == null:
			continue
		var owner_id := body.create_shape_owner(body)
		body.shape_owner_add_shape(owner_id, shape)
		body.shape_owner_set_transform(owner_id, placement)
		body.shape_owner_set_disabled(owner_id, disabled)


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
