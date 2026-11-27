extends Node3D

const HAZE = preload("res://assets/shaders/jabuticabeiras/lamp_haze.gdshader")
const FINISH = preload("res://assets/shaders/jabuticabeiras/photographic_finish.gdshader")
const VALLEY_MIST = preload("res://assets/shaders/jabuticabeiras/valley_mist.gdshader")

var _finish: CanvasLayer
var _haze: Array[MeshInstance3D] = []
var _mist: Array[MeshInstance3D] = []
var _built := false


func build(lamps: Array[OmniLight3D]) -> void:
	var surface := QuadMesh.new()
	surface.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = HAZE
	material.render_priority = 6
	for lamp in lamps:
		var haze := MeshInstance3D.new()
		haze.name = "Bruma_" + str(lamp.name)
		haze.mesh = surface
		haze.material_override = material
		haze.layers = 1
		haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var radius := clampf(lamp.omni_range * 0.63, 1.25, 3.77)
		haze.custom_aabb = AABB(Vector3(-0.52, -0.52, -0.52), Vector3(1.04, 1.04, 1.04))
		haze.position = to_local(lamp.global_position - Vector3.UP * radius * 0.61)
		haze.scale = Vector3.ONE * radius * 2.0
		haze.visibility_range_end = 33.0
		haze.hide()
		add_child(haze)
		_haze.append(haze)
	_make_mist(Vector3(-11.6, 3.4, -222.3), Vector3(55.0, 2.35, 39.0), 0.013)
	_make_mist(Vector3(16.0, 4.8, -262.0), Vector3(63.0, 1.76, 38.0), 0.010)
	_make_mist(Vector3(12.0, 1.85, 56.0), Vector3(46.0, 1.85, 25.0), 0.011)
	_make_finish()
	_built = true


func _make_mist(site: Vector3, extent: Vector3, density: float) -> void:
	var volume := SphereMesh.new()
	volume.radius = 0.5
	volume.height = 1.0
	volume.radial_segments = 16
	volume.rings = 8
	var material := ShaderMaterial.new()
	material.shader = VALLEY_MIST
	material.render_priority = 3
	material.set_shader_parameter("concentration", density)
	var mist := MeshInstance3D.new()
	mist.name = "NeblinaDoVale"
	mist.mesh = volume
	mist.material_override = material
	mist.layers = 1
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.position = site
	mist.scale = extent * 2.0
	mist.hide()
	add_child(mist, true)
	_mist.append(mist)


func _make_finish() -> void:
	_finish = CanvasLayer.new()
	_finish.name = "CameraFinish"
	_finish.layer = 0
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tone := ShaderMaterial.new()
	tone.shader = FINISH
	screen.material = tone
	add_child(_finish)
	_finish.add_child(screen)
	_finish.hide()


func apply(detail: bool, photo: bool) -> void:
	if not _built:
		return
	for haze in _haze:
		haze.visible = detail
	for mist in _mist:
		mist.visible = photo
	_finish.visible = photo
