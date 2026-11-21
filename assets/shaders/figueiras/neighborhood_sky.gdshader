shader_type sky;
render_mode disable_fog;

uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction = vec3(0.4, 0.5, 0.4);
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform float night_factor = 0.0;
uniform float cloud_time = 0.0;

float star_hash(vec3 cell) {
	vec3 p = fract(cell * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float height = max(d.y, 0.0);
	float rim = pow(1.0 - height, 5.5);
	vec2 uv = SKY_COORDS;
	uv.x += 0.13 + cloud_time * 0.000028;
	uv.y = clamp(uv.y + 0.038, 0.003, 0.997);
	float longitude = fract(uv.x);
	float from_seam = min(longitude, 1.0 - longitude);
	float lod = AT_CUBEMAP_PASS ? 1.0 : 0.0;
	vec3 cloud_plate = textureLod(panorama, vec2(longitude, uv.y), lod).rgb;
	if (from_seam < 0.075) {
		vec3 opposite_edge = textureLod(panorama, vec2(1.0 - longitude, uv.y), lod).rgb;
		cloud_plate = mix((cloud_plate + opposite_edge) * 0.5, cloud_plate, smoothstep(0.0, 0.075, from_seam));
	}
	float sunlight = max(dot(d, sun_direction), 0.0);
	float opposite = max(dot(d, -sun_direction), 0.0);
	// Twilight persists above the horizon after the direct sun fades on the street.
	float sky_daylight = max(daylight, smoothstep(-0.22, 0.21, sun_direction.y));
	float horizon_warmth = twilight * pow(sunlight, 5.0) * (0.25 + 0.75 * rim);
	vec3 day = cloud_plate * mix(vec3(1.02, 1.0, 0.97), vec3(1.24, 0.83, 0.59), horizon_warmth);
	vec3 distance_air = mix(vec3(0.60, 0.70, 0.82), vec3(0.95, 0.51, 0.28), horizon_warmth);
	day = mix(day, distance_air, rim * 0.31);
	vec3 night = mix(vec3(0.014, 0.021, 0.040), vec3(0.051, 0.058, 0.082), rim);
	night += cloud_plate * vec3(0.026, 0.030, 0.041) * smoothstep(0.01, 0.18, height);
	vec3 color = mix(night, day, sky_daylight) + pow(sunlight, 12.0) * twilight * vec3(0.37, 0.16, 0.074);
	vec3 ground = mix(vec3(0.012, 0.016, 0.024), vec3(0.14, 0.16, 0.15), daylight);
	color = mix(ground, color, smoothstep(-0.11, -0.015, d.y));
	float sun = smoothstep(cos(0.012), cos(0.007), sunlight) * smoothstep(-0.03, 0.025, sun_direction.y);
	float moon = smoothstep(cos(0.012), cos(0.009), opposite) * smoothstep(-0.01, 0.06, -sun_direction.y);
	color += vec3(2.8, 2.3, 1.7) * sun + vec3(0.67, 0.76, 0.93) * moon * night_factor;
	if (!AT_CUBEMAP_PASS && height > 0.05 && night_factor > 0.01) {
		vec3 cell = d * 310.0;
		float star = step(0.982, star_hash(floor(cell))) * (1.0 - smoothstep(0.04, 0.19, length(fract(cell) - 0.5)));
		color += star * night_factor * smoothstep(0.05, 0.18, height);
	}
	COLOR = color;
}
