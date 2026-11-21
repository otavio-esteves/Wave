extends DrivingWorld

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const CarShadow = preload("res://scripts/city/figueiras_car_shadow.gd")
var _normal_materials: Array[StandardMaterial3D] = []
var _detail_finishes: Array[ShaderMaterial] = []
var _leaves: Array[StandardMaterial3D] = []
var _canopies: Array[GeometryInstance3D] = []
var _detail_batches: Dictionary[GeometryInstance3D, float] = {}
var _tree_shade: ShaderMaterial
var _car_shade: ShaderMaterial


func _enter_tree() -> void:
	super._enter_tree()
	$PlayerCar.transform = Layout.spawn()


func _ready() -> void:
	var shadow := $PlayerCar/ContactShadow as MeshInstance3D
	var quad := shadow.mesh as QuadMesh
	_car_shade = quad.material.duplicate()
	shadow.material_override = _car_shade
	CarShadow.install($PlayerCar, $City/StreetAndTerrainSupport)
	for child in $City.get_children():
		var node := child as GeometryInstance3D
		if node == null:
			continue
		if node.visibility_range_end > 0.0:
			_detail_batches[node] = node.visibility_range_end
		var material: Material = node.material_override
		if material is StandardMaterial3D:
			if material.normal_texture != null and material not in _normal_materials:
				_normal_materials.append(material)
			if material.resource_name in ["canopy", "ipe"]:
				_canopies.append(node)
				if material not in _leaves:
					_leaves.append(material)
		elif material is ShaderMaterial:
			if (material.resource_name.begins_with("figueiras_wall_") or material.resource_name.begins_with("figueiras_surface_")) and material not in _detail_finishes:
				_detail_finishes.append(material)
			elif material.resource_name == "figueiras_shade_tree":
				if _tree_shade == null:
					_tree_shade = material.duplicate()
				node.material_override = _tree_shade
	super._ready()


func apply_graphics() -> void:
	var graphics := WaveSettings.graphics
	var environment: Environment = $WorldEnvironment.environment
	# A fixed sky-colored fill and no color-grade pass keep the low-end profile
	# free of the extra cubemap lookups and full-screen adjustment.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if graphics.material_detail else Environment.AMBIENT_SOURCE_COLOR
	environment.adjustment_enabled = graphics.material_detail or graphics.post_effects
	$DayNightCycle.set_sun_shadows_enabled(graphics.shadows)
	_car_shade.set_shader_parameter("opacity", 0.30 if graphics.shadows else 0.42)
	if _tree_shade != null:
		_tree_shade.set_shader_parameter("opacity", 0.12 if graphics.shadows else 0.22)
	for material in _normal_materials:
		material.normal_enabled = graphics.material_detail
	for material in _detail_finishes:
		material.set_shader_parameter("material_detail", graphics.material_detail)
	for leaves in _leaves:
		leaves.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE if graphics.antialiasing else BaseMaterial3D.ALPHA_ANTIALIASING_OFF
		leaves.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if graphics.material_detail else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	for canopy in _canopies:
		canopy.lod_bias = 0.45 if graphics.material_detail else 0.26
	var detail_scale := 0.0
	if graphics.city_lod:
		detail_scale = 1.60 if graphics.city_detail_extended else 0.86
	for node in _detail_batches:
		node.visibility_range_end = _detail_batches[node] * detail_scale
