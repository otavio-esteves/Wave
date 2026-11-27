// Eight height slices follow the road's grade. One border texel around each
// tile keeps bilinear samples on their own slices.
uniform sampler2D street_light_volume : filter_linear, repeat_disable;
uniform sampler2D street_light_bent : filter_linear, repeat_disable;
uniform vec4 street_light_bounds;
uniform vec2 street_light_grid;
uniform bool has_street_light = false;
uniform bool use_bent_bake = true;

const float STREET_LIGHT_HEIGHTS[8] = float[8](0.23, 0.91, 1.68, 2.64, 3.74, 5.12, 6.85, 9.45);

vec2 street_light_uv(vec2 site, int slice) {
	vec2 grid = street_light_grid;
	vec2 stride = grid + 2.0;
	vec2 tile = vec2(float(slice % 3), float(slice / 3));
	return (tile * stride + 1.0 + site * grid) / (3.0 * stride);
}

vec2 street_light_position(vec3 point) {
	return (point.xz - street_light_bounds.xy) / street_light_bounds.zw;
}

bool outside_street_light(vec2 position) {
	return any(lessThan(position, vec2(0.0))) || any(greaterThan(position, vec2(1.0)));
}

vec4 street_light_at_ground(vec3 point) {
	vec2 position = street_light_position(point);
	return outside_street_light(position) ? vec4(0.91, 0.0, 0.21, 1.0)
		: textureLod(street_light_volume, street_light_uv(position, 0), 0.0);
}

float street_light_elevation(vec3 point) {
	float station = -point.z;
	float grade = 0.25 + station * 0.025 + sin(station * 0.042) * 0.37 + smoothstep(55.0, 97.0, station) * 0.21;
	return point.y - grade;
}

vec4 street_light_at_nearest_slice(vec3 point) {
	vec2 position = street_light_position(point);
	if (outside_street_light(position)) {
		return vec4(0.91, 0.0, 0.21, 1.0);
	}
	float height = street_light_elevation(point);
	int slice = int(height > 0.57) + int(height > 1.29) + int(height > 2.16) + int(height > 3.19)
		+ int(height > 4.43) + int(height > 5.99) + int(height > 8.15);
	return textureLod(street_light_volume, street_light_uv(position, slice), 0.0);
}

void sample_street_light(vec3 point, out vec4 light, out vec3 bent) {
	vec2 position = street_light_position(point);
	bent = vec3(0.0, 0.56, 0.0);
	if (outside_street_light(position)) {
		light = vec4(0.91, 0.0, 0.21, 1.0);
		return;
	}
	float height = street_light_elevation(point);
	int high = 1;
	for (int index = 1; index < 7; index++) {
		high += int(height > STREET_LIGHT_HEIGHTS[index]);
	}
	int low = high - 1;
	float mix_height = clamp((height - STREET_LIGHT_HEIGHTS[low]) /
		(STREET_LIGHT_HEIGHTS[high] - STREET_LIGHT_HEIGHTS[low]), 0.0, 1.0);
	vec2 below = street_light_uv(position, low);
	vec2 above = street_light_uv(position, high);
	light = mix(textureLod(street_light_volume, below, 0.0), textureLod(street_light_volume, above, 0.0), mix_height);
	if (use_bent_bake) {
		bent = mix(textureLod(street_light_bent, below, 0.0).rgb, textureLod(street_light_bent, above, 0.0).rgb, mix_height) * 2.0 - 1.0;
	}
}
