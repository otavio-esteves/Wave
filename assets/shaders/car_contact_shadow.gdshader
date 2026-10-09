shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float shade = 1.0 - smoothstep(0.12, 1.0, dot(p, p));
	ALBEDO = vec3(0.025, 0.035, 0.04);
	ALPHA = shade * 0.28;
}
