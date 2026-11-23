extends RefCounted

const MAGIC := 0x57475631
const STRIDE := 8
const SAMPLE_INTERVAL := 1.0 / 15.0
const MAX_SAMPLES := 3602
const DIRECTORY := "user://figueiras-ghosts"

var samples := PackedFloat32Array()
var _cursor := 0


func clear() -> void:
	samples.clear()
	_cursor = 0


func duration() -> float:
	return samples[samples.size() - STRIDE] if not samples.is_empty() else -1.0


func rewind() -> void:
	_cursor = 0


func add_pose(seconds: float, pose: Transform3D) -> void:
	if samples.size() >= MAX_SAMPLES * STRIDE or seconds <= duration():
		return
	var orientation := pose.basis.orthonormalized().get_rotation_quaternion()
	samples.append_array(PackedFloat32Array([seconds, pose.origin.x, pose.origin.y,
		pose.origin.z, orientation.x, orientation.y, orientation.z, orientation.w]))


func pose_at(seconds: float) -> Transform3D:
	var last := samples.size() - STRIDE
	while _cursor < last - STRIDE and seconds > samples[_cursor + STRIDE]:
		_cursor += STRIDE
	while _cursor > 0 and seconds < samples[_cursor]:
		_cursor -= STRIDE
	var next := mini(_cursor + STRIDE, last)
	var span := samples[next] - samples[_cursor]
	var weight := clampf((seconds - samples[_cursor]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var origin := _position(_cursor).lerp(_position(next), weight)
	var rotation := _orientation(_cursor).slerp(_orientation(next), weight)
	return Transform3D(Basis(rotation), origin)


func load_run(event_id: String, wet: bool, signature: int, time_limit: float) -> void:
	clear()
	var file := FileAccess.open(_path(event_id, wet), FileAccess.READ)
	if file == null or file.get_length() < 12 or file.get_32() != MAGIC or file.get_32() != signature:
		return
	var count := file.get_32()
	var bytes := count * STRIDE * 4
	if count < 2 or count > MAX_SAMPLES or file.get_length() != 12 + bytes:
		return
	samples = file.get_buffer(bytes).to_float32_array()
	if not _valid(time_limit):
		clear()


func save_run(event_id: String, wet: bool, signature: int, time_limit: float) -> Error:
	if samples.size() < STRIDE * 2 or not _valid(time_limit):
		return ERR_INVALID_DATA
	var directory := ProjectSettings.globalize_path(DIRECTORY)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var path := _path(event_id, wet)
	var temporary := "%s.tmp-%d" % [path, OS.get_process_id()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_32(MAGIC)
	file.store_32(signature)
	file.store_32(samples.size() / STRIDE)
	file.store_buffer(samples.to_byte_array())
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))


func _valid(time_limit: float) -> bool:
	if samples.is_empty() or samples[0] != 0.0 or not is_finite(duration()) or duration() > time_limit:
		return false
	var last_time := -1.0
	var last_position := Vector3.ZERO
	for index in range(0, samples.size(), STRIDE):
		var time := samples[index]
		var origin := _position(index)
		var orientation := _orientation(index)
		if not is_finite(time) or time <= last_time or not origin.is_finite() or origin.length_squared() > 4096.0 * 4096.0:
			return false
		if not orientation.is_finite() or absf(orientation.length_squared() - 1.0) > 0.006:
			return false
		if index > 0 and (time - last_time > 0.18 or origin.distance_to(last_position) > 90.0 * (time - last_time) + 0.85):
			return false
		last_time = time
		last_position = origin
	return true


func _position(index: int) -> Vector3:
	return Vector3(samples[index + 1], samples[index + 2], samples[index + 3])


func _orientation(index: int) -> Quaternion:
	return Quaternion(samples[index + 4], samples[index + 5], samples[index + 6], samples[index + 7])


static func _path(event_id: String, wet: bool) -> String:
	return "%s/%s-%s.wgr" % [DIRECTORY, event_id, "chuva" if wet else "seco"]
