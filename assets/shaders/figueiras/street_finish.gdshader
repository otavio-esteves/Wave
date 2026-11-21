shader_type spatial;

uniform sampler2D base_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aggregate_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool material_detail = false;
uniform int surface_kind = 0;
uniform vec4 tint : source_color = vec4(1.0);
varying vec2 street_position;

float grain(vec2 p) {
	vec2 cell = fract(p * vec2(0.1031, 0.1099));
	cell += dot(cell, cell.yx + 33.33);
	return fract((cell.x + cell.y) * cell.x);
}

void vertex() {
	street_position = VERTEX.xz;
}

void fragment() {
	vec3 surface = tint.rgb;
	float roughness = 0.90;
	if (surface_kind == 3) {
		vec2 v = UV * 2.0 - 1.0;
		float r = length(v);
		if (r > 0.97) { discard; }
		float ring = step(0.82, r) - step(0.90, r);
		float grid = step(0.56, fract(v.x * 6.0 + v.y * 3.0)) * step(0.52, fract(v.x * 6.0 - v.y * 3.0));
		surface *= 0.42 + 0.33 * grid + 0.46 * ring;
		roughness = 0.72;
	} else if (surface_kind == 2) {
		// Overpaint follows the clipped road triangles and retains worn edges.
		vec2 paint_grid = UV * vec2(512.0, 72.0);
		float paint_grain = grain(floor(paint_grid));
		float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float abrasion = smoothstep(0.78, 1.0, paint_grain) * (1.0 - smoothstep(0.0, 0.19, edge));
		surface *= 0.94 - abrasion * 0.32;
		roughness = 0.94;
	} else {
		vec2 p = street_position;
		vec3 tile = texture(base_color, UV).rgb;
		float weather = texture(base_color, p * 0.039 + vec2(0.11, 0.74)).r;
		float broad = cos(p.x * 0.105 + p.y * 0.087) * sin(p.y * 0.061 - p.x * 0.029);
		if (surface_kind == 0) {
			float gutter = 1.0 - smoothstep(0.03, 0.77, COLOR.r);
			float lane_offset = COLOR.g * 8.0;
			float tire = 1.0 - smoothstep(0.05, 0.48, abs(abs(lane_offset - 1.81) - 0.65));
			tire *= COLOR.b;
			surface *= tile * (0.83 + 0.33 * weather + 0.065 * broad);
			surface = mix(surface, surface * vec3(1.30, 1.20, 0.99), gutter * (0.20 + 0.20 * broad));
			surface *= 1.0 - 0.125 * tire;
			roughness = 0.84 - tire * 0.12;
		} else {
			float dust = 1.0 - smoothstep(0.0, 0.40, COLOR.r);
			surface *= tile * (0.71 + weather * 0.50 + 0.12 * broad - dust * 0.13);
		}
		if (material_detail) {
			NORMAL_MAP = texture(aggregate_normal, UV).rgb;
			NORMAL_MAP_DEPTH = surface_kind == 0 ? 0.31 : 0.40;
		}
	}
	ALBEDO = surface;
	ROUGHNESS = roughness;
	SPECULAR = 0.23;
}
