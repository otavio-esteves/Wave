shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

void fragment() {
	vec2 radius = (UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.04, 0.035, 0.03);
	ALPHA = (1.0 - smoothstep(0.25, 1.0, dot(radius, radius))) * 0.42;
}
