shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform sampler2D foliage_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 albedo_modulate : source_color = vec4(1.0);
uniform float alpha_cutoff = 0.35;
varying flat vec2 atlas_cell;

void vertex() {
	float tile = INSTANCE_CUSTOM.r * 2.0 + UV2.x;
	atlas_cell = vec2(mod(tile, 8.0), floor(tile / 8.0));
	// Canopy cards describe a volume of leaves, rather than a flat wall.
	// Upward-biased normals retain soft day/night response from native lights.
	NORMAL = normalize(vec3(NORMAL.x * 0.35, 0.94, NORMAL.z * 0.35));
}

void fragment() {
	vec4 sample_colour = texture(foliage_atlas, (atlas_cell + UV) / vec2(8.0, 4.0));
	ALBEDO = sample_colour.rgb * albedo_modulate.rgb * COLOR.rgb;
	ROUGHNESS = 0.95;
	ALPHA = sample_colour.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
}
