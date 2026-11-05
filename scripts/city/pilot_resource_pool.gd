extends RefCounted

# Sector scenes must reference shared resources externally. Otherwise each
# PackedScene serializes its own copy of the same tree mesh and facade material.
var resources: Array[Resource] = []
var _by_fingerprint: Dictionary = {}
var _seen: Dictionary = {}


func intern(resource: Resource, persist: bool = true) -> Resource:
	if resource == null:
		return null
	if _seen.has(resource):
		return _seen[resource]
	var key := fingerprint(resource)
	var canonical: Resource = _by_fingerprint.get(key, resource)
	if canonical == resource:
		_by_fingerprint[key] = resource
		if persist:
			resources.append(resource)
	_seen[resource] = canonical
	return canonical


func collect(city: Node3D) -> void:
	for geometry in city.find_children("*", "GeometryInstance3D", true, false):
		if geometry is MultiMeshInstance3D:
			geometry.multimesh.mesh = intern(geometry.multimesh.mesh)
		geometry.material_override = intern(geometry.material_override)
	# Shape dimensions recur in many independently serialized sectors as well.
	for collider in city.find_children("*", "CollisionShape3D", true, false):
		if collider.shape is BoxShape3D:
			collider.shape = intern(collider.shape, false)
	# Do not retain the discarded sector-local duplicates through publication.
	_seen.clear()


func save_shared(directory: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	for index in resources.size():
		var resource := resources[index]
		var path := directory.path_join("%s_%05d.res" % [resource.get_class(), index])
		error = ResourceSaver.save(resource, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			return error
		resource.take_over_path(path)
	return OK


func fingerprint(resource: Resource) -> String:
	var data: Array = [resource.get_class()]
	for property in resource.get_property_list():
		if not int(property.usage) & PROPERTY_USAGE_STORAGE:
			continue
		var key := str(property.name)
		if key in ["resource_path", "resource_scene_unique_id", "script"]:
			continue
		data.append([key, _value(resource.get(key))])
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(var_to_bytes(data))
	return hash_context.finish().hex_encode()


func _value(value: Variant) -> Variant:
	if value is Resource:
		# Imported textures and shaders keep their original resource identity.
		if not value.resource_path.is_empty() and not value.resource_path.contains("::"):
			return [value.get_class(), value.resource_path]
		return fingerprint(value)
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_value(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _value(value[key])
		return result
	return value
