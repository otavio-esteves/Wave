shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D picture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

vec3 highlights(vec3 value) {
	float luma = dot(value, vec3(0.26, 0.62, 0.12));
	float peak = max(max(value.r, value.g), value.b);
	return value * smoothstep(0.64, 1.03, luma + 0.11 * peak);
}

void fragment() {
	vec2 site = SCREEN_UV;
	vec3 photo = textureLod(picture, site, 0.0).rgb;
	vec3 tight = highlights(textureLod(picture, site, 3.5).rgb);
	vec3 soft = highlights(textureLod(picture, site, 5.5).rgb);
	vec3 roll = tight * 0.096 + soft * 0.072;
	float light = dot(photo, vec3(0.23, 0.67, 0.10));
	vec3 adjusted = photo + roll * vec3(1.10, 0.97, 0.81);
	adjusted += vec3(0.010, 0.015, 0.022) * smoothstep(0.008, 0.14, light)
		* (1.0 - smoothstep(0.15, 0.55, light));
	vec2 frame = (site - 0.5) * vec2(1.67, 1.78);
	float edge = smoothstep(0.60, 1.22, length(frame));
	COLOR = vec4(adjusted * (1.0 - edge * 0.105), 1.0);
}
