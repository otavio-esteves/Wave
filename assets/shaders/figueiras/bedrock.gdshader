shader_type spatial;
render_mode cull_disabled;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 position_world;
varying vec3 normal_world;

void vertex() {
	position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 weights = pow(abs(normalize(normal_world)), vec3(5.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 p = position_world * 0.27;
	vec3 stone = texture(rock_albedo, p.zy).rgb * weights.x;
	stone += texture(rock_albedo, p.xz).rgb * weights.y;
	stone += texture(rock_albedo, p.xy).rgb * weights.z;
	float strata = sin(dot(position_world, vec3(-0.17, 0.51, 0.12)));
	float weathering = smoothstep(-0.32, 0.86, strata) * 0.24;
	ALBEDO = stone * mix(vec3(0.64, 0.68, 0.70), vec3(0.94, 0.84, 0.63), weathering + 0.20);
	ROUGHNESS = 0.91;
	SPECULAR = 0.13;
}
