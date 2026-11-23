shader_type sky;
render_mode disable_fog;

uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rain_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 horizon : source_color = vec4(0.67, 0.72, 0.75, 1.0);
uniform vec4 zenith : source_color = vec4(0.32, 0.48, 0.64, 1.0);
uniform vec3 sun_direction = vec3(0.4, 0.5, 0.4);
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform float night_factor = 0.0;
uniform float overcast = 0.0;
uniform float cloud_time = 0.0;

vec3 sky_plate(sampler2D plate, vec2 uv) {
	float longitude = fract(uv.x);
	float from_seam = min(longitude, 1.0 - longitude);
	vec3 color = texture(plate, vec2(longitude, uv.y)).rgb;
	if (from_seam < 0.069) {
		vec3 opposite_edge = texture(plate, vec2(1.0 - longitude, uv.y)).rgb;
		color = mix((color + opposite_edge) * 0.5, color, smoothstep(0.0, 0.069, from_seam));
	}
	return color;
}

float star_hash(vec3 cell) {
	vec3 p = fract(cell * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 direction = EYEDIR;
	float height = max(direction.y, 0.0);
	float horizon_band = 1.0 - smoothstep(0.0, 0.37, height);
	vec3 air = mix(zenith.rgb, horizon.rgb, horizon_band);
	if (AT_CUBEMAP_PASS) {
		// The filtered reflection needs broad sky and ground colors only.
		// Avoid feeding bright cloud edges or star-sized highlights into it.
		COLOR = mix(horizon.rgb * vec3(0.45, 0.52, 0.47), air, smoothstep(-0.35, 0.10, direction.y));
	} else {
		vec2 clear_uv = SKY_COORDS + vec2(0.13 + cloud_time * 0.000028, 0.038);
		clear_uv.y = clamp(clear_uv.y, 0.003, 0.997);
		vec3 plate = vec3(0.0);
		if (overcast < 0.999) {
			plate = sky_plate(panorama, clear_uv);
		}
		float sun_dot = max(dot(direction, sun_direction), 0.0);
		float sun_tint = twilight * sun_dot * sun_dot * horizon_band;
		float sky_light = max(daylight, smoothstep(-0.24, 0.19, sun_direction.y));
		vec3 clear = plate * mix(vec3(0.92, 0.96, 0.98), vec3(1.19, 0.91, 0.76), sun_tint);
		clear = mix(clear, air, 0.19 + horizon_band * 0.56);
		clear = mix(air + plate * vec3(0.023, 0.028, 0.038), clear, sky_light);
		float sun_visibility = smoothstep(-0.010, 0.045, sun_direction.y);
		float sun = smoothstep(0.999918, 0.999975, sun_dot) * sun_visibility;
		float sun_glow = pow(sun_dot, 30.0) * sun_visibility;
		clear += vec3(2.5, 2.18, 1.73) * sun + vec3(0.155, 0.107, 0.071) * sun_glow;
		float moon = smoothstep(0.99992, 0.99996, max(dot(direction, -sun_direction), 0.0));
		clear += vec3(0.52, 0.62, 0.76) * moon * night_factor;
		if (night_factor > 0.02 && height > 0.07 && overcast < 0.94) {
			vec3 cell = direction * 314.0;
			float seed = star_hash(floor(cell));
			float star = step(0.978, seed) * (1.0 - smoothstep(0.055, 0.20, length(fract(cell) - 0.5)));
			clear += vec3(0.59, 0.66, 0.75) * star * night_factor * smoothstep(0.07, 0.27, height);
		}
		vec3 sky_color = clear;
		if (overcast > 0.001) {
			vec2 rain_uv = SKY_COORDS + vec2(0.34 + cloud_time * 0.000091, 0.0);
			vec3 rain_plate = sky_plate(rain_panorama, rain_uv);
			float cloud = dot(rain_plate, vec3(0.25, 0.63, 0.12));
			vec3 storm = air * mix(0.65, 1.45, smoothstep(0.20, 0.64, cloud));
			storm = mix(storm, horizon.rgb, horizon_band * 0.28);
			sky_color = mix(clear, storm, overcast);
		}
		COLOR = mix(horizon.rgb * vec3(0.72, 0.80, 0.82), sky_color, smoothstep(-0.24, 0.012, direction.y));
	}
}
