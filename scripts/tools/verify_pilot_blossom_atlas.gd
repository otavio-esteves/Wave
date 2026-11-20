extends SceneTree

const Patch = preload("res://scripts/tools/pilot_foliage_atlas_extension.gd")
const ATLAS := "res://assets/textures/pilot/foliage-impostors.res"
const PROVENANCE := "res://assets/textures/pilot/foliage-blossom-extension.provenance.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PROVENANCE))
	var atlas := load(ATLAS) as Texture2D
	var image := atlas.get_image()
	var protected_sha := Patch.outside_digest(image)
	var valid: bool=atlas.get_meta("layer_count",0)==14 and 13 in atlas.get_meta("nonempty_layers",PackedInt32Array())
	valid=valid and image.get_size()==Vector2i(2048,1024) and image.has_mipmaps()
	valid=valid and protected_sha==proof.protected_bytes_sha256_before and protected_sha==proof.protected_bytes_sha256_after
	valid=valid and FileAccess.get_sha256(ATLAS)==proof.atlas_resource_sha256_after
	var expected: Array[String]=[]
	for variant in 6:
		expected.append("tree_leaves%d"%variant)
	expected.append("shrub")
	for variant in 6:
		expected.append("tree_bark%d"%variant)
	var layers: Array=atlas.get_meta("layers",[])
	for index in expected.size():
		valid=valid and layers[index].kind==expected[index]
	valid=valid and layers[13].kind=="flower_cluster" and int(layers[13].source_triangles)==90
	var neutral:=true
	var occupied: Array[int]=[]
	for view in 2:
		var count:=0
		for y in range(768,1024):
			for x in range((2+view)*256,(3+view)*256):
				var colour:=image.get_pixel(x,y)
				neutral=neutral and colour.r==1.0 and colour.g==1.0 and colour.b==1.0
				if colour.a>0.15:
					count+=1
		occupied.append(count)
	valid=valid and neutral and occupied[0]==proof.source_alpha_pixels_above_0_15[0] and occupied[1]==proof.source_alpha_pixels_above_0_15[1]
	print("Blossom atlas artifact: layers=%d neutral=%s protected_mip_bytes_identical=%s occupied=%s valid=%s"%[layers.size(),neutral,protected_sha==proof.protected_bytes_sha256_before,occupied,valid])
	if not valid:
		push_error("Reloaded blossom atlas failed protected mip, metadata, colour or provenance proof")
	quit(0 if valid else 1)
