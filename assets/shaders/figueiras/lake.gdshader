shader_type spatial;
render_mode specular_schlick_ggx;

uniform float daylight = 1.0;
uniform float wave_time = 0.0;
uniform vec3 sun_direction = vec3(0.47, 0.58, 0.55);
uniform bool stream = false;
varying vec2 shore_position;

void vertex() {
	shore_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = shore_position;
	vec2 flow = stream ? vec2(0.06, -0.84) : vec2(0.036, 0.025);
	p += flow * wave_time;
	float long_warp = sin(dot(p, vec2(0.15, -0.091)));
	float phase_a = dot(p, vec2(2.19, 0.83)) + wave_time * 1.13 + 0.88 * sin(p.y * 0.21) + 2.2 * long_warp;
	float phase_b = dot(p, vec2(-0.77, 1.72)) - wave_time * 0.78 + 0.94 * sin(p.x * 0.35);
	float phase_c = dot(p, vec2(0.25, 0.61)) + wave_time * 0.44;
	float crosswave = dot(p, vec2(-0.39, 0.97)) - wave_time * 0.53 + 1.4 * sin(p.x * 0.17);
	float short_waves = 0.60 + 0.40 * sin(dot(p, vec2(0.27, -0.13)) + 0.70 * long_warp);
	vec3 n = normalize(vec3(0.019 * cos(phase_a) * short_waves + 0.011 * cos(phase_c), 1.0,
		0.022 * cos(phase_b) * short_waves + 0.012 * cos(crosswave)));
	vec3 eye = mat3(INV_VIEW_MATRIX) * VIEW;
	vec3 reflected = reflect(-eye, n);
	float fresnel = pow(1.0 - clamp(dot(eye, n), 0.0, 1.0), 3.4);
	float radial = stream ? abs(UV.x * 2.0 - 1.0) : length(UV * 2.0 - 1.0);
	float shallow = smoothstep(0.61, 0.92, radial);
	float caustic = pow(0.5 + 0.5 * sin(phase_a + 0.83 * sin(phase_b)), 5.0);
	vec3 deep_bed = stream ? vec3(0.109, 0.155, 0.120) : vec3(0.065, 0.159, 0.164);
	vec3 bed = mix(deep_bed, vec3(0.195, 0.257, 0.176), shallow);
	vec3 sky = mix(vec3(0.46, 0.60, 0.66), vec3(0.22, 0.42, 0.61), max(reflected.y, 0.0));
	float glint = pow(max(dot(reflected, sun_direction), 0.0), 128.0);
	ALBEDO = mix(bed + shallow * 0.038 * caustic, sky, fresnel * 0.73);
	NORMAL = normalize(mat3(VIEW_MATRIX) * n);
	ROUGHNESS = 0.39;
	SPECULAR = 0.20;
	EMISSION = daylight * (fresnel * sky * 0.11 + vec3(0.92, 0.71, 0.46) * glint * 0.24);
	if (stream) {
		float seams = pow(0.5 + 0.5 * sin(phase_b + 1.15 * sin(phase_a * 0.54)), 8.0);
		EMISSION += (0.027 + 0.037 * seams) * daylight * vec3(0.47, 0.72, 0.67);
	}
}
