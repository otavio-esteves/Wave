shader_type spatial;
render_mode unshaded;

uniform sampler2D meadow_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D woodland_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 grass_color : source_color = vec4(0.36, 0.42, 0.29, 1.0);
uniform vec4 forest_color : source_color = vec4(0.27, 0.35, 0.30, 1.0);
uniform vec4 exposed_soil : source_color = vec4(0.37, 0.32, 0.24, 1.0);

float unpaved_track(float offset, float station, float line, vec2 caps) {
	float runs = smoothstep(caps.x, caps.x + 5.1, station)
		* (1.0 - smoothstep(caps.y - 5.1, caps.y, station));
	float near_track = abs(offset - line);
	float filter = clamp(fwidth(near_track) * 0.61, 0.10, 1.2);
	float road_edge = 1.0 - smoothstep(1.27 - filter, 1.59 + filter, near_track);
	float wheel_track = 1.0 - smoothstep(0.26 - filter * 0.40, 0.40 + filter, abs(near_track - 0.76));
	return runs * road_edge * (0.61 + 0.39 * wheel_track);
}

void fragment() {
	vec3 grass = texture(meadow_map, UV * vec2(1.57, 1.25)).rgb;
	vec3 woods = texture(woodland_map, UV * 0.073).rgb;
	float shoots = dot(grass, vec3(0.22, 0.66, 0.12));
	float cover = dot(woods, vec3(0.20, 0.67, 0.13));
	vec3 meadow = grass_color.rgb * (0.67 + shoots * 0.98 + cover * 0.36);
	vec3 woodland = forest_color.rgb * (0.66 + cover * 1.72 + shoots * 0.24);
	vec3 bank = exposed_soil.rgb * (0.72 + shoots * 0.92);
	vec3 ground = mix(meadow, woodland, COLOR.r);
	ground = mix(ground, bank, COLOR.b * 0.64);
	float left_lane = -15.8 - 0.083 * (UV.y - 203.0) - 4.33 * sin((UV.y - 190.0) * 0.161);
	float right_lane = 17.7 + 0.196 * (UV.y - 198.0) + 4.08 * sin((UV.y - 186.0) * 0.126);
	float path = max(unpaved_track(UV.x, UV.y, left_lane, vec2(187.0, 242.0)),
		unpaved_track(UV.x, UV.y, right_lane, vec2(187.0, 253.0)));
	float nursery_path = 20.5 + 4.65 * sin((UV.y + 54.0) * 0.13);
	path = max(path, unpaved_track(UV.x, UV.y, nursery_path, vec2(-74.0, -33.0)));
	vec3 gravel = mix(vec3(0.177, 0.140, 0.094), vec3(0.318, 0.262, 0.186), shoots);
	ground = mix(ground, gravel, path * 0.80);
	ALBEDO = ground * COLOR.g;
}
