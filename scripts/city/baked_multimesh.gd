@tool
extends MultiMesh

@export var billboard_radius := 0.0:
	set(value):
		billboard_radius = value
		rebuild_instances()

# Keep instance data in a normal resource property. In headless mode the dummy
# RenderingServer discards transform uploads, so its buffer cannot be serialized.
# This property survives saving and restores the GPU instances when loaded.
@export var instance_transforms: Array[Transform3D] = []:
	set(value):
		instance_transforms = value
		rebuild_instances()


func rebuild_instances() -> void:
	if transform_format != MultiMesh.TRANSFORM_3D:
		instance_count = 0
		transform_format = MultiMesh.TRANSFORM_3D
	instance_count = instance_transforms.size()
	if mesh == null or instance_transforms.is_empty():
		return
	var primitive_bounds := mesh.get_aabb()
	var bounds: AABB = instance_transforms[0] * primitive_bounds
	for index in range(instance_transforms.size()):
		var placement := instance_transforms[index]
		set_instance_transform(index, placement)
		bounds = bounds.merge(placement * primitive_bounds)
	# A camera-facing card can rotate beyond the authored plane bounds.
	var padding := Vector3(billboard_radius, 0, billboard_radius)
	bounds.position -= padding
	bounds.size += padding * 2.0
	custom_aabb = bounds
