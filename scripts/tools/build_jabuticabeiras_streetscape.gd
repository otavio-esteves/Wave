extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const Ground = preload("res://scripts/tools/build_jabuticabeiras_ground.gd")
const Masonry = preload("res://scripts/tools/build_jabuticabeiras_masonry.gd")
const M = Masonry.Finish

var _street
var _masonry: Masonry
var _frame: Transform3D


func _init(street, masonry: Masonry) -> void:
	_street = street
	_masonry = masonry


func build() -> void:
	_bicycle()
	_shelter()


func _bicycle() -> void:
	_install_bike_materials()
	var station := 17.43
	var offset := Layout.half_width(station) + 1.39
	var yaw: float = _street.rotation_for_cross(station) - PI * 0.43
	var pos := _site(station, offset)
	var lean := Basis(Vector3.RIGHT, -0.094)
	_frame = Transform3D(Basis(Vector3.UP, yaw) * lean, pos + Vector3.UP * 0.008)
	var rear := Vector3(-0.55, 0.322, 0.0)
	var front := Vector3(0.55, 0.322, 0.0)
	for wheel: Vector3 in [rear, front]:
		var rim := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), wheel)
		for part in [Vector2i(0, 0), Vector2i(1, -1), Vector2i(1, 1)]:
			var element := rim
			element.origin += Vector3.BACK * float(part.y) * 0.009
			var mesh := "bike_tire" if part.x == 0 else "bike_rim"
			var material := "bike_rubber" if part.x == 0 else "bike_chrome"
			_street.add_transformed_instance(mesh, material, _frame * element)
		_beam(wheel + Vector3.FORWARD * 0.058, wheel + Vector3.BACK * 0.058, 0.025, "bike_chrome")
		for index in 14:
			var angle := index * TAU / 14.0
			var target := wheel + Vector3(cos(angle) * 0.296, sin(angle) * 0.296, 0.0)
			var hub := wheel + Vector3.BACK * (0.036 if index % 2 else -0.036)
			_beam(hub, target, 0.0024, "bike_chrome")
	var crank := Vector3(-0.096, 0.321, 0.0)
	var saddle := Vector3(-0.272, 0.852, 0.0)
	var steering := Vector3(0.314, 0.810, 0.0)
	_beam(crank, saddle, 0.024, "bike_paint")
	var knee := steering + Vector3(0.046, -0.152, 0)
	var run := crank.lerp(knee, 0.53) - Vector3.UP * 0.067
	_beam(crank, run, 0.027, "bike_paint")
	_beam(run, knee, 0.026, "bike_paint")
	_beam(knee, steering, 0.026, "bike_paint")
	for side: float in [-1.0, 1.0]:
		var plane := Vector3.BACK * 0.054 * side
		_beam(rear + plane, crank + plane * 0.78, 0.012, "bike_paint")
		_beam(rear + plane, saddle + Vector3.DOWN * 0.16, 0.012, "bike_paint")
		_beam(front + plane, knee + plane * 1.16, 0.016, "bike_paint")
		_beam(crank + plane, crank + plane * 3.41 + Vector3.UP * (0.045 * side), 0.011, "bike_chrome")
		_bike_box(crank + plane * 3.1 + Vector3.UP * 0.041 * side, Vector3(0.094, 0.018, 0.064), "bike_rubber")
	_beam(crank + Vector3.BACK * 0.024, rear + Vector3.BACK * 0.043, 0.013, "dark_iron")
	_beam(saddle, saddle + Vector3.UP * 0.075, 0.016, "bike_chrome")
	_bike_box(saddle + Vector3(0.014, 0.093, 0.0), Vector3(0.237, 0.048, 0.135), "bike_rubber")
	var post := steering + Vector3(0.022, 0.198, 0.0)
	_beam(steering, post, 0.018, "bike_chrome")
	for side: float in [-1.0, 1.0]:
		var grip := post + Vector3(-0.048, 0.012, side * 0.27)
		var bend := post + Vector3(0.037, 0.017, side * 0.16)
		_beam(post, bend, 0.013, "bike_chrome")
		_beam(bend, grip, 0.013, "bike_chrome")
		_beam(grip, grip + Vector3.BACK * side * 0.081, 0.018, "bike_rubber")
	_beam(Vector3(-0.32, 0.29, 0.021), Vector3(-0.47, 0.011, 0.13), 0.010, "bike_chrome")
	for axle: Vector3 in [rear, front]:
		var before := axle + Vector3(-0.309, 0.071, 0.0)
		for section in 14:
			var angle := 2.92 - (section + 1.0) / 14.0 * 2.80
			var vertex := axle + Vector3(cos(angle), sin(angle), 0) * 0.340
			_beam(before, vertex, 0.014, "bike_fender")
			before = vertex
	_basket(Vector3(0.54, 0.82, 0.0))


func _install_bike_materials() -> void:
	var tires := TorusMesh.new()
	tires.inner_radius = 0.292
	tires.outer_radius = 0.322
	tires.rings = 28
	tires.ring_segments = 8
	var rims := TorusMesh.new()
	rims.inner_radius = 0.285
	rims.outer_radius = 0.298
	rims.rings = 28
	rims.ring_segments = 5
	_street.meshes["bike_tire"] = tires
	_street.meshes["bike_rim"] = rims
	var colors := {
		"bike_paint": Color("507b6e"), "bike_fender": Color("688d81"),
		"bike_rubber": Color("393937"), "bike_chrome": Color("8f9694"),
		"basket_rust": Color("8c6744"), "shelter_board": Color("495e66"),
	}
	for name: String in colors:
		var finish := StandardMaterial3D.new()
		finish.resource_name = name
		finish.albedo_color = colors[name]
		finish.roughness = 0.44 if name in ["bike_paint", "bike_chrome"] else 0.75
		finish.metallic = 0.72 if name == "bike_chrome" else 0.12
		_street.materials[name] = finish


func _basket(center: Vector3) -> void:
	_bike_box(center + Vector3.DOWN * 0.062, Vector3(0.26, 0.032, 0.29), "basket_rust")
	for y: float in [-0.053, -0.008, 0.035, 0.091]:
		var width := 0.146 + (y + 0.05) * 0.16
		var depth := 0.132 + (y + 0.05) * 0.19
		for side: float in [-1.0, 1.0]:
			_beam(center + Vector3(-depth, y, side * width), center + Vector3(depth, y, side * width), 0.0065, "basket_rust")
			_beam(center + Vector3(side * depth, y, -width), center + Vector3(side * depth, y, width), 0.0065, "basket_rust")
	for division in 8:
		var t := (division - 3.5) / 3.5
		for side: float in [-1.0, 1.0]:
			_beam(center + Vector3(t * 0.132, -0.063, side * 0.146),
				center + Vector3(t * 0.16, 0.09, side * 0.168), 0.0045, "basket_rust")
			_beam(center + Vector3(side * 0.132, -0.063, t * 0.146),
				center + Vector3(side * 0.159, 0.09, t * 0.168), 0.0045, "basket_rust")


func _bike_box(center: Vector3, size: Vector3, material: String) -> void:
	_street.add_transformed_instance("box", material, _frame * Transform3D(Basis.from_scale(size), center))


func _shelter() -> void:
	var station := 70.78
	var offset := Layout.half_width(station) + 2.24
	var yaw: float = _street.rotation_for_cross(station) - PI * 0.5
	_frame = Transform3D(Basis(Vector3.UP, yaw), _site(station, offset))
	_masonry.begin(_frame)
	var iron := Color("566f69")
	var zinc := Color("8c9292")
	var base := Color("8d8b7b")
	var oak := Color("957458")
	_masonry.box(Vector3(0.0, 0.06, 0.0), Vector3(3.48, 0.19, 1.42), M.STONE, base)
	for x: float in [-1.50, 1.50]:
		var post := Vector3(x, 0.0, -0.52)
		_masonry.box(post + Vector3.UP * 1.21, Vector3(0.10, 2.38, 0.109), M.METAL, iron)
		var edge := Vector3(x, 0.0, 0.59)
		_beam(post + Vector3.UP * 2.42, edge + Vector3.UP * 2.23, 0.041, "awning_metal")
		_beam(post + Vector3.UP * 1.76, edge + Vector3.UP * 2.24, 0.026, "awning_metal")
		_masonry.box(post + Vector3.UP * 0.151, Vector3(0.222, 0.21, 0.273), M.STONE, base)
		_street.add_collision(_frame * (post + Vector3.UP * 0.97), Vector3(0.14, 1.98, 0.15), yaw)
	var half := 1.71
	var forward := 0.75
	var rear := -0.71
	for panel in 12:
		var left := -half + panel * half * 2.0 / 12.0
		var right := left + half * 2.0 / 12.0
		var shade := zinc.darkened(0.026 * (panel % 3))
		_masonry.quad(Vector3(left, 2.23, forward), Vector3(right, 2.23, forward),
			Vector3(right, 2.49, rear), Vector3(left, 2.49, rear), M.METAL, shade)
		_beam(Vector3(left, 2.25, forward), Vector3(left, 2.51, rear), 0.0135, "zinc")
	_masonry.box(Vector3(0.0, 2.214, forward), Vector3(half * 2.0 + 0.11, 0.077, 0.080), M.METAL, iron)
	_masonry.box(Vector3(0.0, 2.457, rear), Vector3(half * 2.0 + 0.11, 0.075, 0.086), M.METAL, iron)
	_glazed_panels(iron)
	for index in 5:
		var z := -0.38 + index * 0.092
		_masonry.box(Vector3(0.0, 0.53, z), Vector3(2.54, 0.052, 0.073), M.WOOD, oak)
	for x: float in [-1.09, 1.09]:
		_masonry.box(Vector3(x, 0.322, -0.22), Vector3(0.082, 0.391, 0.431), M.METAL, iron)
		_masonry.box(Vector3(x, 0.74, -0.26), Vector3(0.049, 0.039, 0.341), M.METAL, iron)
	_masonry.box(Vector3(1.09, 1.53, -0.405), Vector3(0.52, 0.71, 0.072), M.METAL, Color("3e5452"))
	_masonry.box(Vector3(1.09, 1.53, -0.36), Vector3(0.46, 0.61, 0.017), M.PLASTER, Color("d5c7ac"))
	for row in 5:
		_masonry.box(Vector3(1.09, 1.69 - row * 0.074, -0.344), Vector3(0.31, 0.014, 0.009), M.WOOD, Color("7d7867"))
	_masonry.box(Vector3(-0.56, 2.21, -0.41), Vector3(0.53, 0.068, 0.11), M.LIGHT, Color("d8cba7"))
	_street.add_lamp(_frame * Vector3(-0.56, 2.10, -0.36), 2.85, 0.78, 0.47)
	var sign := Vector3(-1.85, 1.98, 0.38)
	_beam(Vector3(sign.x, 0.0, sign.z), sign + Vector3.UP * 0.15, 0.032, "armature")
	_street.add_box(_frame * sign, Vector3(0.39, 0.29, 0.051), "shelter_board", false, yaw)
	_street.lettering("CIRCULAR", _frame * (sign + Vector3.BACK * 0.035), yaw, 0.00156, Color("f1e6ca"), true)


func _glazed_panels(iron: Color) -> void:
	var glass := StandardMaterial3D.new()
	glass.resource_name = "VidroAbrigo"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.71, 0.68, 0.26)
	glass.roughness = 0.36
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sheet := QuadMesh.new()
	sheet.size = Vector2(2.91, 1.46)
	sheet.material = glass
	var window := MeshInstance3D.new()
	window.name = "VidroAbrigo"
	window.mesh = sheet
	window.transform = Transform3D(_frame.basis, _frame * Vector3(0, 1.39, -0.51))
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	window.visibility_range_end = 62.0
	_street.scene_root.add_child(window)
	for y: float in [0.658, 1.375, 2.124]:
		_masonry.box(Vector3(0.0, y, -0.50), Vector3(3.03, 0.033 if y != 1.375 else 0.023, 0.066), M.METAL, iron)
	_masonry.box(Vector3(0.0, 1.39, -0.509), Vector3(0.034, 1.51, 0.074), M.METAL, iron)


func _site(station: float, offset: float) -> Vector3:
	return Layout.position_at(station, offset, Ground.surface_lift(station, offset))


func _beam(a: Vector3, b: Vector3, radius: float, material: String) -> void:
	_street.beam(_frame * a, _frame * b, radius, material)
