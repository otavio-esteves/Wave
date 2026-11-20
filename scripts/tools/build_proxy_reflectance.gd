extends SceneTree

# Precompute distant reflectance while source pixels are available offline.
# Runtime HLOD must never read a texture back from the graphics driver.
const OUTPUT := "res://assets/textures/pilot/proxy-reflectance.tres"


func _initialize() -> void:
	var srgb: Dictionary = {}
	var linear: Dictionary = {}
	var hashes: Dictionary = {}
	var measurements: Array[Dictionary] = []
	for directory in ["res://assets/textures/neighborhood", "res://assets/textures/pilot"]:
		for file in DirAccess.get_files_at(directory):
			if not file.ends_with("-albedo.res"):
				continue
			var path: String = directory.path_join(file)
			var texture := load(path) as Texture2D
			if texture == null:
				push_error("Cannot load reflectance source: " + path)
				quit(1)
				return
			var started := Time.get_ticks_usec()
			var image := texture.get_image()
			var fetched := Time.get_ticks_usec()
			if image == null or image.is_empty() or image.is_compressed() and image.decompress() != OK:
				push_error("Cannot read reflectance source pixels: " + path)
				quit(1)
				return
			var srgb_mean := Color(0, 0, 0, 0)
			var linear_mean := Color(0, 0, 0, 0)
			for y in 16:
				for x in 16:
					var colour := image.get_pixel(mini(image.get_width() - 1, int((x + 0.5) * image.get_width() / 16.0)), mini(image.get_height() - 1, int((y + 0.5) * image.get_height() / 16.0)))
					srgb_mean += colour
					linear_mean += colour.srgb_to_linear()
			srgb[path] = srgb_mean / 256.0
			linear[path] = linear_mean / 256.0
			hashes[path] = FileAccess.get_sha256(path)
			measurements.append({"path": path, "texture_get_image_ms": (fetched - started) / 1000.0, "total_ms": (Time.get_ticks_usec() - started) / 1000.0})
	var resource := Resource.new()
	resource.resource_name = "PilotProxyReflectance"
	resource.set_meta("schema_version", 1)
	resource.set_meta("means_srgb", srgb)
	resource.set_meta("means_linear", linear)
	resource.set_meta("source_sha256", hashes)
	resource.set_meta("policy", "256 regular source samples; Compatibility uses sRGB means, Forward+/Mobile use linear means; source hashes are checked before using a baked mean")
	var error := ResourceSaver.save(resource, OUTPUT)
	if error != OK:
		push_error("Cannot save proxy reflectance: " + error_string(error))
		quit(1)
		return
	print("Proxy reflectance: %d sources; %s" % [srgb.size(), OUTPUT])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostics="):
			FileAccess.open(argument.trim_prefix("--diagnostics="), FileAccess.WRITE).store_string(JSON.stringify(measurements, "\t"))
	quit()
