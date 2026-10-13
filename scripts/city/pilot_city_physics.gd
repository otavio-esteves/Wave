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


func _ready() -> void:
	process_physics_priority = -30
	var world := get_parent()
	target = world.get_node("PlayerCar")
	for body in world.get_node("City").get_children():
		if not body is StaticBody3D or not str(body.name).begins_with("Solids_"):
			continue
		var parts := str(body.name).split("_")
		var bounds := Rect2(Vector2(int(parts[1]), int(parts[2])) * TILE, Vector2.ONE * TILE).grow(32.0)
		var count := body.get_child_count()
		total_shapes += count
		bodies.append({"body": body, "bounds": bounds, "active": true, "shapes": count})
	active_bodies = bodies.size()
	active_shapes = total_shapes
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
	var point := Vector2(_last_position.x, _last_position.z)
	var space: RID = get_parent().get_world_3d().space
	for record in bodies:
		var bounds: Rect2 = record.bounds
		var closest := point.clamp(bounds.position, bounds.end)
		var radius := RETAIN_RADIUS if record.active else RADIUS
		var wanted := point.distance_squared_to(closest) <= radius * radius
		if wanted == record.active:
			continue
		PhysicsServer3D.body_set_space(record.body.get_rid(), space if wanted else RID())
		record.active = wanted
		active_bodies += 1 if wanted else -1
		active_shapes += record.shapes if wanted else -record.shapes
