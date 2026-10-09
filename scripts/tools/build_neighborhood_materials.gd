extends SceneTree

# Original deterministic micro-surfaces, baked offline. No procedural runtime work.
const OUTPUT := "res://assets/textures/neighborhood"

func _initialize() -> void:
	for kind in ["stucco", "limestone", "timber", "paving"]:
		_build(kind)
	quit()

func _build(kind: String) -> void:
	var image := Image.create_empty(256, 256, false, Image.FORMAT_RGB8)
	var height := Image.create_empty(256, 256, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 2012
	noise.frequency = 0.055
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for y in 256:
		for x in 256:
			# Periodic coordinates keep each generated material continuous at tile edges.
			var ax := TAU * x / 256.0
			var ay := TAU * y / 256.0
			var n := noise.get_noise_3d(cos(ax) * 60 + cos(ay) * 30, sin(ax) * 60, sin(ay) * 30)
			var fine := noise.get_noise_3d(cos(ax) * 330 + cos(ay) * 170, sin(ax) * 330, sin(ay) * 170)
			var value := 0.94 + n * 0.055 + fine * 0.03
			var relief := 0.5 + fine * 0.10
			if kind == "limestone":
				var stagger := 64 if y / 64 % 2 else 0
				var joint := y % 64 < 2 or (x + stagger) % 128 < 2
				value = (0.68 if joint else 0.91 + n * 0.08 + fine * 0.035)
				relief = 0.43 if joint else 0.51 + fine * 0.015
			elif kind == "timber":
				var grain := sin(ax * 20 + n * 3 + sin(ay) * 0.5)
				value = 0.78 + grain * 0.10 + fine * 0.025
				relief = 0.5 + grain * 0.014
			elif kind == "paving":
				var joint := y % 128 < 2 or x % 128 < 2
				value = 0.76 if joint else 0.96 + n * 0.035 + fine * 0.025
				relief = 0.45 if joint else 0.5 + fine * 0.025
			image.set_pixel(x, y, Color(value, value, value))
			height.set_pixel(x, y, Color(relief, relief, relief))
	# Encode a normal map from the original procedural height field.
	height.bump_map_to_normal_map(0.6)
	image.generate_mipmaps()
	height.generate_mipmaps()
	ResourceSaver.save(ImageTexture.create_from_image(image), OUTPUT.path_join(kind + "-albedo.res"))
	ResourceSaver.save(ImageTexture.create_from_image(height), OUTPUT.path_join(kind + "-normal.res"))
	print("Baked original surface: " + kind)
