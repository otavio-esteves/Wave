shader_type spatial;
render_mode unshaded, depth_draw_never;

#include "street_sky.gdshaderinc"
#include "street_light.gdshaderinc"

uniform sampler2D sky_panorama : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 glass_site;

void vertex() {
	glass_site = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float grazing = 1.0 - facing;
	vec3 ray = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
	vec3 sky = textureLod(sky_panorama, street_cloud_uv(ray), 3.0).rgb;
	float skyline = 0.16 + 0.046 * sin(ray.x * 15.0 + 1.1) + 0.027 * cos(ray.z * 22.0);
	float open_sky = smoothstep(skyline - 0.10, skyline + 0.04, ray.y);
	vec3 reflection = mix(vec3(0.18, 0.23, 0.23), sky * vec3(0.80, 0.91, 1.0), open_sky);
	if (has_street_light) {
		vec4 field;
		vec3 bent;
		sample_street_light(glass_site, field, bent);
		reflection *= mix(0.75, 1.0, field.r);
		reflection += field.g * vec3(0.24, 0.14, 0.065);
	}
	float sill = 1.0 - smoothstep(0.66, 1.06, UV.y);
	ALBEDO = reflection;
	ALPHA = 0.08 + (0.12 + 0.53 * grazing * grazing) * (0.65 + sill * 0.35);
}
