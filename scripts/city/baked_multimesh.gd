@tool
extends MultiMesh

const PAYLOAD_VERSION := 1
const PACK_CHUNK_INSTANCES := 4096
const MAX_VECTOR_PACK_INSTANCES := 32768
const OMITTED_STORAGE_PROPERTIES := {
	"billboard_radius": true, "instance_transforms": true, "instance_tints": true,
	"instance_count": true, "transform_format": true, "use_colors": true,
	"visible_instance_count": true, "custom_aabb": true, "buffer": true,
	"transform_array": true, "transform_2d_array": true, "color_array": true,
	"custom_data_array": true,
}
static var _native_vector4_bytes := PackedVector4Array([Vector4.ZERO]).to_byte_array().size()
var _updating_instances := false
var _rebuild_count := 0
var _bounds_scan_count := 0
var _buffer_pack_count := 0
var _prepacked_load_count := 0
var _fallback_load_count := 0
var _upload_count := 0
var _payload_get_count := 0
var _payload_get_instances := 0

@export var billboard_radius := 0.0:
	set(value):
		billboard_radius = value
		if not _updating_instances:
			_update_bounds()

# Keep instance data in a normal resource property. In headless mode the dummy
# RenderingServer discards transform uploads, so its buffer cannot be serialized.
# This property survives saving and restores the GPU instances when loaded.
@export var instance_transforms: Array[Transform3D] = []:
	set(value):
		instance_transforms = value
		if not _updating_instances:
			rebuild_instances()

@export var instance_tints := PackedColorArray():
	set(value):
		instance_tints = value
		if not _updating_instances:
			rebuild_instances(false)


# One atomic property avoids depending on the order of independent setters.
# The source arrays remain editable through the public properties above. New
# files store them once inside this payload, beside an offline-built GPU buffer.
# No backing dictionary/buffer is retained after loading: only the authored
# arrays and the native MultiMesh upload survive the setter.
@export_storage var baked_payload: Dictionary:
	get:
		_payload_get_count += 1
		_payload_get_instances += instance_transforms.size()
		return {"version": PAYLOAD_VERSION, "transforms": instance_transforms,
			"tints": instance_tints, "billboard_radius": billboard_radius,
			"bounds": custom_aabb, "visible_instance_count": visible_instance_count,
			"upload": _pack_buffer()}
	set(value):
		_load_payload(value)


func _load_payload(data: Dictionary) -> void:
	var placements: Variant = data.get("transforms")
	var tints: Variant = data.get("tints")
	if not placements is Array or not tints is PackedColorArray:
		push_error("BakedMultiMesh payload lacks authored transform/colour arrays")
		return
	# Nested arrays lose their typed-array annotation in the binary resource
	# format. Array.assign normalizes them in native code without a GDScript
	# per-instance conversion or a second persistent copy of the source data.
	var typed_placements: Array[Transform3D] = []
	typed_placements.assign(placements)
	if typed_placements.size() != placements.size():
		push_error("BakedMultiMesh payload contains invalid authored transforms")
		return
	var radius: Variant = data.get("billboard_radius", 0.0)
	if not (radius is float or radius is int) or not is_finite(float(radius)):
		radius = 0.0
	_updating_instances = true
	instance_transforms = typed_placements
	instance_tints = tints
	billboard_radius = float(radius)
	_updating_instances = false
	var upload: Variant = data.get("upload")
	var bounds: Variant = data.get("bounds")
	var version: Variant = data.get("version")
	var stride := 12 if instance_tints.is_empty() else 16
	var valid: bool = version is int and version == PAYLOAD_VERSION
	valid = valid and upload is PackedFloat32Array and upload.size() == instance_transforms.size() * stride
	valid = valid and bounds is AABB and bounds.position.is_finite() and bounds.size.is_finite()
	if valid:
		valid = bounds.size.x >= 0.0 and bounds.size.y >= 0.0 and bounds.size.z >= 0.0
	if valid:
		_configure_instances()
		custom_aabb = bounds
		_prepacked_load_count += 1
		_upload_buffer(upload)
	else:
		# A malformed/unknown cache is never truncated or uploaded. Its source
		# arrays are still authoritative, just as they are in a legacy resource.
		_fallback_load_count += 1
		rebuild_instances()
	var visible_count: Variant = data.get("visible_instance_count", -1)
	visible_instance_count = visible_count if visible_count is int and visible_count >= -1 and visible_count <= instance_count else -1


func set_instances(placements: Array[Transform3D], tints := PackedColorArray()) -> void:
	# A runtime LOD changes both arrays together. Never upload the previous
	# transforms with the next set of colours or allocate that buffer twice.
	_updating_instances = true
	instance_transforms = placements
	instance_tints = tints
	_updating_instances = false
	rebuild_instances()


func rebuild_instances(update_bounds: bool = true) -> void:
	_rebuild_count += 1
	_configure_instances()
	if update_bounds:
		_update_bounds()
	if mesh == null or instance_transforms.is_empty():
		return
	# The dummy server drops instance uploads; the authored arrays and custom
	# bounds are sufficient for offline assembly and headless validation.
	if DisplayServer.get_name() != "headless":
		_upload_buffer(_pack_buffer())


func _configure_instances() -> void:
	if use_colors != not instance_tints.is_empty():
		instance_count = 0
		use_colors = not instance_tints.is_empty()
	if transform_format != MultiMesh.TRANSFORM_3D:
		instance_count = 0
		transform_format = MultiMesh.TRANSFORM_3D
	if instance_count != instance_transforms.size():
		instance_count = instance_transforms.size()


func _pack_buffer() -> PackedFloat32Array:
	# ResourceLoader can inspect the default property before assigning the
	# payload. That empty getter must not enter the per-instance packer either.
	if instance_transforms.is_empty():
		return PackedFloat32Array()
	_buffer_pack_count += 1
	return make_buffer(instance_transforms, instance_tints)


func _upload_buffer(data: PackedFloat32Array) -> void:
	if data.is_empty() or DisplayServer.get_name() == "headless":
		return
	_upload_count += 1
	buffer = data


func load_work() -> Dictionary:
	# Diagnostics contain counters, never a second retained copy of GPU data.
	return {"rebuilds": _rebuild_count, "bounds_scans": _bounds_scan_count,
		"buffer_packs": _buffer_pack_count, "prepacked_loads": _prepacked_load_count,
		"fallback_loads": _fallback_load_count, "uploads": _upload_count,
		"payload_gets": _payload_get_count, "payload_get_instances": _payload_get_instances}


func _validate_property(property: Dictionary) -> void:
	# Legacy files can still set all these public properties. PROPERTY_USAGE_STORAGE
	# controls saving, not the existence of a property during deserialization. New
	# files have one payload setter, with no other serialized setter able to clear
	# its upload or to rescan/double-pad its saved visibility bounds afterwards.
	if OMITTED_STORAGE_PROPERTIES.has(str(property.name)):
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE


static func make_buffer(placements: Array[Transform3D], tints: PackedColorArray) -> PackedFloat32Array:
	# Vector4 rows replace twelve/sixteen scalar PackedArray writes per instance.
	# Limit scratch buffers to one small chunk. Very large one-off batches retain
	# the single-allocation scalar path, bounding any append/reallocation overhead
	# independently of a city-sized upload. Double-precision Vector4 builds also
	# use scalar conversion: interpreting their raw bytes as float32 is unsafe.
	if _native_vector4_bytes != 16 or placements.size() > MAX_VECTOR_PACK_INSTANCES:
		return _make_scalar_buffer(placements, tints)
	if placements.size() <= PACK_CHUNK_INSTANCES:
		return _make_vector_chunk(placements, tints, 0, placements.size())
	var data := PackedFloat32Array()
	for first in range(0, placements.size(), PACK_CHUNK_INSTANCES):
		data.append_array(_make_vector_chunk(placements, tints, first, mini(PACK_CHUNK_INSTANCES, placements.size() - first)))
	return data


static func _make_vector_chunk(placements: Array[Transform3D], tints: PackedColorArray, first: int, count: int) -> PackedFloat32Array:
	var row_count := 3 if tints.is_empty() else 4
	var rows := PackedVector4Array()
	rows.resize(count * row_count)
	for index in count:
		var placement := placements[first + index]
		var x := placement.basis.x
		var y := placement.basis.y
		var z := placement.basis.z
		var p := placement.origin
		var at := index * row_count
		rows[at] = Vector4(x.x, y.x, z.x, p.x)
		rows[at + 1] = Vector4(x.y, y.y, z.y, p.y)
		rows[at + 2] = Vector4(x.z, y.z, z.z, p.z)
		if row_count == 4:
			var tint := tints[first + index] if first + index < tints.size() else Color.WHITE
			rows[at + 3] = Vector4(tint.r, tint.g, tint.b, tint.a)
	return rows.to_byte_array().to_float32_array()


static func packing_layout() -> Dictionary:
	return {"vector4_bytes": _native_vector4_bytes, "chunk_instances": PACK_CHUNK_INSTANCES,
		"max_vector_instances": MAX_VECTOR_PACK_INSTANCES,
		"maximum_chunk_scratch_bytes": PACK_CHUNK_INSTANCES * 16 * 4 * 3,
		"large_uploads_use_single_scalar_allocation": true}


static func _make_scalar_buffer(placements: Array[Transform3D], tints: PackedColorArray) -> PackedFloat32Array:
	var stride := 12 if tints.is_empty() else 16
	var data := PackedFloat32Array()
	data.resize(placements.size() * stride)
	for index in placements.size():
		var placement := placements[index]
		var at := index * stride
		# RenderingServer expects row-major 3x4 matrices, followed by RGBA.
		for row in 3:
			data[at + row * 4] = placement.basis.x[row]
			data[at + row * 4 + 1] = placement.basis.y[row]
			data[at + row * 4 + 2] = placement.basis.z[row]
			data[at + row * 4 + 3] = placement.origin[row]
		if stride == 16:
			var tint := tints[index] if index < tints.size() else Color.WHITE
			data[at + 12] = tint.r
			data[at + 13] = tint.g
			data[at + 14] = tint.b
			data[at + 15] = tint.a
	return data


func _update_bounds() -> void:
	_bounds_scan_count += 1
	if mesh == null or instance_transforms.is_empty():
		custom_aabb = AABB()
		return
	var primitive_bounds := mesh.get_aabb()
	var bounds: AABB = instance_transforms[0] * primitive_bounds
	for placement in instance_transforms:
		bounds = bounds.merge(placement * primitive_bounds)
	# A camera-facing card can rotate beyond the authored plane bounds.
	var padding := Vector3(billboard_radius, 0, billboard_radius)
	bounds.position -= padding
	bounds.size += padding * 2.0
	custom_aabb = bounds
