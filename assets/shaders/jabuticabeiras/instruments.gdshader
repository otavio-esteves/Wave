shader_type spatial;
render_mode unshaded, shadows_disabled, specular_disabled;

uniform float speed = 0.0;
uniform float rpm = 0.13;
uniform float daylight = 0.78;
uniform float lights = 0.0;

const int FIGURES[10] = int[10](63, 6, 91, 79, 102, 109, 125, 7, 127, 111);
const float START = 2.35619449;
const float ARC = 4.71238898;

float groove(vec2 point, vec2 center, vec2 half_width, float feather) {
	vec2 edge = abs(point - center) - half_width;
	return 1.0 - smoothstep(0.0, feather, max(edge.x, edge.y));
}

float ring(float radial, float low, float high, float feather) {
	return smoothstep(low - feather, low, radial) * (1.0 - smoothstep(high, high + feather, radial));
}

float figure(vec2 p, int number, float feather) {
	int form = FIGURES[number];
	float result = 0.0;
	for (int segment = 0; segment < 7; segment++) {
		if ((form & (1 << segment)) == 0) {
			continue;
		}
		bool bar = segment == 0 || segment == 3 || segment == 6;
		vec2 center = vec2(0.0, segment == 0 ? -0.45 : (segment == 3 ? 0.45 : 0.0));
		if (!bar) {
			center = vec2(segment < 3 ? 0.23 : -0.23, (segment == 1 || segment == 5) ? -0.23 : 0.23);
		}
		vec2 shape = bar ? vec2(0.188, 0.033) : vec2(0.038, 0.174);
		result = max(result, groove(p, center, shape, feather));
	}
	return result;
}

float reading(vec2 local, int numeral, float feather) {
	int digits = numeral >= 100 ? 3 : (numeral >= 10 ? 2 : 1);
	float x = local.x + float(digits - 1) * 0.307;
	float result = figure(vec2(x - float(digits - 1) * 0.614, local.y), numeral % 10, feather);
	if (digits >= 2) {
		result = max(result, figure(vec2(x - float(digits - 2) * 0.614, local.y), (numeral / 10) % 10, feather));
	}
	if (digits >= 3) {
		result = max(result, figure(vec2(x, local.y), numeral / 100, feather));
	}
	return result;
}

vec3 gauge(vec2 p, float value, bool tachometer) {
	float radius = length(p);
	float aa = clamp(fwidth(radius) * 0.59, 0.003, 0.024);
	float bezel = ring(radius, 0.976, 1.026, aa);
	float bevel = ring(radius, 0.988, 1.002, aa) * (0.5 + 0.42 * clamp(-p.y, -1.0, 1.0));
	float inside = 1.0 - smoothstep(0.96, 0.994, radius);
	float angle = atan(p.y, p.x);
	float travel = mod(angle - START, TAU);
	float divisions = tachometer ? 7.0 : 11.0;
	float scale = travel * divisions / ARC;
	bool emphasized = abs(scale - round(scale)) < 0.065;
	float tick = abs(scale * 4.0 - round(scale * 4.0));
	float sweep = 1.0 - smoothstep(ARC + 0.010, ARC + 0.025, travel);
	float mark = (1.0 - smoothstep(0.029, 0.067 + aa * 2.7, tick)) * sweep
		* ring(radius, emphasized ? 0.808 : 0.871, 0.940, aa);
	float redline = tachometer ? smoothstep(5.46, 5.54, scale) * sweep : 0.0;
	float hash_index = clamp(round(scale), 0.0, divisions);
	float numeral_angle = START + hash_index * ARC / divisions;
	vec2 numeral_center = vec2(cos(numeral_angle), sin(numeral_angle)) * 0.715;
	vec2 numeral_local = (p - numeral_center) * 10.0;
	int numeral = int(hash_index) * (tachometer ? 1 : 20);
	float lettering = 0.0;
	if (abs(numeral_local.x) < 1.03 && abs(numeral_local.y) < 0.58) {
		lettering = reading(numeral_local, numeral, aa * 2.4);
	}
	float needle_angle = START + clamp(value, 0.0, 1.0) * ARC;
	vec2 along = vec2(cos(needle_angle), sin(needle_angle));
	float run = dot(p, along);
	float cross = abs(dot(p, vec2(along.y, -along.x)));
	float narrow = mix(0.047, 0.012, smoothstep(0.0, 0.86, run));
	float pointer = (1.0 - smoothstep(narrow, narrow + aa, cross)) * smoothstep(-0.096, -0.046, run)
		* (1.0 - smoothstep(0.84, 0.88, run));
	float cap = 1.0 - smoothstep(0.082, 0.10, radius);

	vec3 dial = vec3(0.032, 0.041, 0.038) * (0.82 + 0.24 * clamp(-p.y, -1.0, 1.0)) * inside;
	vec3 white = mix(vec3(0.34, 0.44, 0.29), vec3(0.79, 0.77, 0.63), daylight);
	white = mix(white, vec3(0.60, 0.76, 0.46), lights * 0.55);
	dial += white * (lettering * 0.71 + mark * (1.0 - redline * 0.75));
	dial += vec3(0.74, 0.26, 0.15) * (redline * mark + redline * ring(radius, 0.939, 0.953, aa) * 0.81);
	dial += vec3(0.089, 0.097, 0.090) * bezel + vec3(0.12, 0.128, 0.115) * bevel;
	dial = mix(dial, vec3(0.89, 0.25, 0.09), pointer * 0.92);
	dial = mix(dial, vec3(0.14, 0.14, 0.12), cap);
	return dial;
}

void fragment() {
	vec2 panel = (UV - 0.5) * vec2(4.79, 1.97);
	vec3 dial = gauge(panel + vec2(1.19, 0.0), speed, false) + gauge(panel - vec2(1.19, 0.0), rpm, true);
	float width = fwidth(panel.x);
	float texture_grain = 0.45 + 0.55 * sin(UV.x * 2317.0 + sin(UV.y * 941.0))
		* sin(UV.y * 1437.0) * (1.0 - smoothstep(0.006, 0.04, width));
	vec3 substrate = vec3(0.015, 0.019, 0.018) * (0.87 + 0.13 * texture_grain);
	float reflector = 1.0 - smoothstep(0.0, 0.15, abs(panel.y + panel.x * 0.30 + VIEW.y * 1.79 + 0.40));
	float border = ring(max(abs(panel.x) * 0.418, abs(panel.y) * 1.016), 0.964, 0.985, 0.012);
	float status = groove(panel, vec2(0.0, 0.064), vec2(0.072, 0.041), 0.012);
	vec3 glass = vec3(0.066, 0.104, 0.128) * reflector * daylight * 0.67;
	ALBEDO = substrate + dial + glass + border * vec3(0.052, 0.065, 0.061);
	ALBEDO += status * vec3(0.14, 0.38, 0.26) * lights;
}
