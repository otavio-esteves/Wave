shader_type sky;
render_mode disable_fog;

uniform vec3 sun_direction = vec3(0.4, 0.5, 0.4);
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform float night_factor = 0.0;
uniform float cloud_time = 0.0;

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
	float horizon = pow(1.0 - altitude, 4.0);
	vec3 zenith = mix(vec3(0.008, 0.014, 0.035), vec3(0.12, 0.35, 0.69), daylight);
	vec3 rim = mix(vec3(0.035, 0.046, 0.075), vec3(0.68, 0.79, 0.91), daylight);
	float sunward = pow(max(dot(normalize(vec3(d.x, 0.001, d.z)), normalize(vec3(sun_direction.x, 0.001, sun_direction.z))), 0.0), 4.0);
	rim = mix(rim, vec3(1.0, 0.38, 0.12), twilight * (0.35 + sunward * 0.65));
	vec3 color = mix(zenith, rim, horizon);
	if (d.y < -0.015) {
		color = mix(vec3(0.018, 0.024, 0.022), vec3(0.19, 0.24, 0.19), daylight);
	}
	float sun_dot = dot(d, sun_direction);
	color += vec3(1.0, 0.62 + daylight * 0.3, 0.35 + daylight * 0.5) * pow(max(sun_dot, 0.0), 64.0) * (0.13 + twilight * 0.2);
	float sun_disc = smoothstep(cos(0.009), cos(0.007), sun_dot) * smoothstep(-0.02, 0.01, sun_direction.y);
	color += vec3(3.0, 2.7, 2.2) * sun_disc;
	vec3 moon_direction = -sun_direction;
	float moon_dot = dot(d, moon_direction);
	float moon_disc = smoothstep(cos(0.012), cos(0.010), moon_dot) * smoothstep(-0.02, 0.04, moon_direction.y);
	float craters = 0.7 + 0.3 * noise(d * 420.0);
	color += vec3(0.75, 0.85, 1.0) * moon_disc * craters * night_factor;
	color += vec3(0.09, 0.13, 0.23) * pow(max(moon_dot, 0.0), 180.0) * night_factor;
	// Three-dimensional star cells are continuous across the panorama seam.
	if (!AT_CUBEMAP_PASS && d.y > 0.015) {
		vec3 cells = d * 350.0;
		vec3 cell = floor(cells);
		float seed = hash(cell);
		vec3 center = vec3(hash(cell + 4.2), hash(cell + 9.1), hash(cell + 2.7));
		float star = (1.0 - smoothstep(0.02, 0.16, length(fract(cells) - center))) * step(0.973, seed);
		color += mix(vec3(0.67,0.79,1.0), vec3(1.0,0.89,0.7), seed) * star * night_factor * smoothstep(0.01, 0.18, d.y) * 1.8;
	}
	if (d.y > 0.025) {
		vec3 p = vec3(d.x / (d.y + 0.23), d.z / (d.y + 0.23), 0.0) * 2.6 + vec3(cloud_time * 0.018, cloud_time * 0.008, 0.0);
		float clouds = noise(p) * 0.62 + noise(p * 2.07) * 0.26 + noise(p * 4.13) * 0.12;
		float cover = smoothstep(0.51, 0.75, clouds) * smoothstep(0.025, 0.2, d.y) * 0.83;
		vec3 cloud_color = mix(vec3(0.035, 0.046, 0.071), vec3(0.90, 0.92, 0.94), daylight);
		cloud_color = mix(cloud_color, vec3(0.89,0.46,0.29), twilight * sunward * 0.6);
		color = mix(color, cloud_color, cover);
	}
	COLOR = color;
}
