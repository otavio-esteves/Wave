shader_type spatial;
render_mode unshaded;

uniform sampler2D canopy_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 fold_color : source_color;
uniform vec4 crown_color : source_color;
uniform float texture_strength = 0.4;

void fragment() {
	vec3 tone = mix(fold_color.rgb, crown_color.rgb, COLOR.r);
	vec3 canopy = texture(canopy_map, UV).rgb;
	float canopy_luma = dot(canopy, vec3(0.23, 0.66, 0.11));
	ALBEDO = tone * mix(1.0, 0.67 + canopy_luma * 0.96, texture_strength) * COLOR.g;
}
