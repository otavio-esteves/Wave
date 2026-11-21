shader_type spatial;

uniform sampler2D interior : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);
uniform float light_inside = 0.0;

void fragment() {
	vec2 perspective = vec2(dot(VIEW, TANGENT), dot(VIEW, BINORMAL));
	vec2 pane = clamp(UV + perspective * 0.08, vec2(0.025), vec2(0.975));
	vec3 room = texture(interior, crop.xy + pane * crop.zw).rgb;
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.8);
	float jamb = smoothstep(0.0, 0.14, min(UV.x, 1.0 - UV.x));
	vec3 reflection = mix(vec3(0.105, 0.148, 0.145), vec3(0.27, 0.34, 0.37), 1.0 - UV.y);
	float sill = smoothstep(0.0, 0.16, 1.0 - UV.y);
	ALBEDO = mix(room * mix(0.54, 0.89, jamb * sill), reflection, 0.17 + fresnel * 0.72);
	EMISSION = room * (0.11 + 0.64 * light_inside) * (1.0 - fresnel * 0.72);
	ROUGHNESS = 0.24;
	SPECULAR = 0.62;
}
