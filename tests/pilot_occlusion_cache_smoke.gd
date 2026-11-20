extends SceneTree

const PATH := "res://assets/geometry/pilot-occlusion-experiment.res"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH.get_basename()+".provenance.json"))
	var cache := load(PATH) as ArrayOccluder3D
	var vertices := cache.vertices
	var indices := cache.indices
	var count := int(cache.get_meta("box_count",0))
	var valid: bool = count > 0 and count == proof.boxes.size() and vertices.size() == count*8 and indices.size() == count*36
	valid = valid and cache.get_meta("source_generation","") == proof.source_generation
	valid = valid and FileAccess.get_sha256(PATH) == proof.output_sha256
	valid = valid and FileAccess.get_sha256(proof.source_entry) == proof.source_entry_sha256
	valid = valid and FileAccess.get_sha256(proof.source_generation.path_join("city.scn")) == proof.source_generation_entry_sha256
	valid = valid and FileAccess.get_sha256(proof.baker) == proof.baker_sha256
	var maximum_fraction := 0.0
	for box_index in count:
		var box: Dictionary = proof.boxes[box_index]
		var t: Array = box.transform
		var transform := Transform3D(Basis(Vector3(t[0],t[1],t[2]),Vector3(t[3],t[4],t[5]),Vector3(t[6],t[7],t[8])),Vector3(t[9],t[10],t[11]))
		var inverse := transform.affine_inverse()
		var half := Vector3(box.size[0],box.size[1],box.size[2])*0.5
		for point_index in range(box_index*8,box_index*8+8):
			var local := inverse*vertices[point_index]
			var fraction := local.abs()/half
			maximum_fraction = maxf(maximum_fraction,maxf(fraction.x,maxf(fraction.y,fraction.z)))
			valid = valid and fraction.x < 1.0 and fraction.y < 1.0 and fraction.z < 1.0
		for triangle_index in range(box_index*36,box_index*36+36):
			valid = valid and indices[triangle_index] >= box_index*8 and indices[triangle_index] < box_index*8+8
		valid = valid and box.hlod_class in ["house","tower"] and box.dimensions[0]>=6 and box.dimensions[1]>=2 and box.dimensions[2]>=6
	print("Occlusion cache: boxes=%d vertices=%d triangles=%d maximum_source_halfextent_fraction=%.8f valid=%s"%[count,vertices.size(),indices.size()/3,maximum_fraction,valid])
	if not valid:
		push_error("Occlusion cache provenance, closed-volume containment or independent-box topology failed")
	quit(0 if valid else 1)
