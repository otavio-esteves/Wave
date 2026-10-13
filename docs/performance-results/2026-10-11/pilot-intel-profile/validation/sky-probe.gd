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
  sky.process_mode = 2
  var material := ShaderMaterial.new()
  if true:
   material.shader = load("res://assets/shaders/pilot_sky.gdshader")
   material.set_shader_parameter("cloud_noise", load("res://assets/textures/pilot/cloud-noise.png"))
  else:
   var shader := Shader.new()
   shader.code = "shader_type sky; void sky() { COLOR = vec3(0.5, 0.6, 0.7); }"
   material.shader = shader
  sky.sky_material = material
  environment.sky = sky
  var node := WorldEnvironment.new()
  if mode == "env-only":
   node.environment = environment.duplicate()
  elif mode == "sky-only":
   node.environment = environment.duplicate()
   node.environment.sky = environment.sky.duplicate()
  elif mode == "new-sky":
   node.environment = environment.duplicate()
   var copied_sky := Sky.new()
   copied_sky.radiance_size = sky.radiance_size
   copied_sky.process_mode = sky.process_mode
   copied_sky.sky_material = material.duplicate()
   node.environment.sky = copied_sky
  elif mode == "uniform-copy":
   node.environment = environment.duplicate()
   node.environment.sky = environment.sky.duplicate()
   var copied := ShaderMaterial.new()
   copied.shader = material.shader
   copied.set_shader_parameter("cloud_noise", material.get_shader_parameter("cloud_noise"))
   node.environment.sky.sky_material = copied
  elif mode == "selective":
   node.environment = environment.duplicate()
   node.environment.sky = environment.sky.duplicate()
   node.environment.sky.sky_material = material.duplicate()
  else:
   node.environment = environment.duplicate(true) if "duplicate" in mode else environment
  print("cloud texture shared: ",node.environment.sky.sky_material.get_shader_parameter("cloud_noise") == material.get_shader_parameter("cloud_noise"))
  world.add_child(node)
  var object := MeshInstance3D.new()
  object.mesh = BoxMesh.new()
  object.position.z = -5
  object.material_override = StandardMaterial3D.new()
  world.add_child(object)
 for i in 90:
  if "animated" in mode:
   world.get_child(1).environment.sky.sky_material.set_shader_parameter("cloud_time", float(i) * 0.1)
  await process_frame
 _close.call_deferred()
func _close() -> void:
 world.queue_free()
 world = null
 for i in 10:
  await process_frame
 quit()
