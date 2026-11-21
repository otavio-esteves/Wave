shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, shadows_disabled, specular_schlick_ggx;

#include "hatch_reflections.gdshaderinc"

void fragment() {
	vec3 normal = normalize(NORMAL);
	float facing = clamp(abs(dot(normal, VIEW)), 0.0, 1.0);
	float reflection = pow(1.0 - facing, 2.0);
	vec3 sky = reflected_sky(mat3(INV_VIEW_MATRIX) * reflect(-VIEW, normal), 1.6);
	// Glancing views read the sky. Looking straight in still shows the cabin.
	ALBEDO = vec3(0.16, 0.22, 0.22);
	ROUGHNESS = 0.12;
	METALLIC = 0.29;
	SPECULAR = 0.60;
	EMISSION = sky * (0.28 + 0.69 * reflection);
	ALPHA = mix(0.26, 0.87, reflection);
}
