@tool
extends MultiMesh

# Frozen prepacked-format baseline for the CPU microbenchmark. Enabling the
# explicit emulation flag exercises the same two GDScript packs that a rendered
# legacy load performed, even when the benchmark uses the dummy render server.
var _updating_instances := false
var _packs := 0
var _bounds_scans := 0

@export var emulate_rendered_upload_in_headless := false
@export var billboard_radius := 0.0:
	set(value):
		billboard_radius = value
		_update_bounds()
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
	if DisplayServer.get_name() == "headless" and not emulate_rendered_upload_in_headless:
		return
	_packs += 1
	buffer = make_buffer(instance_transforms, instance_tints)


func _validate_property(property: Dictionary) -> void:
	if property.name in ["buffer", "transform_array", "transform_2d_array", "color_array", "custom_data_array"]:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE


func _update_bounds() -> void:
	_bounds_scans += 1
	if mesh == null or instance_transforms.is_empty():
		custom_aabb = AABB()
		return
	var primitive_bounds := mesh.get_aabb()
	var bounds: AABB = instance_transforms[0] * primitive_bounds
	for placement in instance_transforms:
		bounds = bounds.merge(placement * primitive_bounds)
	var padding := Vector3(billboard_radius, 0, billboard_radius)
	bounds.position -= padding
	bounds.size += padding * 2.0
	custom_aabb = bounds


func load_work() -> Dictionary:
	return {"buffer_packs": _packs, "bounds_scans": _bounds_scans}


static func make_buffer(placements: Array[Transform3D], tints: PackedColorArray) -> PackedFloat32Array:
	# Preserve the original scalar implementation independently of production
	# optimizations, so the historical CPU comparator cannot silently improve.
	var stride := 12 if tints.is_empty() else 16
	var data := PackedFloat32Array()
	data.resize(placements.size() * stride)
	for index in placements.size():
		var placement := placements[index]
		var at := index * stride
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
