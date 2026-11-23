shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D base_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D meadow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray pavement_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 pavement_tints[4] : source_color;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 avenue_section = vec3(0.95, 3.7, 8.35);
uniform int surface_kind = -1;
uniform float wetness = 0.0;
uniform vec4 road_horizon : source_color = vec4(0.58, 0.66, 0.74, 1.0);
uniform vec4 road_zenith : source_color = vec4(0.31, 0.42, 0.55, 1.0);
uniform bool has_ground_contact = false;
uniform sampler2D ground_contact : filter_linear_mipmap, repeat_disable;
uniform vec4 contact_bounds;
uniform float tree_contact_strength = 1.0;

varying flat vec2 finish;
varying vec3 surface_tint;
varying vec2 contact_uv;
varying float verge;

void vertex() {
	finish = CUSTOM0.xy;
	vec2 site = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float broad = cos(site.x * 0.105 + site.y * 0.087) * sin(site.y * 0.061 - site.x * 0.029);
	contact_uv = (site - contact_bounds.xy) * contact_bounds.zw;
	verge = 0.0;
	if (finish.x == 0.0) {
		float gutter = 1.0 - smoothstep(0.04, 0.73, COLOR.r);
		float lane = COLOR.g * 16.0 - 4.0;
		float track = mix(lane, mod(lane - avenue_section.x, avenue_section.y) - avenue_section.y * 0.5, COLOR.a);
		float shoulder = smoothstep(avenue_section.z - 0.15, avenue_section.z + 0.20, lane) * COLOR.a;
		float median = (1.0 - smoothstep(avenue_section.x - 0.12, avenue_section.x + 0.18, lane)) * COLOR.a;
		float tire = (1.0 - smoothstep(0.11, 0.69, abs(abs(track) - 0.68))) * COLOR.b * (1.0 - max(shoulder, median));
		surface_tint = tint.rgb * (0.94 + broad * 0.18 + shoulder * 0.18 + median * 0.12) * (1.0 - 0.071 * tire);
		surface_tint *= mix(vec3(1.0), vec3(1.40, 1.25, 1.08), gutter * (0.38 + broad * 0.16));
		surface_tint *= mix(vec3(1.0), vec3(0.60, 0.55, 0.48), UV2.y);
		if (UV2.x > 0.5) {
			verge = 1.0;
			surface_tint = mix(tint.rgb * 0.54, COLOR.rgb * vec3(0.97, 0.94, 0.86), smoothstep(0.06, 0.99, COLOR.a));
		}
	} else if (finish.x == 1.0) {
		float dust = 1.0 - smoothstep(0.0, 0.40, COLOR.r);
		surface_tint = pavement_tints[int(finish.y)].rgb * (0.93 + broad * 0.175 - dust * 0.13);
	} else if (finish.x == 5.0) {
		float slope = 1.0 - max(0.0, normalize(MODEL_NORMAL_MATRIX * NORMAL).y);
		float exposed = slope + UV2.x * 0.11 + broad * 0.035;
		float soil = smoothstep(0.05, 0.185, exposed) * (0.70 - COLOR.a * 0.37);
		float rock = smoothstep(0.166, 0.34, exposed) * (0.80 + UV2.x * 0.19);
		surface_tint = mix(mix(COLOR.rgb, vec3(0.37, 0.29, 0.19), soil), vec3(0.39, 0.35, 0.30), rock);
		surface_tint *= 1.0 + broad * 0.095 - wetness * 0.17;
	} else {
		surface_tint = COLOR.rgb * (0.89 + broad * 0.06);
	}
}

void fragment() {
	vec3 surface = surface_tint;
	if (finish.x == 0.0) {
		vec3 tile = texture(base_color, UV * 0.76).rgb;
		float gray = dot(tile, vec3(0.24, 0.67, 0.09));
		surface *= mix(vec3(0.1474) + mix(vec3(gray), tile, 0.28) * 0.78, vec3(0.65 + gray * 0.56), verge);
	} else if (finish.x == 1.0) {
		surface *= texture(pavement_albedo, vec3(UV, min(finish.y, 2.0))).rgb;
	} else if (finish.x == 5.0) {
		float aggregate = dot(texture(meadow_albedo, UV).rgb, vec3(0.24, 0.67, 0.09));
		surface *= 0.70 + aggregate * 0.47;
	}
	if (wetness > 0.001 && finish.x <= 1.0) {
		float water = wetness * (1.0 - UV2.y * 0.83);
		float grazing = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
		surface *= 1.0 - water * 0.24;
		EMISSION = mix(road_horizon.rgb, road_zenith.rgb, 0.24)
			* grazing * grazing * sqrt(water) * (1.0 - UV2.y * 0.66) * 0.29;
	}
	if (has_ground_contact && all(greaterThan(contact_uv, vec2(0.0))) && all(lessThan(contact_uv, vec2(1.0)))) {
		vec2 shade = texture(ground_contact, contact_uv).rg;
		float contact = (1.0 - shade.r) * (1.0 - shade.g * tree_contact_strength);
		surface *= contact * contact;
	}
	ALBEDO = surface;
}
