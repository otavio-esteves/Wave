shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_back;

uniform sampler2D rearview : source_color, filter_linear, repeat_disable;

void fragment() {
	vec2 p = clamp(vec2(1.0 - UV.x, UV.y), vec2(0.0), vec2(1.0));
	vec3 reflection = texture(rearview, p).rgb;
	float vignette = 1.0 - 0.26 * pow(abs(UV.x - 0.5) * 2.0, 7.0);
	ALBEDO = reflection * vec3(0.74, 0.84, 0.88) * vignette;
}
