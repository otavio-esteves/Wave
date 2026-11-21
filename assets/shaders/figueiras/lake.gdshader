shader_type spatial;
render_mode specular_schlick_ggx;

uniform float daylight = 1.0;
uniform float wave_time = 0.0;
uniform vec3 sun_direction = vec3(0.47, 0.58, 0.55);
varying vec2 shore_position;

void vertex() {
	shore_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = shore_position;
	float phase_a = dot(p, vec2(2.19, 0.83)) + wave_time * 1.13 + 0.8 * sin(p.y * 0.21);
	float phase_b = dot(p, vec2(-0.77, 1.72)) - wave_time * 0.78 + 0.6 * sin(p.x * 0.35);
	float phase_c = dot(p, vec2(0.25, 0.61)) + wave_time * 0.44;
	float crosswave = dot(p, vec2(-0.39, 0.97)) - wave_time * 0.53 + 1.4 * sin(p.x * 0.17);
	vec3 n = normalize(vec3(0.021 * cos(phase_a) + 0.014 * cos(phase_c), 1.0, 0.018 * cos(phase_b) + 0.013 * cos(crosswave)));
	vec3 eye = mat3(INV_VIEW_MATRIX) * VIEW;
	vec3 reflected = reflect(-eye, n);
	float fresnel = pow(1.0 - clamp(dot(eye, n), 0.0, 1.0), 3.4);
	float radial = length(UV * 2.0 - 1.0);
	float shallow = smoothstep(0.61, 0.92, radial);
	float caustic = pow(0.5 + 0.5 * sin(phase_a + 0.83 * sin(phase_b)), 5.0);
	vec3 bed = mix(vec3(0.065, 0.159, 0.164), vec3(0.195, 0.257, 0.176), shallow);
	vec3 sky = mix(vec3(0.46, 0.60, 0.66), vec3(0.22, 0.42, 0.61), max(reflected.y, 0.0));
	float glint = pow(max(dot(reflected, sun_direction), 0.0), 128.0);
	ALBEDO = mix(bed + shallow * 0.038 * caustic, sky, fresnel * 0.73);
	NORMAL = normalize(mat3(VIEW_MATRIX) * n);
	ROUGHNESS = 0.39;
	SPECULAR = 0.20;
	EMISSION = daylight * (fresnel * sky * 0.11 + vec3(0.92, 0.71, 0.46) * glint * 0.31);
}
