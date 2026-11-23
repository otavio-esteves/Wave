extends Node3D

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const CYCLE := 34.0
const STOP_SETBACK := 2.35
var _period := 0.0
var _lenses: Array[Transform3D] = []
var _stops: Array[Vector2] = []
var _lights: Array[MultiMesh] = []
var _aspects := PackedInt32Array()
var _centers := positions()


static func positions() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-63, -54), Vector2(64, -54), Vector2(-63, 52), Vector2(64, 52)])


static func crossing(center: Vector2, heading: Vector2) -> float:
	return (Layout.ROW_HALF_WIDTHS[Layout.ROWS.find(center.y)] if heading.y != 0 else Layout.COLUMN_HALF_WIDTHS[Layout.COLUMNS.find(center.x)]) + Layout.junction_radius(Layout.COLUMNS.find(center.x), Layout.ROWS.find(center.y)) + 0.9


func _ready() -> void:
	process_physics_priority = -3
	for center in _centers:
		for arm in 4:
			var heading := Vector2(sin(arm * PI * 0.5), cos(arm * PI * 0.5)).round()
			var across := heading.orthogonal()
			var cross_width: float = Layout.COLUMN_HALF_WIDTHS[Layout.COLUMNS.find(center.x)] if arm % 2 == 0 else Layout.ROW_HALF_WIDTHS[Layout.ROWS.find(center.y)]
			var site := center + heading * (crossing(center, heading) + 1.8) + across * (cross_width + 1.04)
			_stops.append(center + heading * (crossing(center, heading) + STOP_SETBACK))
			var forward := Vector3(-heading.x, 0, -heading.y)
			var lamp_arm := Vector3(heading.y, 0, -heading.x)
			var lens_center := Layout.surface_point(site, 4.76) + lamp_arm * 2.38 + forward * 0.172
			var scale := Vector3(1, 1, 0.57) if arm % 2 == 0 else Vector3(0.57, 1, 1)
			_lenses.append(Transform3D(Basis.from_scale(scale), lens_center))
	if DisplayServer.get_name() != "headless":
		_build_lights()
	_aspects.resize(_centers.size() * 2)
	_aspects.fill(-1)
	_update_aspects()


func _build_lights() -> void:
	var lens := SphereMesh.new()
	lens.radius = 0.076
	lens.height = 0.152
	lens.radial_segments = 8
	lens.rings = 4
	for color: String in ["7aff6c", "ffbd42", "ff3d27"]:
		var bulb := StandardMaterial3D.new()
		bulb.albedo_color = Color(color).darkened(0.33)
		bulb.emission_enabled = true
		bulb.emission = Color(color)
		bulb.emission_energy_multiplier = 2.8
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = lens
		batch.instance_count = _lenses.size()
		var node := MultiMeshInstance3D.new()
		node.multimesh = batch
		node.material_override = bulb
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_lights.append(batch)


func _physics_process(delta: float) -> void:
	_period = fposmod(_period + delta, CYCLE)
	_update_aspects()


func aspect(intersection: int, east_west: bool) -> int:
	return _aspects[intersection * 2 + int(east_west)]


func _phase(intersection: int, east_west: bool) -> int:
	var time := fposmod(_period + intersection * 4.0 + (0.0 if east_west else 16.0), CYCLE)
	var green := 12.0 if east_west else 9.0
	if time < green:
		return 0
	if time < green + 2.0:
		return 1
	return 2


func _update_aspects() -> void:
	var changed := false
	for intersection in _centers.size():
		for axis in 2:
			var face := _phase(intersection, axis == 1)
			var key := intersection * 2 + axis
			if face != _aspects[key]:
				_aspects[key] = face
				changed = true
	if not changed or _lights.is_empty():
		return
	var counts := Vector3i.ZERO
	for intersection in _centers.size():
		for arm in 4:
			var face := _aspects[intersection * 2 + arm % 2]
			var transform := _lenses[intersection * 4 + arm].translated(Vector3.UP * (face - 1) * 0.25)
			_lights[face].set_instance_transform(counts[face], transform)
			counts[face] += 1
	for face in _lights.size():
		_lights[face].visible_instance_count = counts[face]


func speed_limit(site: Vector2, direction: Vector2, speed: float, desired: float, half_length: float, grip: float) -> float:
	var east_west := absf(direction.x) > absf(direction.y)
	var arm := (3 if direction.x > 0.0 else 1) if east_west else (2 if direction.y > 0.0 else 0)
	var limit := desired
	for index in _centers.size():
		var approach := _centers[index] - site
		var lateral := absf(approach.y if east_west else approach.x)
		if lateral > (8.1 if east_west and _centers[index].y == Layout.AVENUE else 5.0):
			continue
		var to_line := (_stops[index * 4 + arm] - site).dot(direction) - half_length
		if to_line < -0.65 or to_line > 36.0 or approach.dot(direction) < 0.0:
			continue
		var signal_aspect := aspect(index, east_west)
		if signal_aspect == 2 or (signal_aspect == 1 and to_line > speed * speed / (11.0 * grip) + 1.0):
			var stopping_room := maxf(0.0, to_line - 0.28 - speed * 0.044)
			limit = minf(limit, sqrt(stopping_room * 7.8 * grip))
	return limit
