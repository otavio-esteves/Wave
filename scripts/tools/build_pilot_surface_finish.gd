extends SceneTree

# Reuse the project's original photographic-style source plates. Derive compact,
# mipmapped GPU textures offline; gameplay never reads pixels or builds images.
const OUTPUT := "res://assets/textures/pilot"
const SIZE := 512


func _initialize() -> void:
	var sources: Array[Dictionary] = []
	var derived: Array[Dictionary] = []
	for kind in ["asphalt", "grass"]:
		var name := "asphalt-realism-v1.png" if kind == "asphalt" else "lawn-realism-v1.png"
		var source := "res://assets/textures/neighborhood/" + name
		var image := Image.load_from_file(ProjectSettings.globalize_path(source))
		if image == null or image.is_empty():
			push_error("Surface source is unavailable: " + source)
			quit(1)
			return
		sources.append({"path": source.trim_prefix("res://"), "sha256": FileAccess.get_sha256(source), "provenance": (source.get_basename() + ".md").trim_prefix("res://")})
		image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		var relief := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for y in SIZE:
			for x in SIZE:
				var color := image.get_pixel(x, y)
				var luminance := color.get_luminance()
				if kind == "grass":
					# Brazilian dry-season lawns have green blades and warm thatch.
					# Reduce the source plate's electric greens before lighting it.
					color = color.lerp(Color(luminance * 1.10, luminance * 1.04, luminance * 0.89), 0.55)
					color *= Color(1.03, 0.98, 0.96)
				else:
					# Keep binder/aggregate variation below the contrast of road
					# markings and geometry; excessive microcontrast looks like grit.
					color = color.lerp(Color(0.42, 0.43, 0.44), 0.26)
				image.set_pixel(x, y, color)
				var height := clampf(0.5 + (luminance - 0.4) * (0.7 if kind == "asphalt" else 0.45), 0.0, 1.0)
				relief.set_pixel(x, y, Color(height, height, height))
		relief.bump_map_to_normal_map(1.4 if kind == "asphalt" else 1.0)
		image.generate_mipmaps()
		relief.generate_mipmaps()
		for item in [["albedo", image], ["normal", relief]]:
			var path := OUTPUT.path_join("finish-%s-%s.res" % [kind, item[0]])
			var error := ResourceSaver.save(ImageTexture.create_from_image(item[1]), path, ResourceSaver.FLAG_COMPRESS)
			if error != OK:
				push_error("Surface finish could not be saved: " + error_string(error))
				quit(1)
				return
			derived.append({"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path), "bytes": FileAccess.open(path, FileAccess.READ).get_length()})
		print("Surface finish: %s, %dx%d with mipmaps" % [kind, SIZE, SIZE])
	var room_source := "res://assets/textures/pilot/window-interior-v2.png"
	var room_image := Image.load_from_file(ProjectSettings.globalize_path(room_source))
	if room_image == null or room_image.is_empty():
		push_error("Window interior source is unavailable")
		quit(1)
		return
	room_image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	room_image.convert(Image.FORMAT_RGB8)
	room_image.generate_mipmaps()
	var room_path := OUTPUT.path_join("finish-window-interior-albedo.res")
	var room_error := ResourceSaver.save(ImageTexture.create_from_image(room_image), room_path, ResourceSaver.FLAG_COMPRESS)
	if room_error != OK:
		push_error("Window interior finish could not be saved: " + error_string(room_error))
		quit(1)
		return
	sources.append({"path": room_source.trim_prefix("res://"), "sha256": FileAccess.get_sha256(room_source), "provenance": "assets/textures/pilot/window-interior-v2.provenance.json"})
	derived.append({"path": room_path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(room_path), "bytes": FileAccess.open(room_path, FileAccess.READ).get_length()})
	print("Surface finish: residential interior, %dx%d with mipmaps" % [SIZE, SIZE])
	var provenance := FileAccess.open(OUTPUT.path_join("finish-provenance.json"), FileAccess.WRITE)
	if provenance == null:
		push_error("Surface provenance could not be saved")
		quit(1)
		return
	provenance.store_string(JSON.stringify({"revision": "2026-11-19-ground-and-interiors-v3", "generator": "scripts/tools/build_pilot_surface_finish.gd", "source_assets": sources, "derived_assets": derived, "processing": {"size": [SIZE, SIZE], "resize": "Lanczos", "grass_saturation": "Desaturated with warm dry-season thatch retained", "normal_scope": "Luminance-derived visual microrelief; not measured displacement and no collision change", "interior_scope": "Original room plate on the existing window quads; selected occupied windows reuse it for emission", "mipmaps": true}}, "\t") + "\n")
	provenance.close()
	quit()
