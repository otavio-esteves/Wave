shader_type spatial;

varying vec2 world_xz;
uniform float wave_time = 0.0;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = world_xz;
	float wave_a = p.x * 9.0 + p.y * 4.5 - wave_time * 2.4;
	float wave_b = p.x * 2.6 - p.y * 11.4 + wave_time * 3.1;
	float wave_c = p.x * 16.8 + p.y * 12.5 + wave_time * 1.1;
	float ripple = 0.53 * sin(wave_a) + 0.31 * sin(wave_b) + 0.16 * sin(wave_c);
	vec3 view_x = mat3(VIEW_MATRIX) * vec3(1.0, 0.0, 0.0);
	vec3 view_z = mat3(VIEW_MATRIX) * vec3(0.0, 0.0, 1.0);
	NORMAL = normalize(NORMAL + view_x * 0.062 * cos(wave_a) + view_z * 0.072 * cos(wave_b));
	float facing = max(dot(VIEW, NORMAL), 0.0);
	ALBEDO = mix(vec3(0.043, 0.135, 0.129), vec3(0.115, 0.265, 0.253), 0.5 + ripple * 0.44) + pow(1.0 - facing, 5.0) * 0.09;
	ROUGHNESS = 0.17;
	METALLIC = 0.24;
	SPECULAR = 0.68;
}
