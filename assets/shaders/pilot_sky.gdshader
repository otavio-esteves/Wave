shader_type sky;
render_mode disable_fog;

uniform vec3 sun_direction = vec3(0.4, 0.5, 0.4);
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform float night_factor = 0.0;
uniform float cloud_time = 0.0;
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void sky() {
	vec3 d = normalize(EYEDIR);
	float altitude = max(d.y, 0.0);
	float horizon = pow(1.0 - altitude, 3.2);
	vec3 zenith = mix(vec3(0.006, 0.012, 0.030), vec3(0.12, 0.29, 0.51), daylight);
	vec3 rim = mix(vec3(0.045, 0.058, 0.089), vec3(0.67, 0.77, 0.84), daylight);
	float sunward = pow(max(dot(normalize(vec3(d.x, 0.001, d.z)), normalize(vec3(sun_direction.x, 0.001, sun_direction.z))), 0.0), 4.0);
	rim = mix(rim, vec3(0.98, 0.48, 0.23), twilight * (0.28 + sunward * 0.72));
	vec3 color = mix(zenith, rim, horizon);
	// A broad aerosol aureole gives the low sun a gradual falloff rather than
	// an isolated white circle. It also colours the distant environment capture.
	float aureole = pow(max(dot(d, sun_direction), 0.0), 12.0);
	color += vec3(0.24, 0.16, 0.075) * aureole * (0.18 + twilight * 0.75) * daylight;
	if (d.y < -0.015) {
		color = mix(vec3(0.018, 0.024, 0.022), vec3(0.19, 0.24, 0.19), daylight);
	}
	float sun_dot = dot(d, sun_direction);
	color += vec3(1.0, 0.62 + daylight * 0.3, 0.35 + daylight * 0.5) * pow(max(sun_dot, 0.0), 64.0) * (0.13 + twilight * 0.2);
	float sun_disc = smoothstep(cos(0.009), cos(0.007), sun_dot) * smoothstep(-0.02, 0.01, sun_direction.y);
	color += vec3(3.0, 2.7, 2.2) * sun_disc;
	if (night_factor > 0.01) {
		vec3 moon_direction = -sun_direction;
		float moon_dot = dot(d, moon_direction);
		float moon_disc = smoothstep(cos(0.012), cos(0.010), moon_dot) * smoothstep(-0.02, 0.04, moon_direction.y);
		if (moon_disc > 0.0) {
			// Crater noise only contributes inside this tiny disc; evaluating
			// eight 3-D lattice corners over the entire night sky wastes ALU.
			float craters = 0.7 + 0.3 * noise(d * 420.0);
			color += vec3(0.75, 0.85, 1.0) * moon_disc * craters * night_factor;
		}
		color += vec3(0.09, 0.13, 0.23) * pow(max(moon_dot, 0.0), 180.0) * night_factor;
		// Three-dimensional star cells are continuous across the panorama seam.
		if (!AT_CUBEMAP_PASS && d.y > 0.015) {
			vec3 cells = d * 350.0;
			vec3 cell = floor(cells);
			float seed = hash(cell);
			if (seed >= 0.973) {
				vec3 center = vec3(hash(cell + 4.2), hash(cell + 9.1), hash(cell + 2.7));
				float star = 1.0 - smoothstep(0.02, 0.16, length(fract(cells) - center));
				color += mix(vec3(0.67,0.79,1.0), vec3(1.0,0.89,0.7), seed) * star * night_factor * smoothstep(0.01, 0.18, d.y) * 1.8;
			}
		}
	}
	if (d.y > 0.018) {
		// Three reads of a small baked noise plate replace ray marching. The
		// offset read supplies a stable sun-facing rim and shaded cloud belly.
		vec2 wind = vec2(cloud_time * 0.0011, cloud_time * 0.00045);
		vec2 p = d.xz / (d.y + 0.22) * 0.165 + wind;
		float clouds = texture(cloud_noise, p).r;
		float detail = texture(cloud_noise, p * 3.02 + vec2(0.31, 0.67)).r;
		float density = clouds * 0.80 + detail * 0.20;
		vec2 sun_offset = sun_direction.xz / max(length(sun_direction.xz), 0.05) * 0.012;
		float toward_sun = texture(cloud_noise, p + sun_offset).r;
		float edge_light = clamp((clouds - toward_sun) * 8.0 + 0.50, 0.0, 1.0);
		float thin = 1.0 - smoothstep(0.50, 0.72, density);
		float cover = smoothstep(0.47, 0.73, density) * smoothstep(0.018, 0.17, d.y) * 0.91;
		vec3 cloud_day = mix(vec3(0.47, 0.57, 0.66), vec3(0.97, 0.96, 0.90), clamp(edge_light * 0.66 + thin * 0.42, 0.0, 1.0));
		vec3 cloud_color = mix(vec3(0.027, 0.039, 0.065), cloud_day, daylight);
		cloud_color = mix(cloud_color, vec3(0.94, 0.53, 0.30), twilight * sunward * (0.35 + edge_light * 0.35));
		color = mix(color, cloud_color, cover);
	}
	COLOR = color;
}
