extends DrivingWorld

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Route = preload("res://scripts/city/figueiras_route.gd")
const Foliage = preload("res://scripts/city/figueiras_foliage.gd")
const CarShadow = preload("res://scripts/city/figueiras_car_shadow.gd")
const Cabin = preload("res://scripts/city/figueiras_cabin.gd")
const Impacts = preload("res://scripts/city/figueiras_impacts.gd")
const Weather = preload("res://scripts/city/figueiras_weather.gd")
const TrafficAudio = preload("res://scripts/city/figueiras_traffic_audio.gd")
const Signals = preload("res://scripts/city/figueiras_signals.gd")
const Traffic = preload("res://scripts/city/figueiras_traffic.gd")
const TireEffects = preload("res://scripts/city/figueiras_tire_effects.gd")
const StaticShapes = preload("res://scripts/city/pilot_city_physics.gd")
const STREET_FINISH = preload("res://assets/shaders/figueiras/street_finish.gdshader")
const STREET_ECONOMY = preload("res://assets/shaders/figueiras/street_economy.gdshader")
const MEADOW_FINISH = preload("res://assets/shaders/figueiras/meadow_finish.gdshader")
const MEADOW_ECONOMY = preload("res://assets/shaders/figueiras/meadow_economy.gdshader")
const PAVEMENT_FINISH = preload("res://assets/shaders/figueiras/pavement_finish.gdshader")
const PAVEMENT_ECONOMY = preload("res://assets/shaders/figueiras/pavement_economy.gdshader")
const UTILITY_COVER = preload("res://assets/shaders/figueiras/utility_cover.gdshader")
const UTILITY_COVER_ECONOMY = preload("res://assets/shaders/figueiras/utility_cover_economy.gdshader")
const SHADOW_ATLAS_SIZE := "rendering/lights_and_shadows/directional_shadow/size"
const SHADOW_ATLAS_16_BITS := "rendering/lights_and_shadows/directional_shadow/16_bits"
const BALANCED_SHADOW_ATLAS := 2048
const RENDER_SCALES := [1.0, 0.86, 0.74]
var _normal_materials: Array[StandardMaterial3D] = []
var _detail_finishes: Array[ShaderMaterial] = []
var _leaves: Array[StandardMaterial3D] = []
var _canopies: Array[GeometryInstance3D] = []
var _parked_cars: Array[GeometryInstance3D] = []
var _detail_batches: Dictionary[GeometryInstance3D, float] = {}
var _terrain_lod: Array[GeometryInstance3D] = []
var _terrain_distant: Array[GeometryInstance3D] = []
var _city_mesh_lod: Array[GeometryInstance3D] = []
var _shadow_sources: Array[GeometryInstance3D] = []
var _shadow_sectors: Array[GeometryInstance3D] = []
var _tree_shade: ShaderMaterial
var _car_shade: ShaderMaterial
var _tire_effects: Node3D
var _foliage: Node
var _cabin: Node3D
var _market_lights: Array[OmniLight3D] = []
var _ambient_sounds: Array[AudioStreamPlayer3D] = []
var _restore_interpolation := false
var _shadow_atlas_size := 0
var _adaptive_scale := false
var _native_scale := 1.0
var _scale_level := 0
var _scale_seconds := 0.0
var _scale_frames := 0
var _late_frames := 0
var _steady_windows := 0
var _scale_settle := 0.0
var _frame_budget := 0.032
var _budget_headlights := false
var _headlight_refresh := 0.0
@onready var _terrain: StaticBody3D = $City/StreetAndTerrainSupport
@onready var _driver: PlayerCar = $PlayerCar


func _enter_tree() -> void:
	# Set the interpolation state before the packed district enters the
	# renderer. Only player and camera opt in to interpolation in this scene.
	_restore_interpolation = not get_tree().physics_interpolation
	if _restore_interpolation:
		get_tree().physics_interpolation = true
	StaticShapes.compact_shapes($City/SolidObjects)
	var support: StaticBody3D = $City/StreetAndTerrainSupport
	if support.has_meta(StaticShapes.BAKED_SHAPES):
		StaticShapes.compact_shapes(support)
	super._enter_tree()
	$PlayerCar.transform = Layout.spawn()
	$PlayerCar.terrain_surface = _terrain_surface
	$PlayerCar.road_support = support
	$ChaseCamera.terrain_preview = _preview_terrain


func _exit_tree() -> void:
	stop_audio()
	if _shadow_atlas_size > 0:
		_set_shadow_atlas(ProjectSettings.get_setting_with_override(SHADOW_ATLAS_SIZE))
	if _scale_level > 0:
		get_viewport().scaling_3d_scale = _native_scale
	if _restore_interpolation:
		get_tree().physics_interpolation = false


func _terrain_surface(point: Vector3, body: Object) -> Dictionary:
	if body != _terrain:
		return {}
	return Layout.driving_surface(Vector2(point.x, point.z), _driver.road_wetness > 0.0)


func _preview_terrain(site: Vector2, direction: Vector2, distance: float) -> Vector3:
	var link := Layout.urban_sample(site)
	var scenic := Layout.scenic_sample(site)
	var local_edge := Layout.urban_edge(link)
	var scenic_edge := Layout.scenic_edge(scenic)
	var local_road := Layout.urban_routes()[int(link.x)] if local_edge < 0.0 else null
	if Layout.Baixada.BOUNDS.has_point(site):
		var district := Layout.district_sample(site)
		var district_edge := Layout.Baixada.edge(district)
		if district_edge < minf(local_edge, 0.0):
			link = district
			local_edge = district_edge
			local_road = Layout.district_routes()[int(district.x)]
	var scenic_road := Layout.scenic_routes()[int(scenic.x)] if scenic_edge < 0.0 else null
	var local_ahead := _road_preview_span(local_road, link.y, local_edge, direction, distance)
	var scenic_ahead := _road_preview_span(scenic_road, scenic.y, scenic_edge, direction, distance)
	if maxf(local_ahead.y, scenic_ahead.y) > 0.07:
		var use_scenic := scenic_ahead.y > local_ahead.y
		var road := scenic_road if use_scenic else local_road
		var sample := scenic if use_scenic else link
		var ahead := scenic_ahead if use_scenic else local_ahead
		var first := sample.y + ahead.x * 0.24
		var last := sample.y + ahead.x
		var side := clampf(sample.z, -road.half_width + 0.4, road.half_width - 0.4)
		var transition := 37.0 if use_scenic else 14.0
		var in_core := minf(first, last) >= transition and maxf(first, last) <= road.length - transition
		var near_height := _preview_road_height(road, first, side, in_core, use_scenic)
		var far_height := _preview_road_height(road, last, side, in_core, use_scenic)
		var sight_line := road.offset_at(last, side) - site
		return Vector3((far_height - near_height) / absf(last - first), ahead.y, -direction.angle_to(sight_line))
	# Grid streets have no route spline. Get grade and pavement confidence
	# from the same pair of samples, including the exit of a covered road.
	var far := Layout.ground_sample(site + direction * distance)
	var near := Layout.ground_sample(site + direction * distance * 0.30)
	var confidence := 1.0 - smoothstep(-0.8, 2.15, maxf(far.y, near.y))
	return Vector3((far.x - near.x) / (distance * 0.70), confidence, 0.0) if confidence > 0.0 else Vector3.ZERO


func _road_preview_span(road: Route, station: float, edge: float, direction: Vector2, distance: float) -> Vector2:
	if road == null:
		return Vector2.ZERO
	var alignment := direction.dot(road.direction_at(station))
	var remaining := road.length - station if alignment >= 0.0 else station
	var confidence := smoothstep(0.75, 0.96, absf(alignment)) * smoothstep(0.4, 2.3, -edge)
	confidence *= smoothstep(3.0, maxf(10.0, distance * 0.70), remaining)
	return Vector2(minf(distance, remaining) * signf(alignment), confidence)


func _preview_road_height(road: Route, station: float, lateral: float, in_core: bool, scenic: bool) -> float:
	if not in_core:
		return Layout.height_at(road.offset_at(station, lateral))
	return Layout.scenic_surface_height(road, station, lateral) if scenic else road.height_at(station)


func _ready() -> void:
	add_to_group("wave_audio")
	_native_scale = get_viewport().scaling_3d_scale
	var shadow := $PlayerCar/ContactShadow as MeshInstance3D
	var quad := shadow.mesh as QuadMesh
	_car_shade = quad.material.duplicate()
	shadow.material_override = _car_shade
	CarShadow.install($PlayerCar, _terrain)
	for marker: Marker3D in $City.find_children("MarketLight_*", "Marker3D", false, false):
		var lamp := OmniLight3D.new()
		lamp.position = marker.position
		lamp.omni_range = 13.5
		lamp.omni_attenuation = 1.4
		lamp.light_color = Color("ffd1a0")
		lamp.light_specular = 0.10
		lamp.hide()
		_market_lights.append(lamp)
		add_child(lamp)
	_tire_effects = TireEffects.new()
	_tire_effects.name = "TireEffects"
	_tire_effects.process_physics_priority = 3
	add_child(_tire_effects)
	var signals := Signals.new()
	signals.name = "Signals"
	add_child(signals)
	var traffic := Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
	var passing := TrafficAudio.new()
	passing.name = "TrafficAudio"
	add_child(passing)
	for child in $City.get_children():
		if child is AudioStreamPlayer3D:
			_ambient_sounds.append(child)
		var node := child as GeometryInstance3D
		if node == null:
			continue
		if node.has_meta("shadow_batched"):
			_shadow_sources.append(node)
		if node.has_meta("shadow_sector"):
			_shadow_sectors.append(node)
		if node is Label3D:
			node.visibility_range_end = clampf(node.font_size * node.pixel_size * 139.0, 24.0, 175.0)
			node.visibility_range_end_margin = 4.0
		if node.visibility_range_end > 0.0:
			_detail_batches[node] = node.visibility_range_end
		if node.has_meta("terrain_lod"):
			_terrain_lod.append(node)
		if node.has_meta("terrain_distant"):
			_terrain_distant.append(node)
		if node.has_meta("city_mesh_lod"):
			_city_mesh_lod.append(node)
		var material: Material = node.material_override
		if material != null and material.resource_name == "parked_car":
			_parked_cars.append(node)
		if material != null and _include_in_mirror(node, material.resource_name):
			node.layers |= Cabin.ROAD_MIRROR_LAYER
		if material is StandardMaterial3D:
			if material.normal_texture != null and material not in _normal_materials:
				_normal_materials.append(material)
			# The elevated camera can cross branches above the solid trunk's
			# collision. Dither only foliage within its immediate view space.
			if material.resource_name in ["bark", "canopy", "ipe", "bush"] and material.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED:
				material.distance_fade_min_distance = 2.6
				material.distance_fade_max_distance = 4.0
				material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			if material.resource_name in ["canopy", "ipe", "bush"]:
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
	_foliage = Foliage.new()
	_foliage.name = "FoliageDistance"
	add_child(_foliage)
	_foliage.configure($City)
	$PlayerCar.car_reset.connect(_foliage.refresh)
	var weather := Weather.new()
	weather.name = "Weather"
	for finish in _detail_finishes:
		if finish.resource_name.begins_with("figueiras_surface_"):
			weather.finishes.append(finish)
			finish.set_shader_parameter("wetness", 0.0)
	add_child(weather)
	var impacts := Impacts.new()
	impacts.name = "Impacts"
	add_child(impacts)
	_cabin = Cabin.new()
	_cabin.name = "Instruments"
	$PlayerCar/Visuals/Body.add_child(_cabin)
	var traffic_meshes := traffic.get_node_or_null("TrafficMeshes")
	if traffic_meshes != null:
		_cabin.mirror_camera_changed.connect(traffic_meshes.set_rearview_camera)
	super._ready()


func stop_audio() -> void:
	for sound in _ambient_sounds:
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null


func _include_in_mirror(node: GeometryInstance3D, material: String) -> bool:
	var label := str(node.name)
	if label.begins_with("Ground_"):
		return not (label.begins_with("Ground_shade_") or label.begins_with("Ground_utility_cover_")
			or label.begins_with("Ground_storm_drain_") or label.begins_with("Ground_tactile_"))
	if material.begins_with("figueiras_wall_"):
		return true
	return material in ["figueiras_architecture", "roof", "roof_gray", "stone", "forest", "distant_canopy", "figueiras_tree_impostor", "parked_car", "figueiras_lake"]


func _process(delta: float) -> void:
	if _adaptive_scale:
		_update_render_scale(delta)
	_tire_effects.set_daylight($DayNightCycle.daylight)
	if _budget_headlights:
		_headlight_refresh -= delta
		if _headlight_refresh <= 0.0:
			_headlight_refresh = 0.10
			var sun_elevation: float = $DayNightCycle.sun_direction.y
			var overcast: float = $Weather.intensity
			var beam := 1.0 - smoothstep(0.035, 0.22, sun_elevation * lerpf(1.0, 0.58, overcast))
			var site := Vector2(_driver.global_position.x, _driver.global_position.z)
			_driver.set_headlight_beam(maxf(beam, Layout.rain_shelter(site)))
	if not _market_lights.is_empty():
		var player := _driver.global_position
		var twilight: float = maxf(1.0 - $DayNightCycle.daylight, $Weather.intensity * 0.62)
		for lamp in _market_lights:
			lamp.visible = twilight > 0.33 and lamp.global_position.distance_squared_to(player) < 49.0 * 49.0
			if lamp.visible:
				lamp.light_energy = 0.82 * smoothstep(0.33, 0.92, twilight)


func apply_graphics() -> void:
	var graphics := WaveSettings.graphics
	_budget_headlights = graphics.city_lod
	_headlight_refresh = 0.0
	if not _budget_headlights:
		_driver.set_headlight_beam(1.0)
	_adaptive_scale = graphics.adaptive_3d and DisplayServer.get_name() != "headless"
	_frame_budget = 0.037 if graphics.fps_limit == 30 else 0.034
	_set_render_scale(0)
	var environment: Environment = $WorldEnvironment.environment
	# The day/night controller supplies a color-matched fill in the two
	# reference profiles. Keep sky radiance filtering for Quality.
	var sky_radiance: bool = graphics.material_detail and graphics.post_effects
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if sky_radiance else Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if sky_radiance else Environment.REFLECTION_SOURCE_DISABLED
	# The background shader draws the visible sky at the viewport resolution.
	# Only the Quality profile uses the filtered cubemap for scene lighting.
	environment.sky.radiance_size = Sky.RADIANCE_SIZE_64 if sky_radiance else Sky.RADIANCE_SIZE_32
	environment.adjustment_enabled = graphics.material_detail or graphics.post_effects
	environment.glow_enabled = graphics.post_effects
	_tire_effects.set_material_detail(graphics.material_detail)
	$Weather.set_material_detail(graphics.material_detail)
	_foliage.apply_graphics(graphics)
	_cabin.apply_graphics()
	var sun := $Sun as DirectionalLight3D
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if graphics.post_effects else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 98.0 if graphics.post_effects else 58.0
	if graphics.shadows:
		var project_size: int = ProjectSettings.get_setting_with_override(SHADOW_ATLAS_SIZE)
		_set_shadow_atlas(project_size if graphics.post_effects else mini(BALANCED_SHADOW_ATLAS, project_size))
	var batched_shadows: bool = graphics.shadows and not graphics.post_effects
	for source in _shadow_sources:
		source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if batched_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for sector in _shadow_sectors:
		sector.visible = batched_shadows
	$ChaseCamera.camera.far = 2900.0
	$DayNightCycle.set_sun_shadows_enabled(graphics.shadows, not graphics.post_effects)
	_car_shade.set_shader_parameter("opacity", 0.30 if graphics.shadows else 0.42)
	if _tree_shade != null:
		_tree_shade.set_shader_parameter("opacity", 0.12 if graphics.shadows else 0.22)
	for material in _normal_materials:
		material.normal_enabled = graphics.material_detail
	var detailed_street: bool = graphics.material_detail or graphics.shadows
	var street_shader := STREET_FINISH if detailed_street else STREET_ECONOMY
	var meadow_shader := MEADOW_FINISH if detailed_street else MEADOW_ECONOMY
	var pavement_shader := PAVEMENT_FINISH if detailed_street else PAVEMENT_ECONOMY
	var cover_shader := UTILITY_COVER if detailed_street else UTILITY_COVER_ECONOMY
	for material in _detail_finishes:
		if material.resource_name.begins_with("figueiras_surface_"):
			var shader := street_shader
			match int(material.get_shader_parameter("surface_kind")):
				1:
					if material.resource_name == "figueiras_surface_pavement":
						shader = pavement_shader
				3: shader = cover_shader
				5: shader = meadow_shader
			if material.shader != shader:
				material.shader = shader
			material.set_shader_parameter("tree_contact_strength", 0.55 if graphics.shadows else 1.0)
		material.set_shader_parameter("material_detail", graphics.material_detail)
	for leaves in _leaves:
		leaves.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE if graphics.antialiasing else BaseMaterial3D.ALPHA_ANTIALIASING_OFF
		leaves.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if graphics.material_detail else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	for canopy in _canopies:
		canopy.lod_bias = 0.45 if graphics.material_detail else 0.26
	for mesh in _city_mesh_lod:
		mesh.lod_bias = 1.1 if not graphics.city_lod else (0.64 if graphics.city_detail_extended else 0.36)
	var vehicle_lod := 1.0 if not graphics.city_lod else (0.80 if graphics.city_detail_extended else 0.43)
	for part: MeshInstance3D in $PlayerCar/Visuals.find_children("*", "MeshInstance3D"):
		if part.mesh != null and part.mesh.resource_path.begins_with("res://assets/models/hatch_1000/"):
			part.lod_bias = vehicle_lod
	for chunk in _terrain_lod:
		chunk.lod_bias = 1.1 if not graphics.city_lod else (0.42 if graphics.city_detail_extended else 0.20)
	for group in _terrain_distant:
		group.visible = graphics.city_lod
		group.visibility_range_begin = 385.0 if graphics.city_detail_extended else 276.0
	for parked in _parked_cars:
		parked.lod_bias = 1.0 if not graphics.city_lod else (0.65 if graphics.city_detail_extended else 0.43)
	var detail_scale := 1.42 if not graphics.city_lod else (1.09 if graphics.city_detail_extended else 0.66)
	for node in _detail_batches:
		var authored_end := _detail_batches[node]
		var local_scale := detail_scale
		if graphics.city_lod and authored_end == 126.0 and not node is Label3D:
			local_scale = 0.76 if graphics.city_detail_extended else 0.54
		if node.name.begins_with("Ground_shade_building_"):
			authored_end = 82.0
		node.visibility_range_end = authored_end * local_scale


func _update_render_scale(delta: float) -> void:
	if not get_window().has_focus():
		_scale_seconds = 0.0
		_scale_frames = 0
		_late_frames = 0
		_steady_windows = 0
		return
	if _scale_settle > 0.0:
		_scale_settle -= delta
		return
	_scale_seconds += delta
	_scale_frames += 1
	_late_frames += int(delta > _frame_budget)
	if _scale_seconds < 1.0:
		return
	var late_share := float(_late_frames) / _scale_frames
	var average := _scale_seconds / _scale_frames
	_scale_seconds = 0.0
	_scale_frames = 0
	_late_frames = 0
	if late_share > 0.22 and _scale_level < RENDER_SCALES.size() - 1:
		_set_render_scale(_scale_level + 1)
		return
	# Restore one step after a sustained recovery. The longer recovery time
	# keeps the viewport from reallocating its buffers at every junction.
	var recovery_budget := minf(_frame_budget - 0.003, 0.0339)
	_steady_windows = _steady_windows + 1 if late_share < 0.06 and average < recovery_budget else 0
	if _steady_windows >= 5 and _scale_level > 0:
		_set_render_scale(_scale_level - 1)


func _set_render_scale(level: int) -> void:
	if level != _scale_level:
		_scale_level = level
		get_viewport().scaling_3d_scale = _native_scale * RENDER_SCALES[level]
	_scale_settle = 0.85
	_scale_seconds = 0.0
	_scale_frames = 0
	_late_frames = 0
	_steady_windows = 0


func _set_shadow_atlas(size: int) -> void:
	if _shadow_atlas_size == size:
		return
	var depth_16_bits: bool = ProjectSettings.get_setting_with_override(SHADOW_ATLAS_16_BITS)
	RenderingServer.directional_shadow_atlas_set_size(size, depth_16_bits)
	_shadow_atlas_size = size
