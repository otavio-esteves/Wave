shader_type spatial;

uniform sampler2D color_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 wall_color : source_color = vec4(1.0);
uniform vec2 tiling = vec2(3.0, 2.0);
uniform bool material_detail = false;
varying vec3 wall_point;
varying float wall_height;

void vertex() {
	wall_height = VERTEX.y + 0.5;
	wall_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(color_texture, UV * tiling).rgb;
	vec2 wall = vec2(wall_point.x + wall_point.z, wall_point.y);
	float stains = material_detail ? texture(color_texture, wall * vec2(0.21, 0.065)).r : 0.54 + 0.16 * sin(wall.x * 0.47 + wall.y * 0.17);
	float runoff = smoothstep(0.39, 0.79, stains);
	float rising_damp = 1.0 - smoothstep(0.0, 0.31 + stains * 0.09, wall_height);
	float under_eave = smoothstep(0.93, 1.0, wall_height) * 0.16;
	float tint = 0.81 + 0.24 * runoff - 0.23 * rising_damp - under_eave;
	ALBEDO = wall_color.rgb * base * tint * mix(vec3(1.0), vec3(0.82, 0.94, 0.86), rising_damp * 0.38);
	ROUGHNESS = 0.85 + rising_damp * 0.09;
	SPECULAR = 0.24;
	if (material_detail) {
		NORMAL_MAP = texture(normal_texture, UV * tiling).rgb;
		NORMAL_MAP_DEPTH = 0.38;
	}
}
