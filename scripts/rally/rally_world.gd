extends "res://scripts/driving_world.gd"

const Layout = preload("res://scripts/rally/rally_layout.gd")

func _ready() -> void:
	var car: PlayerCar = $PlayerCar
	var points: PackedVector3Array = $RallyMap.get_meta("route")
	car.global_position = points[6] + Vector3.UP * 0.55
	var forward := Layout.tangent(points,6)
	car.rotation.y = atan2(-forward.x,-forward.z)
	car.spawn_transform = car.global_transform
	var dust := CPUParticles3D.new()
	dust.name = "GravelDust"
	dust.set_script(preload("res://scripts/rally/gravel_dust.gd"))
	car.add_child(dust)
	super._ready()
	var timing := Node.new()
	timing.name = "StageTiming"
	timing.set_script(preload("res://scripts/rally/stage_timing.gd"))
	add_child(timing)


func apply_graphics() -> void:
	super.apply_graphics()
	var environment: Environment = $WorldEnvironment.environment
	var quality: bool = get_node("/root/WaveSettings").graphics["post_effects"]
	var cinematic: bool = get_node("/root/WaveSettings").graphics["cinematic_effects"]
	var advanced := RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.ssao_enabled = quality
	environment.ssao_radius = 0.65
	environment.ssao_intensity = 1.2
	environment.ssao_power = 1.2
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.1
	environment.ssil_enabled = advanced and cinematic
	environment.ssil_intensity = 0.45
	environment.volumetric_fog_enabled = advanced and cinematic
	environment.volumetric_fog_density = 0.0015
	environment.volumetric_fog_length = 180.0
	environment.volumetric_fog_ambient_inject = 0.35
	environment.volumetric_fog_sky_affect = 0.2
	environment.glow_enabled = quality
	environment.glow_intensity = 0.25
	environment.glow_hdr_threshold = 1.6
