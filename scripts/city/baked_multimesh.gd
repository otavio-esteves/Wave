@tool
extends MultiMesh

var _updating_instances := false

@export var billboard_radius := 0.0:
	set(value):
		billboard_radius = value
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


func set_instances(placements: Array[Transform3D], tints := PackedColorArray()) -> void:
	# A runtime LOD changes both arrays together. Never upload the previous
	# transforms with the next set of colours or allocate that buffer twice.
	_updating_instances = true
	instance_transforms = placements
	instance_tints = tints
	_updating_instances = false
	rebuild_instances()


func rebuild_instances(update_bounds: bool = true) -> void:
	if use_colors != not instance_tints.is_empty():
		instance_count = 0
		use_colors = not instance_tints.is_empty()
	if transform_format != MultiMesh.TRANSFORM_3D:
		instance_count = 0
		transform_format = MultiMesh.TRANSFORM_3D
	if instance_count != instance_transforms.size():
		instance_count = instance_transforms.size()
	if update_bounds:
		_update_bounds()
	if mesh == null or instance_transforms.is_empty():
		return
	# The dummy server drops instance uploads; the exported source arrays and
	# custom bounds are sufficient for offline assembly and headless validation.
	if DisplayServer.get_name() == "headless":
		return
	buffer = make_buffer(instance_transforms, instance_tints)


func _validate_property(property: Dictionary) -> void:
	# The source arrays are authoritative and rebuild the buffer on load. Saving
	# native copies as well doubles instance payloads in a rendered editor export.
	if property.name in ["buffer", "transform_array", "transform_2d_array", "color_array", "custom_data_array"]:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE


static func make_buffer(placements: Array[Transform3D], tints: PackedColorArray) -> PackedFloat32Array:
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
