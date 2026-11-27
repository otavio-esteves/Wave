shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "street_sky.gdshaderinc"

uniform sampler2D cloud_map : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	vec3 normal = FRONT_FACING ? NORMAL : -NORMAL;
	float facing = clamp(dot(normal, VIEW), 0.0, 1.0);
	float grazing = 1.0 - facing;
	float fresnel = 0.044 + 0.956 * grazing * grazing * grazing * grazing * grazing;
	vec3 ray = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, normal);
	vec3 sky = textureLod(cloud_map, street_cloud_uv(ray), 3.0 + COLOR.r * 2.0).rgb;
	float rim = smoothstep(0.28, 0.49, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	float runs = 0.52 + 0.25 * sin(UV.x * 52.4 + COLOR.r * 14.0) + 0.23 * cos(UV.x * 87.4 - UV.y * 5.1);
	float stains = rim * (0.52 + 0.48 * runs) * (1.0 - UV.y * 0.42);
	float clarity = 0.077 + fresnel * 0.54 + stains * (0.12 + COLOR.r * 0.08);
	ALBEDO = mix(vec3(0.18, 0.29, 0.25), sky * vec3(0.78, 0.97, 0.87), 0.59 + fresnel * 0.30);
	ALPHA = clamp(clarity, 0.0, 0.73);
}
