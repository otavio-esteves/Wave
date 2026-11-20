extends SceneTree

const Baked = preload("res://scripts/city/baked_multimesh.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3(2, 3, 4)
	var rotated := Transform3D(Basis.from_euler(Vector3(0.2, 0.7, -0.1)).scaled(Vector3(2, 3, 4)), Vector3(-17, 9, 201))
	var placements: Array[Transform3D] = [rotated, Transform3D.IDENTITY]
	var tints := PackedColorArray([Color(0.2, 0.4, 0.6, 0.8)])
	var source := Baked.new()
	source.mesh = cube
	source.set_instances(placements, tints)
	source.billboard_radius = 6.0
	source.visible_instance_count = 1
	var saved_bounds: AABB = source.custom_aabb
	var expected := Baked.make_buffer(placements, tints)
	for extension: String in ["tres", "res"]:
		var path := "user://prepacked." + extension
		_check(ResourceSaver.save(source, path, ResourceSaver.FLAG_COMPRESS if extension == "res" else 0) == OK, "prepacked resource saves as " + extension)
		var loaded := ResourceLoader.load(path, "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MultiMesh
		_check(loaded != null and loaded.instance_transforms == placements and loaded.instance_tints == tints, extension + " restores every typed source transform and colour")
		_check(loaded.instance_count == 2 and loaded.use_colors and loaded.transform_format == MultiMesh.TRANSFORM_3D and loaded.visible_instance_count == 1, extension + " restores native layout and visible-instance limit atomically")
		_check(loaded.custom_aabb == saved_bounds and loaded.billboard_radius == 6.0, extension + " preserves saved padded bounds without adding padding twice")
		var work: Dictionary = loaded.load_work()
		print("LOAD_WORK: ", work)
		_check(work.prepacked_loads == 1 and work.rebuilds == 0 and work.buffer_packs == 0 and work.bounds_scans == 0, extension + " loads without per-instance repacking or bounds scans")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			_check(work.uploads == 1 and _native_buffer_matches(loaded.buffer, expected, extension), extension + " uploads unchanged transform floats and format-accurate colours once")
		else:
			_check(work.uploads == 0, extension + " keeps offline loading independent of the dummy render buffer")
	var text := FileAccess.get_file_as_string("user://prepacked.tres")
	var individual_sources := RegEx.create_from_string("(?m)^(instance_transforms|instance_tints|billboard_radius|custom_aabb|instance_count|use_colors|transform_format|visible_instance_count|buffer) =")
	_check(text.contains("baked_payload =") and individual_sources.search(text) == null, "new files have one payload and no duplicated source/native storage properties")
	var legacy_file := FileAccess.open("user://legacy-baked.tres", FileAccess.WRITE)
	legacy_file.store_string('[gd_resource type="MultiMesh" load_steps=3 format=3]\n[ext_resource type="Script" path="res://scripts/city/baked_multimesh.gd" id="1"]\n[sub_resource type="BoxMesh" id="cube"]\nsize = Vector3(2, 3, 4)\n[resource]\ntransform_format = 1\nuse_colors = true\ninstance_count = 2\nmesh = SubResource("cube")\nscript = ExtResource("1")\nbillboard_radius = 6.0\ninstance_transforms = %s\ninstance_tints = %s\n' % [var_to_str(placements), var_to_str(tints)])
	legacy_file.close()
	var legacy := ResourceLoader.load("user://legacy-baked.tres", "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MultiMesh
	_check(legacy != null and legacy.instance_transforms == placements and legacy.instance_tints == tints and legacy.custom_aabb == saved_bounds, "legacy individual properties still deserialize with identical source data and bounds")
	_check(legacy.load_work().prepacked_loads == 0 and legacy.load_work().rebuilds == 2 and legacy.load_work().bounds_scans > 0, "legacy loading follows its compatibility rebuild path")
	_check(ResourceSaver.save(legacy, "user://legacy-migrated.res", ResourceSaver.FLAG_COMPRESS) == OK, "saving a legacy batch migrates it to the atomic payload")
	var migrated := ResourceLoader.load("user://legacy-migrated.res", "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MultiMesh
	_check(migrated.instance_transforms == placements and migrated.instance_tints == tints and migrated.load_work().prepacked_loads == 1 and migrated.load_work().bounds_scans == 0, "migrated resources preserve authoring while using the fast path")
	for mutation: String in ["version", "length", "bounds"]:
		var payload: Dictionary = source.baked_payload
		if mutation == "version":
			payload.version = 999
		elif mutation == "length":
			payload.upload = PackedFloat32Array([1, 2, 3])
		else:
			payload.bounds = AABB(Vector3.ZERO, Vector3(-1, 2, 3))
		var fallback := Baked.new()
		fallback.mesh = cube
		fallback.baked_payload = payload
		_check(fallback.load_work().fallback_loads == 1 and fallback.load_work().prepacked_loads == 0 and fallback.instance_transforms == placements and fallback.custom_aabb == saved_bounds, "invalid " + mutation + " cache rebuilds safely from authoritative sources")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			_check(_native_buffer_matches(fallback.buffer, expected, mutation), "invalid " + mutation + " cache never uploads a truncated or incompatible buffer")
	var root_node := Node3D.new()
	var geometry := MultiMeshInstance3D.new()
	geometry.name = "Batch"
	geometry.multimesh = source
	root_node.add_child(geometry)
	geometry.owner = root_node
	var packed := PackedScene.new()
	packed.pack(root_node)
	_check(ResourceSaver.save(packed, "user://prepacked-scene.scn", ResourceSaver.FLAG_COMPRESS) == OK, "prepacked data embeds in a binary PackedScene")
	root_node.free()
	packed = ResourceLoader.load("user://prepacked-scene.scn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var instance := packed.instantiate()
	var scene_batch: MultiMesh = instance.get_node("Batch").multimesh
	_check(scene_batch.instance_transforms == placements and scene_batch.instance_tints == tints and scene_batch.custom_aabb == saved_bounds and scene_batch.load_work().buffer_packs == 0, "binary scene roundtrip preserves typed sources and avoids runtime repacking")
	instance.free()
	var edited: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(-5, 8, 13))]
	migrated.set_instances(edited)
	_check(migrated.instance_count == 1 and not migrated.use_colors and migrated.load_work().rebuilds == 1 and migrated.custom_aabb.get_center().is_equal_approx(Vector3(-5, 8, 13)), "runtime atomic edits still rebuild colours, counts and bounds")
	ResourceSaver.save(migrated, "user://uncoloured-baked.res", ResourceSaver.FLAG_COMPRESS)
	var uncoloured := ResourceLoader.load("user://uncoloured-baked.res", "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MultiMesh
	_check(uncoloured.instance_count == 1 and not uncoloured.use_colors and uncoloured.instance_transforms == edited and uncoloured.load_work().buffer_packs == 0 and uncoloured.load_work().bounds_scans == 0, "nonempty uncoloured batches load their twelve-float layout without repacking")
	migrated.instance_transforms[0] = Transform3D(Basis.IDENTITY, Vector3(4, 7, -9))
	migrated.rebuild_instances()
	_check(migrated.custom_aabb.get_center().is_equal_approx(Vector3(4, 7, -9)), "explicit rebuild still supports in-place authoring edits")
	var empty_placements: Array[Transform3D] = []
	migrated.set_instances(empty_placements)
	_check(migrated.instance_count == 0 and migrated.custom_aabb == AABB(), "empty runtime edits release the previous count and visibility bounds")
	ResourceSaver.save(migrated, "user://empty-baked.res")
	var empty := ResourceLoader.load("user://empty-baked.res", "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MultiMesh
	_check(empty.instance_count == 0 and empty.instance_transforms.is_empty() and empty.custom_aabb == AABB() and empty.load_work().buffer_packs == 0, "empty batches roundtrip through the same cache path")
	if "--render-proof" in OS.get_cmdline_user_args():
		await _render_proof()
	print("Baked MultiMesh: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _render_proof() -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "render proof requires a native display")
		return
	var output := "user://prepacked-render-parity.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--render-proof-output="):
			output = argument.trim_prefix("--render-proof-output=")
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var placements: Array[Transform3D] = [
		Transform3D(Basis.from_euler(Vector3(0.2, 0.6, -0.1)).scaled(Vector3(1.2, 1.9, 0.6)), Vector3(-2, 0.9, 0)),
		Transform3D(Basis(Vector3.UP, -0.4).scaled(Vector3(0.7, 1.2, 1.4)), Vector3(1.3, 0.6, 0.5)),
		Transform3D(Basis.from_scale(Vector3(0.8, 0.6, 0.9)), Vector3(0.1, 0.3, -2)),
	]
	var tints := PackedColorArray([Color(0.26, 0.67, 0.5), Color(0.8, 0.4, 0.18), Color(0.25, 0.45, 0.8)])
	var source := Baked.new()
	source.mesh = cube
	source.set_instances(placements, tints)
	ResourceSaver.save(source, "user://render-prepacked.res", ResourceSaver.FLAG_COMPRESS)
	var cached := ResourceLoader.load("user://render-prepacked.res", "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as MultiMesh
	var legacy: MultiMesh = ResourceLoader.load("user://legacy-baked.tres", "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	legacy.mesh = cube
	legacy.set_instances(placements, tints)
	legacy.visible_instance_count = -1
	_check(cached.buffer == legacy.buffer and cached.load_work().uploads == 1, "rendered legacy and cached resources have identical native GPU instance data")
	var viewports: Array[SubViewport] = []
	for batch in [legacy, cached]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 256)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var geometry := MultiMeshInstance3D.new()
		geometry.multimesh = batch
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		geometry.material_override = material
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		viewport.add_child(geometry)
		var light := DirectionalLight3D.new()
		light.rotation = Vector3(-0.7, -0.4, 0)
		viewport.add_child(light)
		var world_environment := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.13, 0.15, 0.18)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color.WHITE
		environment.ambient_light_energy = 0.4
		world_environment.environment = environment
		viewport.add_child(world_environment)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 8.0
		camera.position = Vector3(7, 6, 10)
		viewport.add_child(camera)
		camera.look_at(Vector3(0, 0.5, 0))
		camera.current = true
	for frame in 4:
		await RenderingServer.frame_post_draw
	var images: Array[Image] = []
	for viewport in viewports:
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
	_check(images[0].get_data() == images[1].get_data(), "legacy and prepacked render identical pixels for rotated scaled tinted instances")
	var background := images[0].get_pixel(0, 0)
	var non_background := 0
	for y in range(8, 256, 16):
		for x in range(8, 320, 16):
			if not images[0].get_pixel(x, y).is_equal_approx(background):
				non_background += 1
	_check(non_background > 5, "render comparison contains visible geometry rather than two empty images")
	var combined := Image.create(640, 256, false, Image.FORMAT_RGBA8)
	combined.blit_rect(images[0], Rect2i(0, 0, 320, 256), Vector2i.ZERO)
	combined.blit_rect(images[1], Rect2i(0, 0, 320, 256), Vector2i(320, 0))
	_check(combined.save_png(output) == OK, "rendered parity proof saves its side-by-side artifact")
	var edited: Array[Transform3D] = placements.duplicate()
	var moved := edited[0]
	moved.origin += Vector3(-0.4, 1.0, 0.2)
	edited[0] = moved
	var edited_tints := tints.duplicate()
	edited_tints[1] = Color(0.7, 0.25, 0.65)
	legacy.set_instances(edited, edited_tints)
	cached.set_instances(edited, edited_tints)
	for frame in 3:
		await RenderingServer.frame_post_draw
	_check(cached.buffer == legacy.buffer and _native_buffer_matches(cached.buffer, Baked.make_buffer(edited, edited_tints), "runtime-edit"), "set_instances edits upload identical native transforms and colours after prepacked loading")
	var edited_images: Array[Image] = []
	for viewport in viewports:
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		edited_images.append(image)
	_check(edited_images[0].get_data() == edited_images[1].get_data() and edited_images[0].get_data() != images[0].get_data(), "runtime-edited legacy and prepacked resources render identical changed pixels")
	combined.blit_rect(edited_images[0], Rect2i(0, 0, 320, 256), Vector2i.ZERO)
	combined.blit_rect(edited_images[1], Rect2i(0, 0, 320, 256), Vector2i(320, 0))
	_check(combined.save_png(output.get_basename() + "-edited.png") == OK, "rendered runtime-edit parity saves its second artifact")
	print("Prepacked render proof: left legacy, right prepacked; GPU=%s; %s" % [RenderingServer.get_video_adapter_name(), output])
	for viewport in viewports:
		viewport.queue_free()
	await process_frame


func _native_buffer_matches(actual: PackedFloat32Array, expected: PackedFloat32Array, context: String) -> bool:
	var transform_error := 0.0
	var colour_error := 0.0
	if actual.size() == expected.size():
		for index in actual.size():
			var difference := absf(actual[index] - expected[index])
			if index % 16 < 12:
				transform_error = maxf(transform_error, difference)
			else:
				colour_error = maxf(colour_error, difference)
	# Compatibility may truncate instance colours to binary16. For the unit-
	# range test tints, the largest spacing below one is 1/2048. Transform
	# entries retain their original float32 bytes and receive no tolerance.
	var colour_limit := 1.0 / 2048.0
	print("NATIVE_BUFFER_ERROR: ", JSON.stringify({"context": context, "actual_floats": actual.size(), "expected_floats": expected.size(), "transform_max_abs_error": transform_error, "colour_max_abs_error": colour_error, "colour_abs_error_limit": colour_limit}))
	return actual.size() == expected.size() and transform_error == 0.0 and colour_error <= colour_limit


func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
