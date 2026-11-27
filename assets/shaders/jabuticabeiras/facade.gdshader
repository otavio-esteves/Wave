shader_type spatial;
render_mode diffuse_burley;

#include "street_sky.gdshaderinc"

uniform sampler2D elevation : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D fine_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D reflected_sky : source_color, filter_linear_mipmap, repeat_disable;
uniform bool material_detail = true;

void fragment() {
	vec3 plate = texture(elevation, UV).rgb;
	float wall_height = UV2.y;
	float splash = (1.0 - smoothstep(0.08, 0.85 + 0.12 * sin(UV2.x * 18.0), wall_height));
	ALBEDO = plate * COLOR.rgb * mix(vec3(1.0), vec3(0.64, 0.67, 0.63), splash * 0.36);
	ROUGHNESS = 0.91;
	SPECULAR = 0.24;
	AO = clamp(COLOR.r, 0.50, 1.0);
	if (COLOR.a > 0.5) {
		float view_angle = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float fresnel = pow(1.0 - view_angle, 3.0);
		vec3 reflection = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
		vec3 surroundings = mix(vec3(0.25, 0.28, 0.26), vec3(0.49, 0.63, 0.72),
			smoothstep(-0.10, 0.45, reflection.y));
		if (material_detail) {
			vec3 sky = textureLod(reflected_sky, street_cloud_uv(reflection), 4.0).rgb;
			float skyline = 0.18 + 0.06 * sin(reflection.x * 13.0 + reflection.z * 7.0);
			surroundings = mix(surroundings, sky * vec3(0.73, 0.84, 0.96),
				smoothstep(skyline - 0.11, skyline + 0.05, reflection.y) * 0.80);
		}
		float display_window = step(0.8, COLOR.a);
		ALBEDO = mix(ALBEDO, surroundings, 0.045 + fresnel * 0.49);
		ROUGHNESS = mix(0.33, 0.21, display_window);
		SPECULAR = 0.36;
		EMISSION = plate * vec3(1.0, 0.89, 0.68) * (0.045 + 0.28 * display_window) * (1.0 - 0.56 * fresnel);
	} else if (material_detail) {
		NORMAL_MAP = texture(fine_normal, UV2 * 1.45).rgb;
		NORMAL_MAP_DEPTH = 0.38;
	}
}
