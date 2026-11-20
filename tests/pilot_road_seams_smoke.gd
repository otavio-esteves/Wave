extends SceneTree

const Baker = preload("res://scripts/city/pilot_road_seam_baker.gd")
const Runtime = preload("res://scripts/city/pilot_road_seams.gd")
const Layout = preload("res://scripts/city/pilot_city_layout.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var road := _quad(0, 2)
	var sidewalk := _quad(2.16, 3.16)
	var baker := Baker.new()
	baker.add_road(road)
	var seam := baker.seal(sidewalk)
	var ray := Vector3(2, 100, 2.08)
	_check(_hit(road.get_faces(), ray) == null and _hit(sidewalk.get_faces(), ray) == null, "fixture has a genuine sixteen centimetre gap")
	_check(not seam.is_empty() and _hit(seam, ray) != null, "offline weld covers the gap without moving either source mesh")
	_check(baker.seal(_quad(2.0, 3.0)).is_empty(), "touching surfaces produce no unnecessary seam")
	_check(baker.seal(_quad(4.0, 5.0)).is_empty(), "a garden beyond the bounded seam distance is preserved")
	var original_road := road.get_faces()
	var original_sidewalk := sidewalk.get_faces()
	road.take_over_path("user://road-seam-fixture/road.res")
	sidewalk.take_over_path("user://road-seam-fixture/sidewalk.res")
	var city := Node3D.new()
	city.set_meta("generation_directory", "fixture-generation")
	var asphalt := StandardMaterial3D.new()
	var source_road := _node(city, road, "Streets", asphalt)
	_node(city, sidewalk, "Sidewalks", StandardMaterial3D.new())
	var cache_root := Node3D.new()
	cache_root.set_meta("source_generation", "fixture-generation")
	cache_root.set_meta("source_geometry", {road.resource_path: {"vertices": road.surface_get_array_len(0)}, sidewalk.resource_path: {"vertices": sidewalk.surface_get_array_len(0)}})
	var patch := _node(cache_root, Baker.mesh_from_faces(seam), "RoadSeam", null)
	patch.owner = cache_root
	var packed := PackedScene.new()
	packed.pack(cache_root)
	cache_root.free()
	var result := Runtime.prepare(city, packed)
	_check(result.applied and city.get_child_count() == 3 and city.get_child(2).get_child(0).material_override == asphalt, "runtime shares the authored street material and installs a cached patch")
	_check(city.get_child(2).get_child(0).get_meta("surface_kind") == "RoadSeam", "visual-only seam keeps its cosmetic classification without inventing physical street support")
	Runtime.prepare(city, packed)
	_check(city.get_child_count() == 3, "installation is idempotent")
	_check(road.get_faces() == original_road and sidewalk.get_faces() == original_sidewalk and source_road.mesh == road, "authored visual and collision support geometry stays intact")
	city.free()
	var stale := Node3D.new()
	stale.set_meta("generation_directory", "different-generation")
	_check(not Runtime.prepare(stale, packed).applied and stale.get_child_count() == 0, "a different immutable generation skips stale patches")
	stale.set_meta("generation_directory", "fixture-generation")
	_node(stale, _quad(0, 2), "Streets", asphalt)
	_check(not Runtime.prepare(stale, packed).applied and stale.get_child_count() == 1, "a different geometry resource skips the cache")
	stale.free()
	_actual_gap()
	print("Pilot road seams: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _actual_gap() -> void:
	# Source proof from driving review, source generation is immutable.
	var cached := load(Runtime.CACHE_PATH) as PackedScene
	var patches := cached.instantiate()
	var base: String = patches.get_meta("source_generation") + "/city_geometry/"
	var source := PackedVector3Array()
	for name in ["Streets_-7_2", "Streets_-7_3", "Sidewalks_-7_3"]:
		var mesh := load(base + name + ".res") as Mesh
		source.append_array(mesh.get_faces())
	var correction := PackedVector3Array()
	for node in patches.get_children():
		if str(node.name).begins_with("RoadSeam_-7_2") or str(node.name).begins_with("RoadSeam_-7_3"):
			correction.append_array(node.mesh.get_faces())
	for point in [Vector3(-880.5077, 50, 385.8785), Vector3(-880.68, 50, 386.1115), Vector3(-880.788, 50, 386.3054), Vector3(-880.8893, 50, 386.4179)]:
		_check(_hit(source, point) == null and _hit(correction, point) != null, "saved driving gap at %s is covered by the cached seam" % point)
	patches.free()


func _quad(minimum: float, maximum: float) -> ArrayMesh:
	var points: Array[Vector3] = []
	for flat in [Vector2(0, minimum), Vector2(4, minimum), Vector2(0, maximum), Vector2(4, maximum)]:
		points.append(Vector3(flat.x, Layout.height_at(flat.x, flat.y) + Layout.ROAD_LIFT, flat.y))
	return Baker.mesh_from_faces(PackedVector3Array([points[0], points[2], points[1], points[1], points[2], points[3]]))


func _node(parent: Node3D, mesh: Mesh, kind: String, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.set_meta("surface_kind", kind)
	parent.add_child(node)
	return node


func _hit(faces: PackedVector3Array, origin: Vector3) -> Variant:
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN, faces[index], faces[index + 1], faces[index + 2])
		if hit != null:
			return hit
	return null


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
