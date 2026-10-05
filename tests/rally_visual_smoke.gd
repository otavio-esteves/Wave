extends SceneTree

const Baked = preload("res://scripts/city/baked_multimesh.gd")
const Capture = preload("res://scripts/tools/performance_capture.gd")
var failures:=0
var checks:=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene=load("res://scenes/rally/rally_map.tscn")
	var map:=scene.instantiate()
	root.add_child(map)
	var trees:=0
	var near_trees:=0
	var trunks:=0
	var paired:=true
	var far_cheap:=true
	var grass_fades:=true
	var padded:=true
	for geometry in map.get_children():
		if not geometry is MultiMeshInstance3D:
			continue
		var kind: String=geometry.material_override.resource_name
		if kind=="conifer":
			trees+=geometry.multimesh.instance_count
			far_cheap=far_cheap and geometry.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()<=72 and geometry.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			padded=padded and geometry.multimesh.billboard_radius>0
		elif kind in ["crown_near","bark"]:
			var parent:=geometry.get_node_or_null(geometry.visibility_parent)
			paired=paired and parent is MultiMeshInstance3D and parent.material_override.resource_name=="conifer" and parent.multimesh.instance_count==geometry.multimesh.instance_count
			if kind=="crown_near":
				near_trees+=geometry.multimesh.instance_count
			else:
				trunks+=geometry.multimesh.instance_count
		elif kind=="tussock":
			grass_fades=grass_fades and geometry.visibility_range_end<=100 and geometry.visibility_range_end>=92 and geometry.material_override.distance_fade_min_distance>geometry.material_override.distance_fade_max_distance
	_check(trees>2000 and trees==near_trees and trees==trunks,"every tree retains both close volume and a distant representation")
	_check(paired,"saved LOD dependencies pair the same sectors without missing crowns/trunks")
	_check(far_cheap,"distant trees use one silhouette card without alpha-shadow passes")
	_check(grass_fades,"grass fades before its sector cutoff rather than rendering hundreds of meters away")
	_check(padded,"billboard rotation has conservative saved culling bounds")
	var terrain: MeshInstance3D=map.get_node("Terrain_0_0")
	_check(not terrain.mesh.surface_get_material(0).uv1_triplanar,"terrain uses authored UV density without three texture projections")
	var gravel: MeshInstance3D=map.get_node("Gravel")
	var material:=gravel.mesh.surface_get_material(0) as ShaderMaterial
	var road_arrays:=gravel.mesh.surface_get_arrays(0)
	_check(material!=null and road_arrays[Mesh.ARRAY_TEX_UV2].size()==road_arrays[Mesh.ARRAY_VERTEX].size(),"road material receives continuous lateral coordinates for tracks and natural shoulders")
	_check(map.get_node("GravelPhysics").get_meta("friction")==0.68 and map.get_node("Terrain_0_0Physics").get_meta("friction")==0.46,"visual LOD leaves road and terrain collision adhesion intact")
	var road_chunks := 0
	var road_length := 0
	var terrain_lods := true
	for geometry in map.get_children():
		if geometry is MeshInstance3D:
			if str(geometry.name).begins_with("Terrain_"):
				terrain_lods = terrain_lods and int(geometry.get_meta("lod_levels", 0)) >= 2
			elif str(geometry.name).begins_with("Gravel") or str(geometry.name).begins_with("Asphalt"):
				road_chunks += 1
				road_length += geometry.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 42
	_check(road_chunks >= 24 and road_length == 745, "cullable road chunks preserve all route bands without missing sections")
	_check(terrain_lods, "all terrain tiles retain detailed near geometry and multiple distant LODs")
	var textures_optimized := true
	for folder in ["res://assets/textures/race", "res://assets/textures/rally"]:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".png.import"):
				var config := ConfigFile.new()
				textures_optimized = textures_optimized and config.load(folder.path_join(file)) == OK
				textures_optimized = textures_optimized and config.get_value("params", "mipmaps/generate", false) and config.get_value("params", "compress/mode", 0) == 2
	_check(textures_optimized, "3D textures use mip chains and GPU compression across circuit and rally")
	var multimesh:=Baked.new()
	var card:=QuadMesh.new()
	card.size=Vector2(10,20)
	multimesh.mesh=card
	multimesh.billboard_radius=5
	multimesh.instance_transforms=[Transform3D.IDENTITY]
	var bounds: AABB=multimesh.custom_aabb
	var contained:=true
	for yaw in 16:
		var basis:=Basis(Vector3.UP,yaw*TAU/16)
		for corner in [Vector3(-5,-10,0),Vector3(5,10,0)]:
			contained=contained and bounds.grow(0.001).has_point(basis*corner)
	_check(contained,"a rotating billboard remains inside its bounds from every viewing direction")
	var capture:=Node.new()
	capture.set_script(Capture)
	root.add_child(capture)
	capture.set_process(false)
	capture.recording=true
	capture._last_frame_usec=Time.get_ticks_usec()-250000
	capture._process(0.016)
	_check(capture.elapsed>=0.25 and capture._frames[0]>=250,"GPU frame timing uses actual time even when engine delta is capped")
	var before: float=capture.elapsed
	var frame_count: int=capture._frames.size()
	capture._notification(Node.NOTIFICATION_PAUSED)
	capture._process(3.0)
	_check(capture.elapsed==before and capture._frames.size()==frame_count,"pause/resume excludes the paused gap from measured frames")
	capture.recording=false
	capture._process(1.0)
	_check(capture.elapsed==before,"stopped capture does not accumulate frames")
	capture.queue_free()
	map.queue_free()
	await process_frame
	print("Rally visual checks: %d passed / %d failed" % [checks-failures,failures])
	quit(0 if failures==0 else 1)

func _check(condition: bool,message: String) -> void:
	checks+=1
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)
