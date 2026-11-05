extends SceneTree

const ROOT := "res://scenes/city/pilot/pilot_city_generations"
var _dependencies: Dictionary = {}
var _records: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := "user://city-generations.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_collect_dependencies("res://scenes/city/pilot/pilot_city.scn")
	for name in DirAccess.get_directories_at(ROOT):
		var directory := ROOT.path_join(name)
		var active := false
		for path: String in _dependencies:
			if path.begins_with(directory + "/"):
				active = true
		_records.append({"generation": name, "directory": directory, "active": active, "bytes": _directory_bytes(directory), "references": []})
	_find_references("res://")
	var active_name := ""
	for record in _records:
		if record.active and (active_name.is_empty() or str(record.generation) > active_name):
			active_name = record.generation
	var rollback := ""
	for record in _records:
		var name: String = record.generation
		if name < active_name and name > rollback:
			rollback = name
	# A pinned historical entry can depend on resources in another generation.
	# Protect that complete graph before labelling anything unreferenced.
	_dependencies.clear()
	for record in _records:
		if record.active or not record.references.is_empty() or record.generation == rollback:
			_collect_dependencies(record.directory.path_join("city.scn"))
	var candidates := 0
	var total_bytes := 0
	for record in _records:
		var retained := false
		for path: String in _dependencies:
			if path.begins_with(str(record.directory) + "/"):
				retained = true
		record["required_by_retained_generation"] = retained
		record["rollback"] = record.generation == rollback
		record["archive_candidate"] = not record.active and record.references.is_empty() and not retained and not record.rollback
		total_bytes += record.bytes
		candidates += 1 if record.archive_candidate else 0
	var report := {"policy": "Read-only inventory. Preserve the active dependency closure, referenced comparison baselines and a rollback generation. Archive unreferenced generations outside the source checkout after review; never rewrite Git history automatically.", "total_bytes": total_bytes, "unreferenced_generations": candidates, "generations": _records}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("Generation audit: %d generations; %.1f MiB; %d unreferenced; %s" % [_records.size(), total_bytes / 1048576.0, candidates, output])
	quit()


func _collect_dependencies(path: String) -> void:
	if _dependencies.has(path):
		return
	_dependencies[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		var child: String = dependency.split("::")[-1]
		if child.begins_with("uid://"):
			child = ResourceUID.get_id_path(ResourceUID.text_to_id(child))
		if not child.is_empty():
			_collect_dependencies(child)


func _directory_bytes(path: String) -> int:
	var result := 0
	for name in DirAccess.get_files_at(path):
		var file := FileAccess.open(path.path_join(name), FileAccess.READ)
		if file != null:
			result += file.get_length()
	for name in DirAccess.get_directories_at(path):
		result += _directory_bytes(path.path_join(name))
	return result


func _find_references(directory: String) -> void:
	for name in DirAccess.get_files_at(directory):
		if name.get_extension() not in ["gd", "md", "json", "html", "tscn", "cfg", "sh", "py"]:
			continue
		var path := directory.path_join(name)
		var text := FileAccess.get_file_as_string(path)
		for record in _records:
			if text.contains(record.generation):
				record.references.append(path)
	for name in DirAccess.get_directories_at(directory):
		if name in [".git", ".godot", "builds", "tools", "pilot_city_generations"]:
			continue
		_find_references(directory.path_join(name))
