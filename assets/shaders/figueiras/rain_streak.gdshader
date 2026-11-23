shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix, fog_disabled;

uniform float intensity = 0.0;

void fragment() {
	float body = smoothstep(0.0, 0.40, UV.x) * (1.0 - smoothstep(0.60, 1.0, UV.x));
	float tail = sin(UV.y * 3.14159) * mix(0.44, 1.0, UV.y);
	float distance_fade = smoothstep(0.7, 3.5, length(VERTEX)) * (1.0 - smoothstep(18.0, 32.0, length(VERTEX)));
	ALBEDO = vec3(0.67, 0.79, 0.84);
	ALPHA = body * tail * distance_fade * intensity * 0.78;
}
