shader_type spatial;

uniform sampler2D interior : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 crop = vec2(0.0, 1.0);
uniform float light_inside = 0.0;

void fragment() {
	vec2 perspective = vec2(dot(VIEW, TANGENT), dot(VIEW, BINORMAL));
	vec2 pane = clamp(UV + perspective * 0.08, vec2(0.025), vec2(0.975));
	pane.x = mix(crop.x, crop.y, pane.x);
	vec3 room = texture(interior, pane).rgb;
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.8);
	float jamb = smoothstep(0.0, 0.14, min(UV.x, 1.0 - UV.x));
	vec3 reflection = mix(vec3(0.105, 0.148, 0.145), vec3(0.27, 0.34, 0.37), 1.0 - UV.y);
	ALBEDO = mix(room * mix(0.59, 0.85, jamb), reflection, 0.13 + fresnel * 0.78);
	EMISSION = room * (0.16 + 0.55 * light_inside) * (1.0 - fresnel * 0.75);
	ROUGHNESS = 0.24;
	SPECULAR = 0.62;
}
