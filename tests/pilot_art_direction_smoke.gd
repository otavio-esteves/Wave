extends SceneTree

const Art = preload("res://scripts/city/pilot_city_art_direction.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	var city := Node3D.new()
	city.name = "City"
	world.add_child(city)
	var asphalt := StandardMaterial3D.new()
	asphalt.resource_name = "asphalt"
	asphalt.vertex_color_use_as_albedo = true
	var first := _surface(city, asphalt)
	var second := _surface(city, asphalt)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "residential_glass_lit"
	glass.emission_enabled = true
	glass.emission_energy_multiplier = 0.23
	var pane := _surface(city, glass)
	var unoccupied := StandardMaterial3D.new()
	unoccupied.resource_name = "residential_glass"
	var dark_pane := _surface(city, unoccupied)
	var cycle := preload("res://scripts/city/neighborhood_day_night.gd").new()
	cycle.name = "DayNightCycle"
	cycle._emissive.append(glass)
	world.add_child(cycle)
	var mesh := first.mesh
	var position := first.transform
	Art.apply(world)
	_check(first.material_override == second.material_override and first.material_override != asphalt, "ground finish retains shared materials while leaving the authored resource private")
	_check(first.mesh == mesh and first.transform == position and city.get_child_count() == 4, "surface finish adds no geometry, nodes, transforms or render passes")
	var finished := first.material_override as StandardMaterial3D
	_check(finished.resource_name == "asphalt" and finished.vertex_color_use_as_albedo and finished.next_pass == null, "finish preserves material classification and authored district colours")
	_check(finished.albedo_texture.get_width() == 512 and finished.normal_texture.get_height() == 512, "road detail uses compact offline 512-pixel textures")
	_check(asphalt.albedo_texture == null and asphalt.uv1_scale == Vector3.ONE, "entering a finished world never mutates the saved material resource")
	_check(is_equal_approx(pane.material_override.emission_energy_multiplier, 0.23) and cycle._emissive[0] == pane.material_override, "night lighting remains bound to the material actually drawn after finish copies")
	_check(pane.material_override.albedo_texture == Art.WINDOW_INTERIOR and pane.material_override.emission_texture == Art.WINDOW_INTERIOR and pane.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "occupied residential panes retain an opaque interior plate with matching textured emission")
	_check(pane.material_override.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY, "occupied interior emission multiplies the room mask so dark recesses stay dark")
	_check(dark_pane.material_override.albedo_texture == Art.WINDOW_INTERIOR and not dark_pane.material_override.emission_enabled and dark_pane.material_override.emission_texture == null, "unoccupied residential interiors remain dark rather than becoming another glowing window")
	cycle._emissive[0].emission_energy_multiplier = 0.31
	_check(is_equal_approx(pane.material_override.emission_energy_multiplier, 0.31), "live lighting changes still reach finished occupied windows")
	var shared := first.material_override
	var count: int = city.get_meta("surface_finish_materials")
	Art.apply(world)
	_check(first.material_override == shared and city.get_meta("surface_finish_materials") == count, "reapplying art direction is idempotent and cannot multiply material copies")
	world.free()
	print("Pilot art direction: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _surface(city: Node3D, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	node.material_override = material
	city.add_child(node)
	return node


func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
