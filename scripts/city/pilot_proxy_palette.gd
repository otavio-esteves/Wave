extends RefCounted

# Distant opaque facades share draw materials. Their source texture means are
# baked offline: Texture2D.get_image() here would synchronize/read back the
# graphics driver while the world is loading. Unknown or stale means retain the
# complete source material instead of changing its colour speculatively.
const MEANS := preload("res://assets/textures/pilot/proxy-reflectance.tres")
var _materials: Dictionary = {}
var _policies: Dictionary = {}
var _texture_means: Dictionary = {}
var _file_hashes: Dictionary = {}
var _missing: Dictionary = {}
var _stale: Dictionary = {}
var _linear_colour := RenderingServer.get_current_rendering_method() != "gl_compatibility"


func prepare(source: StandardMaterial3D, pane: bool) -> Dictionary:
	var identity := "%s/%s" % [source.get_instance_id(), pane]
	if _policies.has(identity):
		return _policies[identity]
	var preserve := _preserve(source, pane)
	var mean := Color.WHITE
	if not preserve and source.albedo_texture != null:
		var baked: Variant = _texture_mean(source.albedo_texture)
		if baked == null:
			preserve = true
		else:
			mean = baked
	var reflectance := source.albedo_color.srgb_to_linear() if _linear_colour else source.albedo_color
	reflectance *= mean
	# Fingerprinting an unknown embedded Texture2D could itself fetch its image.
	# Preserve its live material identity instead of inspecting it here.
	var key := "authored/%d" % source.get_instance_id() if preserve else "palette/%d/%d/%d" % [source.cull_mode, roundi(source.roughness * 4.0), roundi(source.metallic * 4.0)]
	var policy := {"preserve": preserve, "key": key, "reflectance": reflectance, "vertex_colours": source.vertex_color_use_as_albedo, "vertex_srgb": _linear_colour and source.vertex_color_is_srgb}
	_policies[identity] = policy
	return policy


func key(source: StandardMaterial3D, pane: bool) -> String:
	return prepare(source, pane).key


func material(source: StandardMaterial3D, pane: bool) -> StandardMaterial3D:
	var policy := prepare(source, pane)
	if policy.preserve:
		return source
	var identity: String = policy.key
	if not _materials.has(identity):
		var simplified := StandardMaterial3D.new()
		simplified.resource_name = "far_" + identity.replace("/", "_")
		simplified.albedo_color = Color.WHITE
		simplified.vertex_color_use_as_albedo = true
		# Compatibility keeps sRGB instance values; Forward+/Mobile receive the
		# linear reflectance product. Swatches verify the Compatibility path.
		simplified.vertex_color_is_srgb = false
		simplified.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		simplified.cull_mode = source.cull_mode
		simplified.roughness = snappedf(source.roughness, 0.25)
		simplified.metallic = snappedf(source.metallic, 0.25)
		_materials[identity] = simplified
	return _materials[identity]


func tint(source: StandardMaterial3D, colour: Color, pane: bool) -> Color:
	return tint_prepared(prepare(source, pane), colour)


static func tint_prepared(policy: Dictionary, colour: Color) -> Color:
	if policy.preserve:
		return colour
	var reflectance: Color = policy.reflectance
	if policy.vertex_colours:
		reflectance *= colour.srgb_to_linear() if policy.vertex_srgb else colour
	return reflectance


static func _preserve(source: StandardMaterial3D, pane: bool) -> bool:
	return pane or "glass" in source.resource_name or source.emission_enabled or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or source.next_pass != null or source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED


func _texture_mean(texture: Texture2D) -> Variant:
	if _texture_means.has(texture):
		return _texture_means[texture]
	var metadata_key := "wave_proxy_mean_linear" if _linear_colour else "wave_proxy_mean_srgb"
	var value: Variant = texture.get_meta(metadata_key) if texture.has_meta(metadata_key) else null
	if value is Color:
		_texture_means[texture] = value
		return value
	var path := texture.resource_path
	var means: Dictionary = MEANS.get_meta("means_linear" if _linear_colour else "means_srgb", {})
	var hashes: Dictionary = MEANS.get_meta("source_sha256", {})
	if means.has(path) and hashes.has(path) and FileAccess.file_exists(path):
		if not _file_hashes.has(path):
			_file_hashes[path] = FileAccess.get_sha256(path)
		if _file_hashes[path] == hashes[path]:
			_texture_means[texture] = means[path]
			return means[path]
		_stale[path] = true
	else:
		# PNGs may be remapped to .ctex in a PCK. An absent raw source is an
		# ordinary cache miss, never an I/O error or a reason for a GPU readback.
		_missing[path if not path.is_empty() else "embedded:" + str(texture.get_instance_id())] = true
	_texture_means[texture] = null
	return null


func diagnostics() -> Dictionary:
	return {"material_policies": _policies.size(), "texture_means": _texture_means.size(), "missing_means": _missing.keys(), "stale_means": _stale.keys(), "runtime_texture_readbacks": 0}
