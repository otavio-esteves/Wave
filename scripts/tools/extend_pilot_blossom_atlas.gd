extends SceneTree

const Patch = preload("res://scripts/tools/pilot_foliage_atlas_extension.gd")
const Flower = preload("res://scripts/city/neighborhood_flower_mesh.gd")
const ATLAS := "res://assets/textures/pilot/foliage-impostors.res"
const PROVENANCE := "res://assets/textures/pilot/foliage-blossom-extension.provenance.json"
const BACKUP := "res://builds/overhaul-2026-11-19/validation/blossom-atlas/foliage-before.res"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Blossom source views require a small rendered viewport")
		quit(1)
		return
	root.size=Vector2i(320,180)
	DirAccess.make_dir_recursive_absolute(BACKUP.get_base_dir())
	if not FileAccess.file_exists(BACKUP):
		var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(ATLAS),ProjectSettings.globalize_path(BACKUP))
		if copy_error != OK:
			push_error("Cannot preserve original atlas")
			quit(1)
			return
	var original := load(BACKUP) as Texture2D
	var layers: Array = original.get_meta("layers",[]).duplicate(true)
	if layers.size()!=13:
		push_error("Blossom extension requires the preserved original thirteen-layer atlas")
		quit(1)
		return
	var source := Flower.build()
	var bounds := source.get_aabb()
	var span := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))*1.12
	var viewport := SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=span
	viewport.add_child(camera)
	camera.current=true
	var geometry := MeshInstance3D.new()
	geometry.mesh=source
	var material := StandardMaterial3D.new()
	material.albedo_color=Color.WHITE
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	geometry.material_override=material
	geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(geometry)
	var views: Array[Image] = []
	var occupied: Array[int] = []
	for view in 2:
		camera.position=bounds.get_center()+(Vector3.BACK if view==0 else Vector3.RIGHT)*4.0
		camera.look_at(bounds.get_center(),Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var count := 0
		# A neutral plate carries only alpha coverage. White RGB in transparent
		# texels also prevents dark edge tint when a sparse petal is minified.
		for y in image.get_height():
			for x in image.get_width():
				var alpha := image.get_pixel(x,y).a
				if alpha>0.15:
					count+=1
				image.set_pixel(x,y,Color(1,1,1,alpha))
		views.append(image)
		occupied.append(count)
		image.save_png(BACKUP.get_base_dir().path_join("neutral-source-view-%d.png"%view))
	viewport.queue_free()
	await process_frame
	var patch := Patch.append_flower(original.get_image(),views)
	if not patch.unchanged_outside_new_cells or mini(occupied[0],occupied[1])==0:
		push_error("Protected atlas bytes changed or the new blossom layer is empty")
		quit(1)
		return
	layers.append({"kind":"flower_cluster","layer":13,"aabb_position":bounds.position,"aabb_size":bounds.size,"span":span,"source_triangles":source.get_faces().size()/3,"neutral_white_rgb":true})
	var texture := ImageTexture.create_from_image(patch.image)
	texture.resource_name=original.resource_name
	for key in original.get_meta_list():
		texture.set_meta(key,original.get_meta(key))
	texture.set_meta("layers",layers)
	texture.set_meta("layer_count",14)
	texture.set_meta("nonempty_layers",PackedInt32Array(range(14)))
	texture.set_meta("neutral_blossom_layer",13)
	texture.set_meta("protected_existing_texels_sha256",patch.protected_bytes_sha256_before)
	var error := ResourceSaver.save(texture,ATLAS,ResourceSaver.FLAG_COMPRESS)
	if error!=OK:
		push_error("Cannot save extended atlas: "+error_string(error))
		quit(1)
		return
	patch.erase("image")
	patch.merge({"mode":"Two native orthographic views of the exact original Flower.build() mesh; no city loaded", "source":"res://scripts/city/neighborhood_flower_mesh.gd","source_sha256":FileAccess.get_sha256("res://scripts/city/neighborhood_flower_mesh.gd"),"patcher_sha256":FileAccess.get_sha256("res://scripts/tools/pilot_foliage_atlas_extension.gd"),"atlas":ATLAS,"atlas_resource_sha256_before":FileAccess.get_sha256(BACKUP),"atlas_resource_sha256_after":FileAccess.get_sha256(ATLAS),"source_layer":layers[13],"source_alpha_pixels_above_0_15":occupied,"colour_policy":"Neutral white RGB, exact rendered alpha coverage; gold/violet supplied once by existing source material albedo_modulate; source vertex tints ignored when source vertex_color_use_as_albedo is false","mip_policy":"Only cells26/27 are patched at each independently downsampled mip; old cells and all smaller-than-cell tail mips are byte-identical","runtime_scope":"Diagnostic blossom-hlod only; default game foliage domain unchanged"})
	var file := FileAccess.open(PROVENANCE,FileAccess.WRITE)
	file.store_string(JSON.stringify(patch,"\t")+"\n")
	file.close()
	var main_path := "res://assets/textures/pilot/foliage-provenance.json"
	var main: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main_path))
	main.atlas.sha256=FileAccess.get_sha256(ATLAS)
	if not "flower_cluster" in main.atlas.layers:
		main.atlas.layers.append("flower_cluster")
	main["blossom_extension_provenance"]=PROVENANCE
	file=FileAccess.open(main_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(main,"\t")+"\n")
	file.close()
	print("Blossom atlas:14 layers,2 new views, protected bytes identical=%s, alpha pixels=%s"%[patch.unchanged_outside_new_cells,occupied])
	quit()
