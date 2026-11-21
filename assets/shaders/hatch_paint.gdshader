shader_type spatial;
render_mode specular_schlick_ggx;

#include "hatch_reflections.gdshaderinc"

uniform sampler2D paint_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D paint_normal : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 body_point;

void vertex() {
	body_point = VERTEX;
}

void fragment() {
	vec2 grain_uv = vec2(body_point.x + 0.71 * body_point.y, body_point.z + 0.42 * body_point.y) * 7.0;
	float grain = texture(paint_albedo, grain_uv).r;
	vec2 orange_peel = texture(paint_normal, grain_uv).xy - 0.5;
	vec3 normal = normalize(NORMAL);
	float facing = clamp(dot(normal, VIEW), 0.0, 1.0);
	float glaze = pow(1.0 - facing, 3.0);
	vec3 ray = reflect(-VIEW, normalize(normal + vec3(orange_peel * 0.024, 0.0)));
	vec3 sky = reflected_sky(mat3(INV_VIEW_MATRIX) * ray, 3.0);
	ALBEDO = COLOR.rgb * grain * (0.83 - 0.17 * glaze);
	ROUGHNESS = 0.24;
	METALLIC = 0.06;
	SPECULAR = 0.62;
	EMISSION = sky * (0.055 + 0.27 * glaze);
}
