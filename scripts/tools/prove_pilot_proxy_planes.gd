extends SceneTree

const Planes = preload("res://scripts/city/pilot_proxy_planes.gd")
const OUTPUT := "res://builds/overhaul-2026-11-19/validation/flat-thin-swatch"
var records: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Plane proof requires native rendered pixels")
		quit(1)
		return
	root.size = Vector2i(320,180)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var viewports: Array[SubViewport] = []
	var objects: Array[MeshInstance3D] = []
	var cameras: Array[Camera3D] = []
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b9b6ad")
	material.roughness = 1.0
	for index in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512,512)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("101820")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("99a7b2")
		environment.environment.ambient_light_energy = 0.6
		environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		viewport.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-42,-24,0)
		light.light_color = Color("fff1d7")
		viewport.add_child(light)
		var object := MeshInstance3D.new()
		object.material_override = material
		viewport.add_child(object)
		objects.append(object)
		var camera := Camera3D.new()
		camera.fov = 70.0
		camera.far = 1000.0
		viewport.add_child(camera)
		camera.current = true
		cameras.append(camera)
	var source := BoxMesh.new()
	source.size = Vector3.ONE
	objects[0].mesh = source
	var valid := true
	for axis in 3:
		for cull in [BaseMaterial3D.CULL_BACK,BaseMaterial3D.CULL_FRONT,BaseMaterial3D.CULL_DISABLED]:
			material.cull_mode = cull
			var proxy := Planes.mesh(axis,cull)
			objects[1].mesh = proxy
			valid = valid and proxy.get_aabb() == source.get_aabb() and proxy.surface_get_array_index_len(0) == 12 and proxy.surface_get_array_len(0) == 8
			var scale := Vector3(8,3,8)
			scale[axis] = 0.3
			var rotation := Basis.from_euler(Vector3(0.17,0.4,-0.11))
			var transform := Transform3D(rotation * Basis.from_scale(scale),Vector3.ZERO)
			for object in objects:
				object.transform = transform
			for angle in [0.0,35.0,145.0,180.0]:
				var normal := Vector3.ZERO
				normal[axis] = 1.0
				var tangent := Vector3.RIGHT if axis != 0 else Vector3.FORWARD
				var direction := rotation * (normal*cos(deg_to_rad(angle))+tangent*sin(deg_to_rad(angle)))
				for camera in cameras:
					camera.position = direction*240.0
					camera.look_at(Vector3.ZERO, rotation*Vector3.UP if axis != 1 else rotation*Vector3.BACK)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var first := viewports[0].get_texture().get_image()
				var second := viewports[1].get_texture().get_image()
				var record := _compare(first,second)
				record.merge({"axis":axis,"cull_mode":cull,"view_angle_degrees":angle,"distance_metres":240,"source_dimensions":scale,"same_nonuniform_rotated_transform":true,"conservative_aabb_equal":proxy.get_aabb()==source.get_aabb()})
				records.append(record)
				valid = valid and record.interior_pixels > 0 and record.interior_max_error_rgb <= 1.0/255.0 and record.maximum_bounds_shift_pixels <= 1
				if axis==2 and cull==BaseMaterial3D.CULL_BACK:
					var combined := Image.create(1024,512,false,first.get_format())
					combined.blit_rect(first,Rect2i(0,0,512,512),Vector2i.ZERO)
					combined.blit_rect(second,Rect2i(0,0,512,512),Vector2i(512,0))
					combined.save_png(OUTPUT.path_join("z-axis-angle-%d.png"%angle))
					var detail := combined.get_region(Rect2i(224,224,64,64))
					var detail_proxy := combined.get_region(Rect2i(736,224,64,64))
					detail.resize(256,256,Image.INTERPOLATE_NEAREST)
					detail_proxy.resize(256,256,Image.INTERPOLATE_NEAREST)
					var enlarged := Image.create(512,256,false,first.get_format())
					enlarged.blit_rect(detail,Rect2i(0,0,256,256),Vector2i.ZERO)
					enlarged.blit_rect(detail_proxy,Rect2i(0,0,256,256),Vector2i(256,0))
					enlarged.save_png(OUTPUT.path_join("z-axis-angle-%d-detail.png"%angle))
	var file := FileAccess.open(OUTPUT.path_join("proof.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"valid":valid,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"scope":"Two isolated objects in separate equal worlds, one opaque BoxMesh and one four-triangle original-major-face proxy; no city, shadows, textures, fog or gameplay changes. All cases at 240m, 512px square vertical70degree field of view. Conservative AABB is unchanged; tiny missing side faces are only accepted within one-pixel bounds.","records":records},"\t")+"\n")
	file.close()
	print("Flat-thin native proof: %d comparisons valid=%s"%[records.size(),valid])
	if not valid:
		push_error("Flat-thin proof requires review: color, two-sided lighting or silhouette tolerance failed")
	quit(0 if valid else 1)


func _compare(first:Image,second:Image)->Dictionary:
	first = first.get_region(Rect2i(224,224,64,64))
	second = second.get_region(Rect2i(224,224,64,64))
	var background := first.get_pixel(0,0)
	var first_mask: Dictionary = {}
	var second_mask: Dictionary = {}
	var bounds_first := Rect2i()
	var bounds_second := Rect2i()
	for y in first.get_height():
		for x in first.get_width():
			var point:=Vector2i(x,y)
			if _difference(first.get_pixel(x,y),background)>0.02:
				first_mask[point]=true
				bounds_first=Rect2i(point,Vector2i.ONE) if first_mask.size()==1 else bounds_first.merge(Rect2i(point,Vector2i.ONE))
			if _difference(second.get_pixel(x,y),background)>0.02:
				second_mask[point]=true
				bounds_second=Rect2i(point,Vector2i.ONE) if second_mask.size()==1 else bounds_second.merge(Rect2i(point,Vector2i.ONE))
	var interior := 0
	var maximum := 0.0
	for point:Vector2i in first_mask:
		if not second_mask.has(point):
			continue
		var inside:=true
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			inside=inside and first_mask.has(point+offset) and second_mask.has(point+offset)
		if inside:
			interior+=1
			maximum=maxf(maximum,_difference(first.get_pixelv(point),second.get_pixelv(point)))
	var shift := maxi(maxi(absi(bounds_first.position.x-bounds_second.position.x),absi(bounds_first.position.y-bounds_second.position.y)),maxi(absi(bounds_first.end.x-bounds_second.end.x),absi(bounds_first.end.y-bounds_second.end.y)))
	return {"pixel_bounds_roi_origin":Vector2i(224,224),"source_pixels":first_mask.size(),"proxy_pixels":second_mask.size(),"interior_pixels":interior,"interior_max_error_rgb":maximum,"source_pixel_bounds":bounds_first,"proxy_pixel_bounds":bounds_second,"maximum_bounds_shift_pixels":shift}


func _difference(first:Color,second:Color)->float:
	return maxf(absf(first.r-second.r),maxf(absf(first.g-second.g),absf(first.b-second.b)))
