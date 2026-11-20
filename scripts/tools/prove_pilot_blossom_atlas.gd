extends SceneTree

const Flower = preload("res://scripts/city/neighborhood_flower_mesh.gd")
const Foliage = preload("res://scripts/city/pilot_foliage_lod.gd")
const SHADER = preload("res://assets/shaders/pilot_foliage_impostor.gdshader")
const OUTPUT := "res://builds/overhaul-2026-11-19/validation/blossom-atlas"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Blossom appearance proof needs native rendering")
		quit(1)
		return
	root.size=Vector2i(320,180)
	var atlas := load(Foliage.ATLAS_PATH) as Texture2D
	if atlas.get_meta("layer_count",0)<14 or not 13 in atlas.get_meta("nonempty_layers",PackedInt32Array()):
		push_error("Proof requires the verified nonempty neutral blossom atlas extension")
		quit(1)
		return
	var source := Flower.build()
	var bounds := source.get_aabb()
	var span := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))*1.12
	var viewports: Array[SubViewport] = []
	var cameras: Array[Camera3D] = []
	var environments: Array[Environment] = []
	var lights: Array[DirectionalLight3D] = []
	for variant in 2:
		var viewport := SubViewport.new()
		viewport.size=Vector2i(512,512)
		viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var environment := Environment.new()
		environment.background_mode=Environment.BG_COLOR
		environment.background_color=Color("101820")
		environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
		var environment_node := WorldEnvironment.new()
		environment_node.environment=environment
		viewport.add_child(environment_node)
		environments.append(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-50,-25,0)
		viewport.add_child(light)
		lights.append(light)
		var camera := Camera3D.new()
		camera.fov=70
		camera.far=200
		viewport.add_child(camera)
		camera.current=true
		cameras.append(camera)
		for colour in 2:
			var tint := Color("e6bd50") if colour==0 else Color("b77cbb")
			var placement := Transform3D(Basis.IDENTITY,Vector3(-0.8 if colour==0 else 0.8,0,0))
			if variant==0:
				var geometry := MeshInstance3D.new()
				geometry.mesh=source
				geometry.transform=placement
				var material := StandardMaterial3D.new()
				material.albedo_color=tint
				material.roughness=0.95
				material.cull_mode=BaseMaterial3D.CULL_DISABLED
				geometry.material_override=material
				geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				viewport.add_child(geometry)
			else:
				var geometry := MultiMeshInstance3D.new()
				geometry.multimesh=MultiMesh.new()
				geometry.multimesh.transform_format=MultiMesh.TRANSFORM_3D
				geometry.multimesh.use_colors=true
				geometry.multimesh.use_custom_data=true
				geometry.multimesh.mesh=Foliage._cross_cards()
				geometry.multimesh.instance_count=1
				geometry.multimesh.set_instance_transform(0,placement*Transform3D(Basis.from_scale(Vector3.ONE*span),bounds.get_center()))
				geometry.multimesh.set_instance_color(0,Color.WHITE)
				geometry.multimesh.set_instance_custom_data(0,Color(13,0,0,0))
				var material := ShaderMaterial.new()
				material.shader=SHADER
				material.set_shader_parameter("foliage_atlas",atlas)
				material.set_shader_parameter("albedo_modulate",tint)
				material.set_shader_parameter("alpha_cutoff",0.15)
				geometry.material_override=material
				geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				viewport.add_child(geometry)
	var captures: Array[Dictionary] = []
	for phase in ["day","night"]:
		for environment in environments:
			environment.ambient_light_color=Color("c1ccd5") if phase=="day" else Color("6984ab")
			environment.ambient_light_energy=0.58 if phase=="day" else 0.24
		for light in lights:
			light.light_color=Color("fff1d7") if phase=="day" else Color("a8badd")
			light.light_energy=1.08 if phase=="day" else 0.17
		for distance in [5.0,50.0]:
			for angle in [0.0,35.0]:
				for camera in cameras:
					camera.position=Vector3(sin(deg_to_rad(angle))*distance,0.25,cos(deg_to_rad(angle))*distance)
					camera.look_at(bounds.get_center(),Vector3.UP)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var first := viewports[0].get_texture().get_image()
				var second := viewports[1].get_texture().get_image()
				var combined := Image.create(1024,512,false,first.get_format())
				combined.blit_rect(first,Rect2i(0,0,512,512),Vector2i.ZERO)
				combined.blit_rect(second,Rect2i(0,0,512,512),Vector2i(512,0))
				var label := "%s-distance%d-angle%d"%[phase,distance,angle]
				combined.save_png(OUTPUT.path_join(label+".png"))
				if distance==50.0:
					var detail_source := first.get_region(Rect2i(224,224,64,64))
					var detail_proxy := second.get_region(Rect2i(224,224,64,64))
					detail_source.resize(256,256,Image.INTERPOLATE_NEAREST)
					detail_proxy.resize(256,256,Image.INTERPOLATE_NEAREST)
					var detail := Image.create(512,256,false,first.get_format())
					detail.blit_rect(detail_source,Rect2i(0,0,256,256),Vector2i.ZERO)
					detail.blit_rect(detail_proxy,Rect2i(0,0,256,256),Vector2i(256,0))
					detail.save_png(OUTPUT.path_join(label+"-detail.png"))
				captures.append({"name":label,"phase":phase,"distance_metres":distance,"angle_degrees":angle})
	var file := FileAccess.open(OUTPUT.path_join("visual-proof.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"atlas_sha256":FileAccess.get_sha256(Foliage.ATLAS_PATH),"layout":"Original volumetric source left, crossed-card proxy right; gold then violet within each half", "captures":captures,"alpha_cutoff":0.15,"modulation":"Neutral white atlas multiplied once by existing gold/violet albedo_modulate; instance colour WHITE because the original material ignores vertex colours","source_triangles":source.get_faces().size()/3,"proxy_triangles":4,"scope":"Small static native appearance diagnostic only; no city, default gameplay change or FPS evidence. Five-metre views expose approximation and are outside the proposed40m/70m substitution range;50m is within the diagnostic domain. Native source normals and card wrap lighting differ, so RGB pixel parity is not claimed."},"\t")+"\n")
	file.close()
	print("Blossom source/proxy proof: %d native day/night views, no city loaded"%captures.size())
	quit()
