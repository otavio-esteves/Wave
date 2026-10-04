extends CPUParticles3D

@onready var car: PlayerCar = get_parent()

func _ready() -> void:
	position = Vector3(0, -0.12, 1.2)
	amount = 36
	lifetime = 1.3
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(0.7, 0.03, 0.2)
	direction = Vector3(0, 0.2, 1)
	spread = 35
	initial_velocity_min = 0.6
	initial_velocity_max = 1.8
	gravity = Vector3(0, 0.35, 0)
	scale_amount_min = 0.35
	scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0,Color(0.70,0.61,0.47,0.22))
	ramp.set_color(1,Color(0.70,0.61,0.47,0))
	color_ramp = ramp
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	texture.gradient = Gradient.new()
	texture.gradient.set_color(0,Color.WHITE)
	texture.gradient.set_color(1,Color(1,1,1,0))
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = false
	car.car_reset.connect(func() -> void: emitting = false; restart())

func _physics_process(_delta: float) -> void:
	emitting = car.is_on_floor() and car.surface_name=="cascalho" and car.get_speed_kmh()>18
