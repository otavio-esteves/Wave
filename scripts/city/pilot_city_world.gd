extends DrivingWorld

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var _surface_nodes: Array[GeometryInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _cached_graphics := false
var _last_lod := -1.0
var startup_timings: Array[Dictionary] = []
var _startup_started_usec := 0
var _startup_previous_usec := 0
var _trace_startup := "--profile-startup" in OS.get_cmdline_user_args()


func _enter_tree() -> void:
	_mark_startup("world-enter")
	super._enter_tree()
	# Set the authored spawn before PlayerCar records its reset transform.
	$PlayerCar.transform = Layout.spawn()
	var city := get_node("City") as Node3D
	preload("res://scripts/city/pilot_batch_compaction.gd").prepare(city)
	_mark_startup("batches-compacted")
	preload("res://scripts/city/pilot_road_seams.gd").prepare(city)
	_mark_startup("road-seams-installed")
	var local_spawn: Vector3 = city.transform.affine_inverse() * $PlayerCar.position
	preload("res://scripts/city/pilot_city_physics.gd").prepare(city, local_spawn)
	_mark_startup("physics-prepared")


func _ready() -> void:
	_mark_startup("children-ready")
	preload("res://scripts/city/pilot_city_art_direction.gd").apply(self)
	_mark_startup("surface-finish")
	super._ready()
	_mark_startup("world-base-ready")
	var physics := preload("res://scripts/city/pilot_city_physics.gd").new()
	physics.name = "CityPhysics"
	add_child(physics)
	_mark_startup("physics-resident")
	var visual_lod := preload("res://scripts/city/pilot_city_visual_lod.gd").new()
	visual_lod.name = "CityVisualLOD"
	add_child(visual_lod)
	_mark_startup("building-lod-ready")
	var foliage_lod := preload("res://scripts/city/pilot_foliage_lod.gd").new()
	foliage_lod.name = "CityFoliageLOD"
	add_child(foliage_lod)
	_mark_startup("foliage-lod-ready")
	var reflection := preload("res://scripts/city/vehicle_reflection.gd").new()
	reflection.name = "VehicleReflection"
	add_child(reflection)
	var minimap := preload("res://scripts/city/city_minimap.gd").new()
	minimap.name = "CityMinimap"
	minimap.car = $PlayerCar
	$HUD/Overlay.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.offset_left = 20
	minimap.offset_top = -223
	minimap.offset_right = 230
	minimap.offset_bottom = -20
	$HUD/Overlay/Telemetry.offset_top = -104
	var map := preload("res://scripts/city/city_map.gd").new()
	map.name = "CityMap"
	map.car = $PlayerCar
	map.hud = $HUD
	$HUD/Overlay.add_child(map)
	$HUD.city_map = map
	var button := Button.new()
	button.text = "Mapa da cidade"
	$HUD.buttons.add_child(button)
	$HUD.buttons.move_child(button, 3)
	button.pressed.connect(map.open_map)

	var trip := preload("res://scripts/city/pilot_city_trip.gd").new()
	trip.name = "CityTrip"
	add_child(trip)
	minimap.trip = trip
	map.trip = trip
	var trip_button := Button.new()
	trip_button.text = "Passeio: praça e oficina"
	trip_button.custom_minimum_size.y = 42
	$HUD.buttons.add_child(trip_button)
	$HUD.buttons.move_child(trip_button, 3)
	trip_button.pressed.connect(func() -> void:
		trip.start()
		$HUD.set_paused(false)
	)
	_mark_startup("world-ready")


func _mark_startup(phase: String) -> void:
	if not _trace_startup:
		return
	var now := Time.get_ticks_usec()
	if _startup_started_usec == 0:
		_startup_started_usec = now
		_startup_previous_usec = now
	var record := {"phase": phase, "elapsed_ms": (now - _startup_started_usec) / 1000.0, "phase_ms": (now - _startup_previous_usec) / 1000.0}
	startup_timings.append(record)
	_startup_previous_usec = now
	print("City startup: " + JSON.stringify(record))


func apply_graphics() -> void:
	super.apply_graphics()
	# Moonlight stays soft; avoid a second directional shadow atlas.
	var moon := get_node_or_null("Moon") as DirectionalLight3D
	if moon != null:
		moon.shadow_enabled = false
	var settings := get_node("/root/WaveSettings")
	# Reflections follow the evolving sky in all profiles.
	# Micro-normal maps belong to Medium/High; Economy retains the same geometry/albedo.
	var detailed := bool(settings.graphics["material_detail"])
	if not _cached_graphics:
		_cache_graphics()
	var compact_detail := bool(settings.graphics["city_lod"]) and not bool(settings.graphics["city_detail_extended"])
	var lod := 0.2 if compact_detail else 0.5
	if lod != _last_lod:
		for surface in _surface_nodes:
			surface.lod_bias = lod
		_last_lod = lod
	for material in _materials:
		material.shading_mode = material.get_meta("pilot_original_shading") if detailed else BaseMaterial3D.SHADING_MODE_PER_VERTEX
		if material.normal_texture != null:
			material.normal_enabled = detailed
	var visual_lod := get_node_or_null("CityVisualLOD")
	if visual_lod != null:
		visual_lod.set_render_profile(bool(settings.graphics["city_lod"]), bool(settings.graphics["city_detail_extended"]))
	var foliage_lod := get_node_or_null("CityFoliageLOD")
	if foliage_lod != null:
		foliage_lod.set_render_profile(bool(settings.graphics["city_lod"]), bool(settings.graphics["city_detail_extended"]))
	var reflection := get_node_or_null("VehicleReflection")
	if reflection != null:
		reflection.set_enabled(detailed)


func _cache_graphics() -> void:
	var seen: Dictionary = {}
	for geometry: GeometryInstance3D in $City.find_children("*", "GeometryInstance3D", true, false):
		if geometry.get_meta("surface_kind", "") in ["Terrain", "Streets", "Sidewalks", "SidewalksFar", "BackgroundLandscape"]:
			_surface_nodes.append(geometry)
		var material := geometry.material_override as StandardMaterial3D
		if material != null and material.resource_name == "tree_leaves":
			_surface_nodes.append(geometry)
		if material == null or seen.has(material):
			continue
		seen[material] = true
		if not material.has_meta("pilot_original_shading"):
			material.set_meta("pilot_original_shading", material.shading_mode)
		_materials.append(material)
	_cached_graphics = true
