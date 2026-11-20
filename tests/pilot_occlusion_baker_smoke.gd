extends SceneTree

const Baker = preload("res://scripts/tools/pilot_occlusion_baker.gd")
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var city := Node3D.new()
	var box := _box(city)
	box.transform = Transform3D(Basis(Vector3.UP,0.7).scaled(Vector3(1.3,2.1,0.8)),Vector3(30,7,-20))
	box.multimesh.instance_transforms[0] = Transform3D(Basis(Vector3.UP,-0.2).scaled(Vector3(1.1,0.9,1.4)),Vector3(2,1,-3))
	var actual: Transform3D = box.transform * box.multimesh.instance_transforms[0]
	var result := Baker.build(city)
	_check(result.boxes.size()==1 and result.vertices.size()==8 and result.indices.size()==36, "one opaque closed volume yields an independent eight-vertex twelve-triangle cuboid")
	var inside := true
	for point: Vector3 in result.vertices:
		var local: Vector3 = actual.affine_inverse()*point
		inside = inside and absf(local.x)<4 and absf(local.y)<2 and absf(local.z)<4
	_check(inside, "rotated nonuniform source transform remains exact and all occluder corners lie strictly inside source box")
	box.multimesh.mesh = QuadMesh.new()
	_check(Baker.build(city).boxes.is_empty(), "open wall planes cannot become closed occluders")
	box.multimesh.mesh = BoxMesh.new()
	box.multimesh.mesh.size=Vector3(8,4,0.3)
	_check(Baker.build(city).boxes.is_empty(), "thin walls cannot fill large open areas")
	box.multimesh.mesh.size=Vector3(8,4,8)
	box.hide()
	_check(Baker.build(city).boxes.is_empty(), "hidden geometry cannot occlude")
	box.show()
	city.hide()
	_check(Baker.build(city).boxes.is_empty(), "hidden ancestors suppress their occluder descendants")
	city.show()
	box.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_check(Baker.build(city).boxes.is_empty(), "alpha materials cannot occlude")
	box.material_override.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	box.material_override.resource_name="white"
	_check(Baker.build(city).boxes.is_empty(), "opaque unknown materials outside the persistent building HLOD classification cannot occlude")
	box.material_override.resource_name="stone"
	box.material_override.next_pass=StandardMaterial3D.new()
	_check(Baker.build(city).boxes.is_empty(), "multipass materials cannot occlude")
	box.material_override=ShaderMaterial.new()
	_check(Baker.build(city).boxes.is_empty(), "custom shader materials cannot occlude")
	box.free()
	var left:=_box(city)
	left.position.x=-20
	var right:=_box(city)
	right.position.x=20
	result=Baker.build(city)
	var gap_clear:=true
	for point:Vector3 in result.vertices:
		gap_clear=gap_clear and absf(point.x)>15.0
	_check(result.boxes.size()==2 and gap_clear, "separate source boxes never become a merged AABB across a courtyard")
	city.free()
	print("Pilot occlusion baker: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)


func _box(parent:Node3D)->MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new()
	node.multimesh=BakedMultiMesh.new()
	node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var placements: Array[Transform3D] = [Transform3D.IDENTITY]
	node.multimesh.set_instances(placements)
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(8,4,8)
	node.multimesh.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.resource_name="stone"
	node.material_override=material
	parent.add_child(node)
	return node


func _check(value:bool,message:String)->void:
	checks+=1
	if value:
		print("PASS: "+message)
	else:
		failures+=1
		push_error(message)
