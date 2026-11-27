shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, alpha_to_coverage;

#include "street_light.gdshaderinc"

uniform sampler2D leaf_spray : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool antialias_leaves = false;
uniform bool flowers = false;
uniform bool distant_grove = false;
uniform vec4 flower_tint : source_color = vec4(1.0);
uniform float sway = 0.0;
varying vec2 crown_lighting;

void vertex() {
	if (sway > 0.0 && !distant_grove) {
		vec3 site = MODEL_MATRIX[3].xyz + VERTEX;
		float gust = sin(TIME * 1.45 + dot(site.xz, vec2(0.29, 0.17)));
		float flutter = sin(TIME * 2.71 + site.y * 3.1 + site.x);
		// Vertex colors describe crown depth. The exposed tips move the most.
		float tip = clamp(COLOR.r * 1.4 - 0.27, 0.0, 1.0);
		VERTEX.xz += vec2(gust + flutter * 0.3, gust * 0.46) * sway * tip;
	}
	crown_lighting = vec2(0.59, 0.0);
	if (has_street_light && !distant_grove) {
		vec4 field = street_light_at_nearest_slice((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
		crown_lighting = vec2(max(field.r, 0.38), field.g);
	}
}

void fragment() {
	vec4 leaf = texture(leaf_spray, UV);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = flowers ? 0.38 : 0.33;
	ALPHA_ANTIALIASING_EDGE = antialias_leaves ? 0.18 : 0.0;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(leaf_spray, 0));
	// Folded cards share a crown normal on both sides so the folds do not
	// create black stripes on the side of the canopy facing the camera.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 tint = mix(vec3(0.51, 0.61, 0.55), COLOR.rgb, 0.52);
	float luma = dot(leaf.rgb, vec3(0.21, 0.72, 0.07));
	vec3 leaf_color = mix(vec3(luma), leaf.rgb, 0.73) * vec3(1.02, 0.98, 1.02);
	if (flowers) {
		tint = flower_tint.rgb * mix(0.76, 1.0, COLOR.g);
		leaf_color = leaf.rgb;
	}
	ALBEDO = leaf_color * tint * mix(0.83, 1.04, crown_lighting.x);
	ROUGHNESS = 0.78;
	SPECULAR = 0.27;
	BACKLIGHT = leaf_color * vec3(0.24, 0.26, 0.15);
	EMISSION = leaf_color * tint * (0.04 + 0.053 * COLOR.g);
	EMISSION += leaf_color * (vec3(0.022, 0.046, 0.071) * crown_lighting.x
		+ vec3(0.58, 0.37, 0.13) * crown_lighting.y * 0.46);
	if (distant_grove) {
		EMISSION += vec3(0.031, 0.049, 0.050) * (0.62 + luma * 0.38 + COLOR.g * 0.26);
	}
}
