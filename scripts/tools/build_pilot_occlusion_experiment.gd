extends SceneTree

const Baker = preload("res://scripts/tools/pilot_occlusion_baker.gd")
const SOURCE := "res://scenes/city/pilot/pilot_city.scn"
const OUTPUT := "res://assets/geometry/pilot-occlusion-experiment.res"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var started := Time.get_ticks_usec()
	# Instantiate the raw saved city outside the tree: no runtime HLOD, art,
	# streaming, world setup, editor import or source publication can execute.
	var packed := load(SOURCE) as PackedScene
	var city := packed.instantiate() as Node3D
	var result := Baker.build(city)
	if result.boxes.is_empty():
		push_error("No eligible source boxes: empty occlusion output must never replace the diagnostic cache")
		city.free()
		quit(1)
		return
	var generation: String = city.get_meta("generation_directory", "")
	var occluder := ArrayOccluder3D.new()
	occluder.resource_name = "PilotOcclusionExperiment"
	occluder.set_arrays(result.vertices, result.indices)
	occluder.set_meta("source_generation", generation)
	occluder.set_meta("box_count", result.boxes.size())
	occluder.set_meta("triangle_count", result.indices.size() / 3)
	occluder.set_meta("source_entry_sha256", FileAccess.get_sha256(SOURCE))
	occluder.set_meta("experimental_only", true)
	var error := ResourceSaver.save(occluder, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Occlusion diagnostic save failed: " + error_string(error))
		city.free()
		quit(1)
		return
	var provenance := {"schema": 1, "purpose": "Unused by gameplay. Opt-in native-profiler occlusion experiment only; static source boxes do not track gameplay visibility/HLOD ranges.", "source_entry": SOURCE, "source_entry_sha256": FileAccess.get_sha256(SOURCE), "source_generation": generation, "source_generation_entry_sha256": FileAccess.get_sha256(generation.path_join("city.scn")), "baker": "res://scripts/tools/pilot_occlusion_baker.gd", "baker_sha256": FileAccess.get_sha256("res://scripts/tools/pilot_occlusion_baker.gd"), "output": OUTPUT, "output_sha256": FileAccess.get_sha256(OUTPUT), "inset_factor": Baker.INSET, "minimum_dimensions_metres": [6,2,6], "coordinate_space": "City local, excluding City root transform; all authored descendant/instance transforms retained", "box_count": result.boxes.size(), "vertex_count": result.vertices.size(), "triangle_count": result.indices.size() / 3, "rejections": result.rejected, "boxes": result.boxes, "bake_wall_ms": (Time.get_ticks_usec()-started)/1000.0}
	var file := FileAccess.open(OUTPUT.get_basename()+".provenance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(provenance, "\t")+"\n")
	file.close()
	print("Occlusion experiment: %d boxes, %d triangles, generation %s" % [result.boxes.size(), result.indices.size()/3, generation])
	city.free()
	quit()
