extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const CANOPY = preload("res://assets/textures/figueiras/mata-da-serra.png")
const HILLSIDE = preload("res://assets/shaders/jabuticabeiras/hillside.gdshader")
const SEGMENTS := 240
const ORIGIN := Vector3(3.4, 0.4, -Layout.LENGTH * 0.5)
const PROFILE := [Vector2(0.58, -0.22), Vector2(0.65, -0.13), Vector2(0.71, 0.06),
	Vector2(0.77, 0.24), Vector2(0.83, 0.47), Vector2(0.89, 0.72), Vector2(0.95, 0.89), Vector2(1.0, 1.0)]


func build(parent: Node3D) -> void:
	_ridge(parent, "Serra", 252.0, 54.0, 2.16, Color("829ca9"), Color("688391"), 0.24)
	_ridge(parent, "MataDoVale", 198.0, 39.0, 4.31, Color("778d89"), Color("4a6766"), 0.54)
	_ridge(parent, "Morro", 146.0, 28.0, 0.80, Color("7c855f"), Color("435e53"), 0.73)


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
	var repeats := roundf(radius * TAU / 19.0)
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
			var colors := [_tone(angle, lower, radius, height, phase), _tone(next, lower, radius, height, phase),
				_tone(next, upper, radius, height, phase), _tone(angle, upper, radius, height, phase)]
			var uv := [Vector2(band_start, lower.x * radius / 17.0), Vector2(band_end, lower.x * radius / 17.0),
				Vector2(band_end, upper.x * radius / 17.0), Vector2(band_start, upper.x * radius / 17.0)]
			for corner: int in [0, 2, 1, 0, 3, 2]:
				surface.set_color(colors[corner])
				surface.set_uv(uv[corner])
				surface.add_vertex(sites[corner])
	surface.index()
	var ridge := MeshInstance3D.new()
	ridge.name = label
	ridge.mesh = surface.commit()
	ridge.position = ORIGIN
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ridge)


func _crest(angle: float, radius: float, height: float, phase: float) -> Vector3:
	var long_wave := 0.57 + 0.25 * sin(angle * 3.0 + phase) + 0.18 * sin(angle * 5.0 - phase)
	var valley := pow(maxf(cos(angle + 1.47), 0.0), 3.0)
	var nursery := pow(maxf(cos(angle - 1.57), 0.0), 3.0)
	var opening := maxf(valley, nursery)
	var hills := maxf(0.14, long_wave + 0.098 * sin(angle * 11.0 + phase)
		+ 0.075 * sin(angle * 19.0 - phase)) * (1.0 - 0.97 * opening)
	hills += 0.023 * sin(angle * 53.0 + phase) + 0.009 * sin(angle * 97.0)
	var edge := Vector2.from_angle(angle) * radius * (1.0 + 0.11 * sin(angle * 4.0 + phase))
	return Vector3(edge.x, 1.1 + hills * height - 16.0 * opening, edge.y)


func _slope(crest: Vector3, angle: float, profile: Vector2, phase: float) -> Vector3:
	var fold := (1.0 - absf(profile.y)) * (0.075 * sin(angle * 9.0 - phase)
		+ 0.029 * sin(angle * 17.0) + 0.013 * sin(angle * 31.0 + profile.x * 9.0))
	var distance := profile.x + fold
	return Vector3(crest.x * distance, crest.y * profile.y + crest.y * fold, crest.z * distance)


func _tone(angle: float, profile: Vector2, radius: float, height: float, phase: float) -> Color:
	var position := _slope(_crest(angle, radius, height, phase), angle, profile, phase)
	var edge := angle + 0.014
	var tangent := _slope(_crest(edge, radius, height, phase), edge, profile, phase) - position
	var uphill := Vector3(Vector2.from_angle(angle).x, height / radius * 2.1, Vector2.from_angle(angle).y)
	var normal := tangent.cross(uphill).normalized()
	var incidence := clampf(normal.dot(Layout.SUN_DIRECTION.normalized()), 0.0, 1.0)
	var light := 0.68 + incidence * 0.32 + 0.06 * sin(angle * 10.0 - phase + profile.y * 2.0)
	var meadow := smoothstep(0.26, 0.79, (sin(angle * 18.0 + profile.y * 5.4 + phase) + 1.0) * 0.5)
	return Color(smoothstep(-0.04, 1.0, profile.y), light, meadow)
