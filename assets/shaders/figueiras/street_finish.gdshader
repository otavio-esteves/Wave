shader_type spatial;

uniform sampler2D base_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aggregate_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool material_detail = false;
uniform bool repaved = false;
uniform bool vertex_paint = false;
uniform int surface_kind = 0;
uniform vec4 tint : source_color = vec4(1.0);
varying vec2 street_position;
varying float broad_variation;

float grain(vec2 p) {
	vec2 cell = fract(p * vec2(0.1031, 0.1099));
	cell += dot(cell, cell.yx + 33.33);
	return fract((cell.x + cell.y) * cell.x);
}

void vertex() {
	street_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	broad_variation = cos(street_position.x * 0.105 + street_position.y * 0.087) * sin(street_position.y * 0.061 - street_position.x * 0.029);
}

void fragment() {
	vec3 surface = tint.rgb;
	float roughness = 0.90;
	if (surface_kind == 4) {
		float border = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float channels = smoothstep(0.54, 0.65, fract(UV.x * 11.0));
		float open_grate = channels * smoothstep(0.035, 0.085, border) * smoothstep(0.022, 0.078, abs(UV.y - 0.5));
		surface *= mix(0.86, 0.22, open_grate);
		roughness = 0.74;
	} else if (surface_kind == 3) {
		vec2 v = UV * 2.0 - 1.0;
		float r = length(v);
		if (r > 0.97) { discard; }
		float ring = step(0.82, r) - step(0.90, r);
		float grid = step(0.56, fract(v.x * 6.0 + v.y * 3.0)) * step(0.52, fract(v.x * 6.0 - v.y * 3.0));
		surface *= 0.42 + 0.33 * grid + 0.46 * ring;
		roughness = 0.72;
	} else if (surface_kind == 2) {
		// Overpaint follows the clipped road triangles and retains worn edges.
		vec2 paint_grid = street_position * 57.0;
		float paint_grain = grain(floor(paint_grid));
		float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float abrasion = smoothstep(0.68, 1.0, paint_grain) * (1.0 - smoothstep(0.0, 0.28, edge));
		float wear = 0.93 + 0.07 * sin(street_position.x * 2.0 + street_position.y * 1.7);
		surface = (vertex_paint ? COLOR.rgb : surface) * (wear - abrasion * 0.41);
		roughness = 0.94;
	} else {
		vec2 p = street_position;
		vec3 tile = texture(base_color, UV).rgb;
		float broad = broad_variation;
		float weather = material_detail ? texture(base_color, p * 0.039 + vec2(0.11, 0.74)).r : 0.44 + broad * 0.11;
		if (surface_kind == 0 && UV2.x > 0.5) {
			vec3 aggregate = UV2.x > 1.5 ? vec3(0.76, 0.76, 0.63) : vec3(0.73, 0.70, 0.61);
			surface *= tile * aggregate * (0.71 + weather * 0.50 + 0.12 * broad);
		} else if (surface_kind == 0) {
			float gutter = 1.0 - smoothstep(0.03, 0.77, COLOR.r);
			float lane_offset = COLOR.g * 12.0;
			float track = mix(lane_offset - 2.10, mod(lane_offset, 3.60) - 1.80, COLOR.a);
			float tire = 1.0 - smoothstep(0.10, 0.52, abs(abs(track) - 0.70));
			tire *= COLOR.b * (1.0 - COLOR.a * smoothstep(7.0, 7.42, lane_offset));
			float parking = COLOR.a * smoothstep(7.02, 7.35, lane_offset);
			surface *= tile * (0.78 + 0.40 * weather + 0.073 * broad + parking * 0.11);
			surface = mix(surface, surface * vec3(1.26, 1.13, 0.91), gutter * (0.33 + 0.22 * broad));
			surface *= 1.0 - (0.090 + 0.055 * weather) * tire;
			if (repaved) {
				surface *= vec3(0.82, 0.855, 0.89);
			}
			roughness = 0.85 - tire * 0.14;
		} else if (surface_kind == 5) {
			float field = smoothstep(-0.43, 0.60, broad + weather * 0.65 - 0.32);
			surface *= tile * COLOR.rgb * mix(vec3(0.74, 0.86, 0.79), vec3(1.08, 1.04, 0.84), field);
		} else {
			float dust = 1.0 - smoothstep(0.0, 0.40, COLOR.r);
			surface *= tile * (0.71 + weather * 0.50 + 0.12 * broad - dust * 0.13);
		}
		if (material_detail) {
			NORMAL_MAP = texture(aggregate_normal, UV).rgb;
			NORMAL_MAP_DEPTH = surface_kind == 5 ? 0.18 : 0.34;
		}
	}
	if (surface_kind == 0 && UV2.y > 0.001) {
		float pools = pow(0.5 + 0.5 * cos(street_position.x * 1.10 + street_position.y * 0.21), 6.0);
		surface *= mix(vec3(1.0), vec3(0.54, 0.51, 0.46) + vec3(0.15, 0.096, 0.049) * pools, UV2.y);
	}
	ALBEDO = surface;
	ROUGHNESS = roughness;
	SPECULAR = 0.23;
}
