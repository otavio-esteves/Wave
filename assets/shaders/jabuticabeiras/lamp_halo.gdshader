shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

varying float distance_to_lamp;

void vertex() {
	vec3 center = (VIEW_MATRIX * MODEL_MATRIX[3]).xyz;
	float span = length(MODEL_MATRIX[0].xyz);
	POSITION = PROJECTION_MATRIX * vec4(center + vec3(VERTEX.xy * span, 0.0), 1.0);
	distance_to_lamp = length(center);
}

void fragment() {
	vec2 ray = (UV - 0.5) * 2.0;
	float radius = length(ray);
	float glow = exp(-radius * radius * 7.5) * (1.0 - smoothstep(0.74, 1.0, radius));
	float fade = smoothstep(2.0, 5.0, distance_to_lamp) * (1.0 - smoothstep(55.0, 99.0, distance_to_lamp));
	ALBEDO = vec3(1.0, 0.57, 0.21);
	ALPHA = glow * fade * 0.39;
}
