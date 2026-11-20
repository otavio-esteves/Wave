extends SceneTree

# Bake the original geometry, not an illustration of a different tree. Copas,
# shrubs and trunks have separate cells so their different pivots/scales remain
# independent in the runtime HLOD.
const CELL := 256
const COLUMNS := 8
const ROWS := 4
const VIEWS := 2
const OUTPUT := "res://assets/textures/pilot/foliage-impostors.res"
var images: Array[Image] = []
var records: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Foliage atlas baking requires a rendered viewport")
		quit(1)
		return
	var output := OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var builder := preload("res://scripts/city/pilot_city_builder.gd").new()
	builder._tree_palette()
	var kinds: Array[String] = []
	for variant in 6:
		kinds.append("tree_leaves%d" % variant)
	kinds.append("shrub")
	for variant in 6:
		kinds.append("tree_bark%d" % variant)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL, CELL)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	var geometry := MeshInstance3D.new()
	geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(geometry)
	for kind in kinds:
		var mesh: Mesh = builder.meshes[kind]
		var material: StandardMaterial3D = builder.materials["tree_bark" if kind.begins_with("tree_bark") else "tree_leaves"].duplicate()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		geometry.mesh = mesh
		geometry.material_override = material
		var bounds := mesh.get_aabb()
		var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.12
		camera.size = span
		records.append({"kind": kind, "layer": records.size(), "aabb_position": bounds.position, "aabb_size": bounds.size, "span": span, "source_triangles": mesh.get_faces().size() / 3})
		for view in VIEWS:
			var direction := Vector3.BACK if view == 0 else Vector3.RIGHT
			camera.position = bounds.get_center() + direction * 4.0
			camera.look_at(bounds.get_center(), Vector3.UP)
			# Commands from the changed source material must reach the viewport.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			images.append(image)
	viewport.queue_free()
	await process_frame
	var atlas := _atlas_with_isolated_mips()
	var texture := ImageTexture.create_from_image(atlas)
	texture.resource_name = "PilotFoliageImpostors"
	texture.set_meta("schema_version", 1)
	texture.set_meta("columns", COLUMNS)
	texture.set_meta("rows", ROWS)
	texture.set_meta("views", VIEWS)
	texture.set_meta("layers", records)
	var error := ResourceSaver.save(texture, output, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Cannot save foliage atlas: " + error_string(error))
		quit(1)
		return
	print("Foliage atlas: %d source layers, %d views, %dx%d, %s" % [records.size(), images.size(), atlas.get_width(), atlas.get_height(), output])
	quit()


func _atlas_with_isolated_mips() -> Image:
	# Build every cell's mip independently. Generating mips on the combined
	# atlas would blend the silhouettes/colours of neighbouring tree species.
	var data := PackedByteArray()
	var width := CELL * COLUMNS
	var height := CELL * ROWS
	var level := 0
	while width > 0 and height > 0:
		var mip := Image.create(width, height, false, Image.FORMAT_RGBA8)
		mip.fill(Color.TRANSPARENT)
		var cell := CELL >> level
		if cell > 0:
			for index in images.size():
				var image := images[index].duplicate() as Image
				image.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
				mip.blit_rect(image, Rect2i(0, 0, cell, cell), Vector2i(index % COLUMNS, index / COLUMNS) * cell)
		data.append_array(mip.get_data())
		if width == 1 and height == 1:
			break
		width = maxi(1, width >> 1)
		height = maxi(1, height >> 1)
		level += 1
	return Image.create_from_data(CELL * COLUMNS, CELL * ROWS, true, Image.FORMAT_RGBA8, data)
