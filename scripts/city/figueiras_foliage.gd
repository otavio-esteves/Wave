extends Node

const Bake = preload("res://scripts/city/figueiras_foliage_bake.gd")
const DISTANCE_HYSTERESIS := 8.0
const CELL_SIZE := Vector2.ONE * Bake.SIZE
var _cells: Dictionary[Vector2i, Dictionary] = {}
var _detailed: Dictionary[Vector2i, bool] = {}
var _distant_batches: Array[MultiMeshInstance3D] = []
var _plants: Array[PlantBatch] = []
var _canopies: Array[PlantBatch] = []
var _near := 51.0
var _plant_near := 20.0
var _next_update := 0.0
var _position := Vector2.INF


class PlantBatch:
	var batch: MultiMesh
	var detailed_mesh: Mesh
	var distant_mesh: Mesh
	var bounds: Rect2

	func _init(node: MultiMeshInstance3D, lod: StringName) -> void:
		batch = node.multimesh
		detailed_mesh = batch.mesh
		distant_mesh = node.get_meta(lod)
		var aabb := node.global_transform * batch.custom_aabb
		bounds = Rect2(Vector2(aabb.position.x, aabb.position.z), Vector2(aabb.size.x, aabb.size.z))

	func update(site: Vector2, near: float) -> void:
		var distance := site.distance_squared_to(site.clamp(bounds.position, bounds.end))
		var limit := near + DISTANCE_HYSTERESIS if batch.mesh == detailed_mesh else near
		set_detailed(distance <= limit * limit)

	func set_detailed(detailed: bool) -> void:
		var target := detailed_mesh if detailed else distant_mesh
		if batch.mesh != target:
			batch.mesh = target


func configure(city: Node3D) -> void:
	for node in city.get_children():
		if node is MultiMeshInstance3D and node.has_meta("distant_plant_mesh"):
			_plants.append(PlantBatch.new(node, &"distant_plant_mesh"))
		if node is MultiMeshInstance3D and node.has_meta("flat_canopy_mesh"):
			_canopies.append(PlantBatch.new(node, &"flat_canopy_mesh"))
		if node.has_meta("foliage_distant"):
			_distant_batches.append(node)
		if not node.has_meta("foliage_cell"):
			continue
		var cell: Vector2i = node.get_meta("foliage_cell")
		if not _cells.has(cell):
			_cells[cell] = {"proxy": null, "geometry": []}
		if node.has_meta("foliage_proxy"):
			_cells[cell].proxy = node
		else:
			_cells[cell].geometry.append(node)
	for data in _cells.values():
		if data.proxy != null:
			_set_detail(data, false)


func apply_graphics(graphics: Dictionary) -> void:
	var short_detail: bool = graphics.city_lod and not graphics.city_detail_extended
	_near = 16.0 if short_detail else 23.0
	_plant_near = 11.0 if short_detail else 19.0
	if graphics.material_detail:
		_near = 68.0 if graphics.post_effects else (28.0 if graphics.city_lod else 36.0)
		_plant_near = 48.0 if graphics.post_effects else (22.0 if graphics.city_lod else 30.0)
	for canopy in _canopies:
		canopy.set_detailed(graphics.material_detail or not graphics.city_lod)
	for batch in _distant_batches:
		batch.visible = graphics.city_lod
		batch.visibility_range_begin = _near + 102.0
	refresh()


func _exit_tree() -> void:
	for plant in _plants:
		plant.set_detailed(true)
	for canopy in _canopies:
		canopy.set_detailed(true)


func _process(delta: float) -> void:
	_next_update -= delta
	if _next_update > 0.0:
		return
	_next_update = 0.13
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var site := Vector2(camera.global_position.x, camera.global_position.z)
		if _position.distance_squared_to(site) > 4.0 * 4.0:
			_update(site)


func refresh() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_update(Vector2(camera.global_position.x, camera.global_position.z))


func _update(site: Vector2) -> void:
	_position = site
	for plant in _plants:
		plant.update(site, _plant_near)
	var far_radius := _near + DISTANCE_HYSTERESIS
	var margin := Vector2.ONE * far_radius
	var first := Vector2i(((site - margin) / Bake.SIZE).floor())
	var last := Vector2i(((site + margin) / Bake.SIZE).floor())
	var nearby: Dictionary[Vector2i, bool] = {}
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, z)
			if not _cells.has(cell) or _cells[cell].proxy == null:
				continue
			var origin := Vector2(cell) * Bake.SIZE
			var distance := site.distance_squared_to(site.clamp(origin, origin + CELL_SIZE))
			var was_detailed := _detailed.has(cell)
			var limit := far_radius if was_detailed else _near
			if distance < limit * limit:
				nearby[cell] = true
				if not was_detailed:
					_set_detail(_cells[cell], true)
	for cell in _detailed:
		if not nearby.has(cell):
			_set_detail(_cells[cell], false)
	_detailed = nearby


func _set_detail(data: Dictionary, detailed: bool) -> void:
	data.proxy.visible = not detailed
	for batch: MultiMeshInstance3D in data.geometry:
		batch.visible = detailed
