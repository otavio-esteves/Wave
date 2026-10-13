extends SceneTree
var world: Node3D
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 var mode := OS.get_cmdline_user_args()[0]
 world = Node3D.new()
 root.add_child(world)
 var camera := Camera3D.new()
 world.add_child(camera)
 if mode != "blank":
  var environment := Environment.new()
  environment.background_mode = Environment.BG_SKY
  var sky := Sky.new()
  sky.radiance_size = 1
  sky.process_mode = int(mode) if mode != "complex" else 2
  var material := ShaderMaterial.new()
  if mode == "complex":
   material.shader = load("res://assets/shaders/pilot_sky.gdshader")
   material.set_shader_parameter("cloud_noise", load("res://assets/textures/pilot/cloud-noise.png"))
  else:
   var shader := Shader.new()
   shader.code = "shader_type sky; void sky() { COLOR = vec3(0.5, 0.6, 0.7); }"
   material.shader = shader
  sky.sky_material = material
  environment.sky = sky
  var node := WorldEnvironment.new()
  node.environment = environment
  world.add_child(node)
  var object := MeshInstance3D.new()
  object.mesh = BoxMesh.new()
  object.position.z = -5
  object.material_override = StandardMaterial3D.new()
  world.add_child(object)
 for i in 45:
  await process_frame
 _close.call_deferred()
func _close() -> void:
 world.queue_free()
 world = null
 for i in 10:
  await process_frame
 quit()
