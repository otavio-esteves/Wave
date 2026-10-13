extends SceneTree

# Original deterministic micro-surfaces, baked offline. No procedural runtime work.
const OUTPUT := "res://assets/textures/neighborhood"

func _initialize() -> void:
	var kinds: Array[String] = ["stucco", "limestone", "timber", "paving", "pavers", "brickwork", "roof_tiles", "asphalt", "window", "shop_window", "turf", "curtain_wall"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			var selected := argument.trim_prefix("--only=")
			if selected not in kinds:
				push_error("Unknown surface: " + selected)
				quit(1)
				return
			kinds = [selected]
	for kind in kinds:
		_build(kind)
	quit()

func _build(kind: String) -> void:
	var size := 512
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var height := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 2012
	noise.frequency = 0.055
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var stone_rng := RandomNumberGenerator.new()
	stone_rng.seed = 5547
	for y in size:
		for x in size:
			# Periodic coordinates keep each generated material continuous at tile edges.
			var ax := TAU * x / float(size)
			var ay := TAU * y / float(size)
			var n := noise.get_noise_3d(cos(ax) * 60 + cos(ay) * 30, sin(ax) * 60, sin(ay) * 30)
			var fine := noise.get_noise_3d(cos(ax) * 330 + cos(ay) * 170, sin(ax) * 330, sin(ay) * 170)
			var value := 0.91 + n * 0.08 + fine * 0.05
			var relief := 0.5 + fine * 0.10
			var tint := Color.WHITE
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
				# Individual concrete slabs have chamfered joints, aggregate and subtle stains.
				var dx := mini(x % 256, 255 - x % 256)
				var dy := mini(y % 256, 255 - y % 256)
				var bevel := smoothstep(1, 5, minf(dx, dy))
				var slab_tone := 0.88 + 0.025 * sin(floorf(x / 256.0) * 17 + floorf(y / 256.0) * 31)
				value = lerpf(0.53, slab_tone + n * 0.065 + fine * 0.045, bevel)
				relief = lerpf(0.38, 0.51 + fine * 0.025, bevel)
				tint = Color(1.0, 0.985, 0.955)
			elif kind in ["pavers", "brickwork"]:
				var brick_height := 64
				var row := y / brick_height
				var stagger := 64 if row % 2 else 0
				var dx := mini((x + stagger) % 128, 127 - (x + stagger) % 128)
				var dy := mini(y % brick_height, brick_height - 1 - y % brick_height)
				var bevel := smoothstep(1, 5, minf(dx, dy))
				var individual := sin(floorf((x + stagger) / 128.0) * 43 + row * 17) * 0.065
				value = lerpf(0.53, 0.84 + individual + fine * 0.06 + n * 0.035, bevel)
				relief = lerpf(0.39, 0.54 + fine * 0.04, bevel)
				tint = Color(1.0, 0.98, 0.93) if kind == "pavers" else Color(1.0, 0.77, 0.60)
			elif kind == "roof_tiles":
				var barrel := 0.5 + 0.5 * cos(ax * 8)
				var seam := smoothstep(0, 5, y % 128)
				value = (0.65 + barrel * 0.22 + n * 0.10 + fine * 0.04) * lerpf(0.7, 1.0, seam)
				relief = 0.36 + barrel * 0.22 * seam
				tint = Color(1.0, 0.79, 0.64)
			elif kind == "asphalt":
				# Fine stochastic stone grain; broad periodic cracks read as flowing stripes.
				var aggregate := stone_rng.randf_range(-1.0, 1.0)
				value = 0.40 + n * 0.020 + fine * 0.012 + aggregate * 0.065
				relief = 0.5 + aggregate * 0.065
				tint = Color(0.98, 0.99, 1.0)
			elif kind == "turf":
				# Short blades, thatch and uneven growth, without a checkerboard lawn.
				var grain := stone_rng.randf_range(-1.0, 1.0)
				var dry := smoothstep(-0.12, 0.48, n)
				var blades := sin(ax * 79 + sin(ay * 47) * 2.5) * 0.025
				var green := Color("65714a").lerp(Color("91845d"), dry * 0.62)
				image.set_pixel(x, y, green * (0.95 + fine * 0.18 + grain * 0.11 + blades))
				height.set_pixel(x, y, Color(0.5 + grain * 0.10 + blades, 0.5 + grain * 0.10 + blades, 0.5 + grain * 0.10 + blades))
				continue
			elif kind == "curtain_wall":
				var cell_x := x / 128
				var cell_y := y / 128
				var px := x % 128
				var py := y % 128
				var cell_seed := posmod(cell_x * 13 + cell_y * 7, 9)
				var mullion := px < 3 or py < 4
				var reflection := 0.31 + (1.0 - py / 128.0) * 0.17 + sin(ax + ay * 0.3) * 0.045
				var pane := Color(0.71, 0.84, 0.90) * (reflection + cell_seed * 0.014)
				if cell_seed in [1, 4, 7] and py > 22 and py < 96:
					pane = pane.lerp(Color("a5a49a") * (0.70 if py % 8 < 2 else 0.92), 0.32)
				image.set_pixel(x, y, Color("354047") if mullion else pane)
				height.set_pixel(x, y, Color(0.45, 0.45, 0.45) if mullion else Color(0.5, 0.5, 0.5))
				continue
			elif kind == "window":
				# Opaque layered interior: curtains, dark room and soft sky reflection.
				var u := x / float(size)
				var v := y / float(size)
				var curtain := 1.0 - smoothstep(0.20, 0.28, minf(u, 1 - u))
				var fold := 0.70 + 0.12 * sin(ax * 17)
				var reflection := pow(1 - v, 2) * 0.16 + 0.035 * sin(ax + ay * 0.6)
				var room := Color(0.105, 0.15, 0.17) + Color(reflection, reflection, reflection)
				var fabric := Color(0.63, 0.60, 0.52) * fold
				image.set_pixel(x, y, room.lerp(fabric, curtain * 0.65))
				height.set_pixel(x, y, Color(0.5, 0.5, 0.5))
				continue
			elif kind == "shop_window":
				# Original stocked display behind opaque glazing; no transparent room geometry.
				var u := x / float(size)
				var v := y / float(size)
				var room := Color(0.11, 0.16, 0.17)
				if u > 0.14 and u < 0.86 and v > 0.22 and v < 0.72:
					var shelf := fposmod((v - 0.22) * 6, 1.0)
					var package := fposmod(u * 15, 1.0)
					var tone: Color = [Color("888968"), Color("697f7b"), Color("957c69"), Color("747770")][int(u * 15 + v * 6) % 4]
					room = tone * 0.55 if shelf < 0.72 and package > 0.12 and package < 0.82 else Color(0.09, 0.13, 0.14)
					if shelf > 0.91:
						room = Color(0.27, 0.29, 0.27)
				var reflection := pow(1 - v, 2) * 0.13 + 0.025 * sin(ax + ay)
				image.set_pixel(x, y, room + Color(reflection, reflection, reflection))
				height.set_pixel(x, y, Color(0.5, 0.5, 0.5))
				continue
			image.set_pixel(x, y, Color(value, value, value) * tint)
			height.set_pixel(x, y, Color(relief, relief, relief))
	# Encode a normal map from the original procedural height field.
	height.bump_map_to_normal_map(0.6)
	image.generate_mipmaps()
	height.generate_mipmaps()
	ResourceSaver.save(ImageTexture.create_from_image(image), OUTPUT.path_join(kind + "-albedo.res"))
	ResourceSaver.save(ImageTexture.create_from_image(height), OUTPUT.path_join(kind + "-normal.res"))
	print("Baked original surface: " + kind)
