shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, alpha_to_coverage;

uniform sampler2D leaf_spray : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool antialias_leaves = false;
uniform float sway = 0.0;

void vertex() {
	if (sway > 0.0) {
		vec3 site = MODEL_MATRIX[3].xyz + VERTEX;
		float gust = sin(TIME * 1.45 + dot(site.xz, vec2(0.29, 0.17)));
		float flutter = sin(TIME * 2.71 + site.y * 3.1 + site.x);
		// Vertex colors describe crown depth. The exposed tips move the most.
		float tip = clamp(COLOR.r * 1.4 - 0.27, 0.0, 1.0);
		VERTEX.xz += vec2(gust + flutter * 0.3, gust * 0.46) * sway * tip;
	}
}

void fragment() {
	vec4 leaf = texture(leaf_spray, UV);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.33;
	ALPHA_ANTIALIASING_EDGE = antialias_leaves ? 0.18 : 0.0;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(leaf_spray, 0));
	// Folded cards share a crown normal on both sides so the folds do not
	// create black stripes on the side of the canopy facing the camera.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 tint = mix(vec3(0.37, 0.57, 0.47), COLOR.rgb, 0.58);
	vec3 leaf_color = leaf.rgb * vec3(0.89, 1.0, 1.22);
	ALBEDO = leaf_color * tint;
	ROUGHNESS = 0.76;
	SPECULAR = 0.32;
	BACKLIGHT = leaf_color * vec3(0.13, 0.21, 0.11);
	EMISSION = leaf_color * tint * 0.06;
}
