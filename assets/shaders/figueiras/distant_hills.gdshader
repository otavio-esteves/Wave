shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform sampler2D canopy_pattern : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 air : source_color = vec4(0.58, 0.67, 0.74, 1.0);
uniform vec4 air_above : source_color = vec4(0.50, 0.61, 0.73, 1.0);
uniform vec3 sun_direction = vec3(0.4, 0.5, 0.4);
uniform float daylight = 1.0;
uniform float overcast = 0.0;

varying vec2 grove_uv;
varying float grove_contour;
varying float hillside;
varying float low_ground;
varying float elevation;

void vertex() {
	vec3 world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	hillside = dot(world_normal, sun_direction);
	low_ground = 1.0 - smoothstep(24.0, 140.0, world_point.y);
	elevation = world_point.y;
	grove_uv = world_point.xz * mat2(vec2(0.021, 0.008), vec2(-0.008, 0.021));
	grove_contour = sin(world_point.x * 0.021 + world_point.y * 0.043) * cos(world_point.z * 0.025 - world_point.y * 0.029);
}

void fragment() {
	vec3 canopy = texture(canopy_pattern, grove_uv).rgb;
	float density = dot(canopy, vec3(0.23, 0.66, 0.11));
	float woodland = smoothstep(0.31, 0.61, COLOR.a * 0.41 + density * 0.57 + grove_contour * 0.16);
	float key = mix(smoothstep(-0.07, 0.87, hillside), 0.64, overcast * 0.77);
	vec3 land = COLOR.rgb * mix(vec3(1.17, 1.11, 0.95), vec3(0.68, 0.83, 0.78), woodland) * (0.76 + density * 0.48);
	land *= mix(vec3(0.64, 0.71, 0.75), vec3(1.16, 1.13, 1.00), key);
	vec3 moon_land = land * vec3(0.16, 0.23, 0.35);
	float distance_from_eye = length(VERTEX);
	float optical_depth = max(0.0, distance_from_eye - 120.0) * mix(0.00069, 0.0021, overcast);
	float aerial_mix = 1.0 - exp(-optical_depth * (0.84 + low_ground * 0.52));
	vec3 aerial_color = mix(air.rgb, air_above.rgb, smoothstep(18.0, 245.0, elevation) * 0.74);
	ALBEDO = mix(mix(moon_land, land, daylight), aerial_color, aerial_mix);
}
