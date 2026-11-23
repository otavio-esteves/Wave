shader_type spatial;
render_mode unshaded, shadows_disabled, specular_disabled;

uniform float speed = 0.0;
uniform float rpm = 0.13;
uniform float daylight = 1.0;
uniform float lights = 0.0;

float dial(vec2 point, float value, bool rev_counter) {
	float radius = length(point);
	float angle = atan(point.y, point.x);
	float absolute_angle = mod(angle + 2.3561945, 6.2831853);
	float ring = smoothstep(0.92, 0.95, radius) * (1.0 - smoothstep(0.96, 0.99, radius));
	float draw_arc = 1.0 - smoothstep(4.70, 4.72, absolute_angle);
	float tick = 1.0 - smoothstep(0.035, 0.105, abs(fract(absolute_angle / 0.259 + 0.5) - 0.5));
	float major = step(0.83, abs(cos(absolute_angle / 0.824 * 3.14159265)));
	float marks = tick * draw_arc * smoothstep(mix(0.84, 0.73, major), mix(0.87, 0.76, major), radius);
	marks *= 1.0 - smoothstep(0.91, 0.94, radius);
	float needle_angle = -2.3561945 + clamp(value, 0.0, 1.0) * 4.712389;
	vec2 axis = vec2(cos(needle_angle), sin(needle_angle));
	float pointer = 1.0 - smoothstep(0.018, 0.047, abs(dot(point, vec2(-axis.y, axis.x))));
	pointer *= step(0.015, dot(point, axis)) * (1.0 - smoothstep(0.75, 0.82, radius));
	float cap = 1.0 - smoothstep(0.07, 0.10, radius);
	float red = rev_counter ? smoothstep(3.86, 3.90, absolute_angle) * draw_arc * marks : 0.0;
	return ring * 0.23 + marks * 0.66 + cap * 0.36 + pointer * 1.5 + red * 1.2;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(4.36, 2.32);
	float left = dial(p + vec2(1.09, 0.0), speed, false);
	float right = dial(p - vec2(1.09, 0.0), rpm, true);
	float face = left + right;
	vec3 white = mix(vec3(0.55, 0.63, 0.51), vec3(0.88, 0.88, 0.77), daylight);
	vec3 tint = mix(white, vec3(1.0, 0.39, 0.21), smoothstep(0.83, 1.24, face));
	float indicator = (1.0 - smoothstep(0.055, 0.095, abs(p.x))) * (1.0 - smoothstep(0.031, 0.073, abs(p.y - 0.56)));
	ALBEDO = vec3(0.035, 0.052, 0.053) + tint * min(face, 1.0) * (0.57 + 0.28 * daylight + 0.13 * lights);
	ALBEDO += vec3(0.33, 0.69, 0.77) * indicator * lights;
}
