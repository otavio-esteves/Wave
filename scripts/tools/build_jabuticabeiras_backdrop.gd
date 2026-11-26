extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const CANOPY = preload("res://assets/textures/figueiras/mata-da-serra.png")
const HILLSIDE = preload("res://assets/shaders/jabuticabeiras/hillside.gdshader")
const SEGMENTS := 144
const PROFILE := [Vector2(0.60, -0.17), Vector2(0.70, 0.06), Vector2(0.79, 0.34),
	Vector2(0.89, 0.71), Vector2(1.0, 1.0)]


func build(parent: Node3D) -> void:
	_ridge(parent, "Serra", 245.0, 34.0, 2.16, Color("a0b7c3"), Color("8da7b1"), 0.15)
	_ridge(parent, "MataDoVale", 181.0, 26.0, 4.31, Color("879e9b"), Color("708b87"), 0.42)
	_ridge(parent, "Morro", 140.0, 17.0, 0.80, Color("7a927a"), Color("637e6a"), 0.63)


func _ridge(parent: Node3D, label: String, radius: float, height: float,
		phase: float, crest_color: Color, slope_color: Color, detail: float) -> void:
	var material := ShaderMaterial.new()
	material.resource_name = label
	material.shader = HILLSIDE
	material.set_shader_parameter("fold_color", slope_color)
	material.set_shader_parameter("crown_color", crest_color)
	material.set_shader_parameter("texture_strength", detail)
	material.set_shader_parameter("canopy_map", CANOPY)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var repeats := roundf(radius * TAU / 25.0)
	var depth_scale := radius * 0.045
	for index in SEGMENTS:
		var angle := TAU * index / SEGMENTS
		var next := TAU * (index + 1) / SEGMENTS
		var crest := _crest(angle, radius, height, phase)
		var next_crest := _crest(next, radius, height, phase)
		for band in PROFILE.size() - 1:
			var lower: Vector2 = PROFILE[band]
			var upper: Vector2 = PROFILE[band + 1]
			var band_start := float(index) * repeats / SEGMENTS
			var band_end := float(index + 1) * repeats / SEGMENTS
			var sites := [_slope(crest, angle, lower, phase), _slope(next_crest, next, lower, phase),
				_slope(next_crest, next, upper, phase), _slope(crest, angle, upper, phase)]
			var colors := [_tone(angle, lower.y, phase), _tone(next, lower.y, phase),
				_tone(next, upper.y, phase), _tone(angle, upper.y, phase)]
			var uv := [Vector2(band_start, lower.x * depth_scale), Vector2(band_end, lower.x * depth_scale),
				Vector2(band_end, upper.x * depth_scale), Vector2(band_start, upper.x * depth_scale)]
			for corner: int in [0, 2, 1, 0, 3, 2]:
				surface.set_color(colors[corner])
				surface.set_uv(uv[corner])
				surface.add_vertex(sites[corner])
	surface.index()
	var ridge := MeshInstance3D.new()
	ridge.name = label
	ridge.mesh = surface.commit()
	ridge.position = Vector3(3.4, 0.4, -Layout.LENGTH * 0.5)
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ridge)


func _crest(angle: float, radius: float, height: float, phase: float) -> Vector3:
	var long_wave := 0.57 + 0.25 * sin(angle * 3.0 + phase) + 0.18 * sin(angle * 5.0 - phase)
	var hills := maxf(0.19, long_wave + 0.082 * sin(angle * 11.0 + phase) + 0.044 * sin(angle * 19.0 - phase))
	hills += 0.020 * sin(angle * 53.0 + phase)
	var edge := Vector2.from_angle(angle) * radius * (1.0 + 0.11 * sin(angle * 4.0 + phase))
	return Vector3(edge.x, 2.5 + hills * height, edge.y)


func _slope(crest: Vector3, angle: float, profile: Vector2, phase: float) -> Vector3:
	var fold := (1.0 - absf(profile.y)) * (0.054 * sin(angle * 9.0 - phase) + 0.028 * sin(angle * 17.0))
	var distance := profile.x + fold
	return Vector3(crest.x * distance, crest.y * profile.y + crest.y * fold, crest.z * distance)


func _tone(angle: float, height: float, phase: float) -> Color:
	var light := 0.92 + 0.063 * sin(angle * 10.0 - phase + height * 2.0) + 0.017 * cos(angle * 27.0)
	return Color(smoothstep(0.05, 1.0, height), light, 0.0)
