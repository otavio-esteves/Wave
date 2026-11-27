shader_type spatial;
render_mode diffuse_burley;

#include "street_sky.gdshaderinc"
#include "street_light.gdshaderinc"

uniform sampler2D finishes : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D weathering : filter_linear_mipmap, repeat_enable;
uniform sampler2D street_sky : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 atlas_tile;
uniform bool material_detail = true;
uniform bool use_baked_shadow = false;
uniform bool has_weathering = false;
uniform bool vertex_light_bake = false;

varying vec3 site;
varying vec4 vertex_field;

void vertex() {
	site = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_field = vec4(0.91, 0.0, 0.21, 1.0);
	if (has_street_light && vertex_light_bake) {
		vec3 normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
		vertex_field = street_light_at_nearest_slice(site + normal * 0.42);
	}
}

void fragment() {
	float kind = UV2.x;
	vec3 base = COLOR.rgb;
	float occlusion = clamp(UV2.y, 0.25, 1.0);
	ROUGHNESS = 0.89;
	SPECULAR = 0.24;
	if (kind < 5.5) {
		vec2 cell = vec2(mod(round(kind), 3.0), floor(round(kind) / 3.0));
		vec2 size = vec2(textureSize(finishes, 0));
		vec2 scale = vec2(atlas_tile.x) / size;
		vec2 texture_uv = (cell * (atlas_tile.x + 2.0 * atlas_tile.y) + atlas_tile.y) / size + fract(UV) * scale;
		vec2 horizontal = dFdx(UV) * scale;
		vec2 vertical = dFdy(UV) * scale;
		vec3 material_color = textureGrad(finishes, texture_uv, horizontal, vertical).rgb;
		float luma = dot(material_color, vec3(0.24, 0.66, 0.10));
		vec3 mineral = mix(vec3(luma), material_color, 0.54);
		base *= mix(mineral, vec3(1.0), 0.29);
		float height_from_base = COLOR.a * 8.0 - 0.4;
		float capillary = 1.0 - smoothstep(0.12, 1.05, height_from_base);
		float upright = 1.0 - abs((mat3(INV_VIEW_MATRIX) * NORMAL).y);
		if (has_weathering && kind < 2.6) {
			vec2 direction = vec2(site.x + site.z * 0.73, site.y) * vec2(0.171, 0.242);
			vec4 deposit = texture(weathering, direction);
			float drip = deposit.r * upright * (0.27 + 0.61 * capillary);
			float lime = max(0.0, deposit.g - 0.22) * (0.38 + 0.55 * capillary);
			float spores = deposit.b * capillary * upright * (0.65 + (1.0 - occlusion) * 0.67);
			base *= mix(vec3(1.0), vec3(0.72, 0.66, 0.59), drip * 0.63 + capillary * 0.13);
			base = mix(base, base * 0.57 + vec3(0.082, 0.082, 0.039), spores * 0.57);
			base = mix(base, base * 0.79 + vec3(0.14, 0.125, 0.103), lime * 0.58);
			if (kind < 0.5) {
				base = mix(base, vec3(0.36, 0.26, 0.20) * (0.69 + luma * 0.61),
					deposit.a * (0.13 + 0.27 * capillary) * upright);
			}
			ROUGHNESS -= drip * 0.14;
		}
		EMISSION = base * vec3(0.020, 0.027, 0.039) * occlusion;
		if (kind > 4.5) {
			base = mix(material_color, base, 0.43);
			ROUGHNESS = 0.46;
		}
		if (material_detail) {
			NORMAL_MAP = textureGrad(relief, texture_uv, horizontal, vertical).rgb;
			NORMAL_MAP_DEPTH = 0.53;
		}
	} else if (kind < 6.5) {
		ROUGHNESS = 0.41;
		METALLIC = 0.12;
		SPECULAR = 0.44;
		base = mix(base, vec3(0.24, 0.28, 0.30), 0.17) * (0.94 + 0.055 * sin(UV.y * 115.0));
	} else if (kind < 7.5) {
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float fresnel = (1.0 - facing) * (1.0 - facing);
		vec3 ray = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
		vec3 reflection = vec3(0.21, 0.28, 0.37);
		if (material_detail) {
			reflection = textureLod(street_sky, street_cloud_uv(ray), 3.4).rgb * vec3(0.56, 0.72, 1.05);
		}
		float skyline = smoothstep(-0.11, 0.51 + 0.07 * sin(ray.x * 11.0), ray.y);
		float curtain = 0.88 + 0.12 * sin(UV.x * 68.0 + sin(UV.x * 17.0));
		EMISSION = base * occlusion * curtain * 0.49 + reflection * skyline * (0.17 + fresnel * 0.31);
		ROUGHNESS = 0.24;
		SPECULAR = 0.46;
		base *= 0.51;
	} else {
		EMISSION = base * 1.62;
		ROUGHNESS = 0.49;
	}
	if (has_street_light && kind < 7.5) {
		vec3 outward = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
		vec4 field = vertex_field;
		vec3 bent = vec3(0.0, 0.56, 0.0);
		if (!vertex_light_bake) {
			if (use_bent_bake) {
				sample_street_light(site + outward * 0.42, field, bent);
			} else {
				field = street_light_at_nearest_slice(site + outward * 0.42);
			}
		}
		float orientation = clamp(0.71 + dot(outward, bent) * 0.66, 0.38, 1.0);
		float sky = clamp(field.r * orientation + field.b * 0.19, 0.0, 1.0);
		occlusion *= mix(0.61, 1.0, sky);
		base *= mix(vec3(0.78, 0.81, 0.85), vec3(1.0), sky);
		if (use_baked_shadow) {
			float face = max(dot(outward, normalize(vec3(-0.69, 0.24, -0.68))), 0.0);
			base *= mix(1.0, 0.56, (1.0 - field.a) * face);
		}
		EMISSION += base * (vec3(0.13, 0.22, 0.35) * sky * 0.21
			+ vec3(0.30, 0.18, 0.09) * field.b
			+ vec3(0.93, 0.48, 0.22) * field.g * 0.45);
	}
	ALBEDO = base * mix(0.62, 1.0, occlusion);
	AO = occlusion;
}
