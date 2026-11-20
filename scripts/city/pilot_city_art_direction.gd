extends RefCounted

# A compact finish layer for the saved city. Each shared material gets at most
# one private copy per world; authored meshes, instance colours and collision stay
# intact. All profiles retain the albedo finish, while normal maps still follow
# the independent material-detail preference in PilotCityWorld.
const ASPHALT_ALBEDO = preload("res://assets/textures/pilot/finish-asphalt-albedo.res")
const ASPHALT_NORMAL = preload("res://assets/textures/pilot/finish-asphalt-normal.res")
const GRASS_ALBEDO = preload("res://assets/textures/pilot/finish-grass-albedo.res")
const GRASS_NORMAL = preload("res://assets/textures/pilot/finish-grass-normal.res")
const WINDOW_INTERIOR = preload("res://assets/textures/pilot/finish-window-interior-albedo.res")


static func apply(world: Node3D) -> void:
	var city := world.get_node("City") as Node3D
	var copies: Dictionary = {}
	for geometry: GeometryInstance3D in city.find_children("*", "GeometryInstance3D", true, false):
		var material := geometry.material_override as StandardMaterial3D
		if material == null or not _has_finish(material.resource_name):
			continue
		if material.get_meta("wave_surface_finish", false):
			continue
		if not copies.has(material):
			var copy := material.duplicate() as StandardMaterial3D
			_finish(copy)
			copies[material] = copy
		geometry.material_override = copies[material]
	var cycle := world.get_node_or_null("DayNightCycle")
	if cycle != null and cycle.has_method("remap_materials"):
		cycle.remap_materials(copies)
	city.set_meta("surface_finish_revision", "2026-11-19-ground-and-interiors-v3")
	if not copies.is_empty() or not city.has_meta("surface_finish_materials"):
		city.set_meta("surface_finish_materials", copies.size())


static func _has_finish(name: String) -> bool:
	return name in ["asphalt", "grass", "sidewalk", "curb_concrete", "paving", "roof", "timber", "stone", "downtown_stone", "downtown_brick", "downtown_glass", "downtown_glass_dark", "residential_glass", "residential_glass_lit", "commercial_glass", "glass", "tree_leaves", "hedge", "aged_plaster", "oxidized_metal"]


static func _finish(material: StandardMaterial3D) -> void:
	material.set_meta("wave_surface_finish", true)
	# Continue using the standard material variants and shared textures so this
	# does not introduce a pass, a light or a draw call for any existing batch.
	match material.resource_name:
		"asphalt":
			material.albedo_texture = ASPHALT_ALBEDO
			material.normal_texture = ASPHALT_NORMAL
			material.normal_enabled = true
			material.normal_scale = 0.12
			material.albedo_color = Color("e6f2ff")
			material.roughness = 0.86
			material.metallic_specular = 0.28
			# Streets already carry continuous world coordinates at 0.25 / m.
			# A two-metre photograph tile keeps aggregate at centimetre scale.
			material.uv1_scale = Vector3.ONE * 2.0
		"grass":
			material.albedo_texture = GRASS_ALBEDO
			material.normal_texture = GRASS_NORMAL
			material.normal_enabled = true
			material.normal_scale = 0.35
			material.albedo_color = Color("c0c2ba")
			material.roughness = 0.98
			material.metallic_specular = 0.12
			material.uv1_scale = Vector3.ONE * 0.55
		"sidewalk", "curb_concrete", "paving":
			material.albedo_color = material.albedo_color.lerp(Color("c4c6bd"), 0.28)
			material.roughness = 0.91
			material.normal_scale = 0.24
		"roof":
			material.albedo_color = Color("af7c62")
			material.roughness = 0.86
		"stone", "downtown_stone", "downtown_brick", "aged_plaster":
			material.roughness = 0.88
			material.metallic_specular = 0.25
		"timber":
			material.roughness = 0.78
			material.metallic_specular = 0.25
		"downtown_glass", "downtown_glass_dark":
			material.roughness = 0.20
			material.metallic = 0.35
			material.metallic_specular = 0.65
		"residential_glass", "residential_glass_lit":
			# Existing opaque panes now show an original recessed room plate.
			# Reflectance stays on the standard shader; only occupied panes gain
			# textured emission, still driven by the existing day/night cycle.
			material.albedo_texture = WINDOW_INTERIOR
			material.albedo_color = Color("c2ced4")
			material.roughness = 0.20
			material.metallic = 0.04
			material.metallic_specular = 0.65
			material.texture_repeat = false
			if material.resource_name == "residential_glass_lit":
				material.emission_texture = WINDOW_INTERIOR
				material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				material.uv1_scale = Vector3(-1, 1, 1)
				material.uv1_offset = Vector3(1, 0, 0)
		"commercial_glass", "glass":
			material.roughness = 0.19
			material.metallic_specular = 0.65
		"tree_leaves", "hedge":
			material.roughness = 0.98
			material.metallic_specular = 0.10
		"oxidized_metal":
			material.roughness = 0.72
			material.metallic = 0.32
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
