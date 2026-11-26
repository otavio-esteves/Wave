shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D elevation : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D fine_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool material_detail = true;

void fragment() {
	vec3 plate = texture(elevation, UV).rgb;
	ALBEDO = plate * COLOR.rgb;
	ROUGHNESS = 0.91;
	SPECULAR = 0.24;
	AO = clamp(COLOR.r, 0.50, 1.0);
	if (COLOR.a > 0.5) {
		float view_angle = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float fresnel = pow(1.0 - view_angle, 3.0);
		vec3 reflection = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
		vec3 surroundings = mix(vec3(0.25, 0.28, 0.26), vec3(0.49, 0.63, 0.72),
			smoothstep(-0.10, 0.45, reflection.y));
		float display_window = step(0.8, COLOR.a);
		ALBEDO = mix(ALBEDO, surroundings, 0.045 + fresnel * 0.49);
		ROUGHNESS = mix(0.28, 0.19, display_window);
		SPECULAR = 0.36;
		EMISSION = plate * vec3(1.0, 0.89, 0.68) * (0.045 + 0.28 * display_window) * (1.0 - 0.56 * fresnel);
	} else if (material_detail) {
		NORMAL_MAP = texture(fine_normal, UV2 * 1.45).rgb;
		NORMAL_MAP_DEPTH = 0.38;
	}
}
