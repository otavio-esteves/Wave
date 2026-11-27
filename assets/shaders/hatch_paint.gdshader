shader_type spatial;
render_mode specular_schlick_ggx;

#include "hatch_reflections.gdshaderinc"

uniform sampler2D paint_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D paint_normal : hint_normal, filter_linear_mipmap, repeat_enable;
instance uniform bool road_finish : instance_index(8) = false;
instance uniform float body_water : instance_index(9) = 0.0;
instance uniform float body_shadow : instance_index(11) = 0.0;
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
	if (road_finish) {
		float sill = 1.0 - smoothstep(-0.31, 0.27, body_point.y);
		float wheel_mist = smoothstep(0.18, 0.93, abs(body_point.z) / 1.7);
		float dirt = sill * (0.09 + 0.15 * wheel_mist) * (0.87 + grain * 0.22);
		vec3 enamel = COLOR.rgb * grain * (0.89 - 0.12 * glaze);
		vec3 road_dirt = mix(vec3(0.37, 0.30, 0.24), vec3(0.22, 0.19, 0.16), body_water);
		float fresnel = 0.044 + 0.956 * pow(1.0 - facing, 5.0);
		ALBEDO = mix(enamel, road_dirt, dirt);
		ALBEDO *= mix(vec3(1.0), vec3(0.66, 0.76, 0.91), body_shadow * 0.74);
		ROUGHNESS = mix(0.245 + 0.32 * dirt, 0.175 + 0.22 * dirt, body_water);
		METALLIC = 0.0;
		SPECULAR = 0.54;
		EMISSION = sky * fresnel * (0.62 + body_water * 0.17) * (1.0 - dirt * 0.86);
	}
}
