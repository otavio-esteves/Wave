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
	float stains = texture(color_texture, wall * vec2(0.18, 0.079)).r;
	float runoff = smoothstep(0.42, 0.79, stains);
	float rising_damp = 1.0 - smoothstep(0.0, 0.31 + stains * 0.09, wall_height);
	float tint = 0.83 + 0.21 * runoff - 0.25 * rising_damp;
	ALBEDO = wall_color.rgb * base * tint;
	ROUGHNESS = 0.85 + rising_damp * 0.09;
	SPECULAR = 0.24;
	if (material_detail) {
		NORMAL_MAP = texture(normal_texture, UV * tiling).rgb;
		NORMAL_MAP_DEPTH = 0.38;
	}
}
