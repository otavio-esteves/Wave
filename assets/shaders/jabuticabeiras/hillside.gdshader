shader_type spatial;
render_mode unshaded;

uniform sampler2D canopy_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 fold_color : source_color;
uniform vec4 crown_color : source_color;
uniform float texture_strength = 0.4;

void fragment() {
	vec3 tone = mix(fold_color.rgb, crown_color.rgb, COLOR.r * 0.46 + COLOR.b * 0.32);
	vec3 canopy = texture(canopy_map, UV).rgb;
	vec3 groves = texture(canopy_map, UV * 0.31 + vec2(0.19, 0.43)).rgb;
	float canopy_luma = dot(canopy, vec3(0.23, 0.66, 0.11));
	float grove_luma = dot(groves, vec3(0.28, 0.61, 0.11));
	vec3 meadow = tone * vec3(1.18, 1.08, 0.80);
	float clearing = smoothstep(0.45, 0.74, grove_luma + COLOR.b * 0.24);
	tone = mix(tone, meadow, clearing * texture_strength);
	ALBEDO = tone * mix(1.0, 0.48 + canopy_luma * 0.98 + grove_luma * 0.22, texture_strength) * COLOR.g;
}
