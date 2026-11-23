shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform float strength = 1.0;

void fragment() {
	float rim = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float edges = rim * rim;
	ALBEDO = mix(vec3(0.03, 0.47, 0.60), vec3(0.65, 1.0, 0.92), edges);
	ALPHA = (0.24 + edges * 0.31) * strength;
}
