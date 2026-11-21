shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float shade = 1.0 - smoothstep(0.12, 1.0, dot(p, p));
	ALBEDO = vec3(0.0);
	ALPHA = shade * opacity;
}
