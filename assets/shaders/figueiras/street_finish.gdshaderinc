#ifdef STREET_ECONOMY
uniform sampler2D base_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
#else
uniform sampler2D base_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
#endif
uniform sampler2D aggregate_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool material_detail = false;
uniform bool repaved = false;
uniform bool vertex_paint = false;
uniform int surface_kind = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 avenue_section = vec3(0.95, 3.7, 8.35);
uniform float wetness = 0.0;
uniform vec4 road_horizon : source_color = vec4(0.58, 0.66, 0.74, 1.0);
uniform vec4 road_zenith : source_color = vec4(0.31, 0.42, 0.55, 1.0);
uniform int wet_road_lamp_count = 0;
uniform vec4 wet_road_lamps[6];
uniform bool has_ground_contact = false;
uniform sampler2D ground_contact : filter_linear_mipmap, repeat_disable;
uniform vec4 contact_bounds = vec4(0.0);
uniform float tree_contact_strength = 1.0;

// Grass never uses the road film, paint, or drainage branches.
#ifdef STREET_MEADOW
#define SURFACE_KIND 5
#else
#define SURFACE_KIND surface_kind
#endif

varying vec3 ground_position;
varying float broad_variation;

float grain(vec2 p) {
	vec2 cell = fract(p * vec2(0.1031, 0.1099));
	cell += dot(cell, cell.yx + 33.33);
	return fract((cell.x + cell.y) * cell.x);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = ground_position.xz;
	broad_variation = cos(p.x * 0.105 + p.y * 0.087) * sin(p.y * 0.061 - p.x * 0.029);
}

void fragment() {
	vec2 street_position = ground_position.xz;
	vec3 surface = tint.rgb;
	float roughness = 0.90;
	float dirt_edge = 0.0;
#ifdef STREET_UTILITY_COVER
	vec2 v = UV * 2.0 - 1.0;
	float r = length(v);
	if (r > 0.97) { discard; }
	float ring = step(0.82, r) - step(0.90, r);
	float grid = step(0.56, fract(v.x * 6.0 + v.y * 3.0)) * step(0.52, fract(v.x * 6.0 - v.y * 3.0));
	surface *= 0.42 + 0.33 * grid + 0.46 * ring;
	roughness = 0.72;
	float shine = 0.0;
#else
	if (SURFACE_KIND == 4) {
		float border = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float channels = smoothstep(0.54, 0.65, fract(UV.x * 11.0));
		float open_grate = channels * smoothstep(0.035, 0.085, border) * smoothstep(0.022, 0.078, abs(UV.y - 0.5));
		surface *= mix(0.86, 0.22, open_grate);
		roughness = 0.74;
	} else if (SURFACE_KIND == 2) {
		// Overpaint follows the clipped road triangles and retains worn edges.
		vec2 paint_grid = street_position * 42.0;
		float paint_grain = grain(floor(paint_grid));
		float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		vec2 footprint = fwidth(paint_grid);
		float visible_grit = 1.0 - smoothstep(0.40, 1.55, max(footprint.x, footprint.y));
		float abrasion = smoothstep(0.62, 1.0, paint_grain) * (1.0 - smoothstep(0.0, 0.31, edge));
		float wear = 0.88 + 0.09 * sin(street_position.x * 1.54 + street_position.y * 1.07);
		surface = (vertex_paint ? COLOR.rgb : surface) * (wear - abrasion * 0.36 * visible_grit);
		roughness = 0.81;
	} else {
		vec2 p = street_position;
		vec3 tile = texture(base_color, SURFACE_KIND == 0 ? UV * 0.76 : UV).rgb;
		float broad = broad_variation;
		float weather = 0.44 + broad * 0.11;
#ifndef STREET_ECONOMY
		if (material_detail && SURFACE_KIND != 5) {
			weather = texture(base_color, p * 0.039 + vec2(0.11, 0.74)).r;
		}
#endif
		if (SURFACE_KIND == 0 && UV2.x > 0.5) {
			float stones = dot(tile, vec3(0.24, 0.67, 0.09));
			vec3 drain = surface * (0.39 + stones * 0.32 + 0.11 * broad);
			vec3 verge = COLOR.rgb * vec3(0.96, 0.95, 0.87) * (0.68 + stones * 0.63);
			float growth = smoothstep(0.06, 0.99, COLOR.a + (stones - 0.57) * 0.22);
			surface = mix(drain, verge, growth);
			dirt_edge = 1.0 - growth * 0.92;
		} else if (SURFACE_KIND == 0) {
			float gutter = 1.0 - smoothstep(0.04, 0.73, COLOR.r);
			dirt_edge = gutter;
			float lane_offset = COLOR.g * 16.0 - 4.0;
			float track = mix(lane_offset, mod(lane_offset - avenue_section.x, avenue_section.y) - avenue_section.y * 0.5, COLOR.a);
			float shoulder = smoothstep(avenue_section.z - 0.15, avenue_section.z + 0.20, lane_offset) * COLOR.a;
			float median = (1.0 - smoothstep(avenue_section.x - 0.12, avenue_section.x + 0.18, lane_offset)) * COLOR.a;
			float tire = (1.0 - smoothstep(0.11, 0.69, abs(abs(track) - 0.68))) * COLOR.b * (1.0 - max(shoulder, median));
			vec3 graded = mix(vec3(dot(tile, vec3(0.24, 0.67, 0.09))), tile, 0.28);
			surface *= mix(vec3(0.67), graded, 0.78) * (0.72 + 0.50 * weather + 0.13 * broad + shoulder * 0.18 + median * 0.12);
			float dirt = gutter * (0.26 + 0.19 * broad + weather * 0.27);
			surface = mix(surface, surface * vec3(1.40, 1.25, 1.08), dirt);
			surface *= 1.0 - (0.042 + 0.066 * weather + 0.033 * broad) * tire;
#ifndef STREET_ECONOMY
			if (material_detail && -VERTEX.z < 52.0) {
				// Sealed cracks interrupt the tire polish in short, irregular
				// lengths. Fade before these marks approach one pixel.
				vec2 repair_uv = mat2(vec2(0.38, 0.11), vec2(-0.11, 0.38)) * p;
				float seed = grain(floor(repair_uv));
				vec2 cell = fract(repair_uv) - 0.5;
				float fissure = abs(cell.x - (seed - 0.5) * 0.50 - sin(cell.y * 12.0 + seed * 18.0) * 0.043);
				float seam = 1.0 - smoothstep(0.004, 0.015 + length(fwidth(repair_uv)) * 0.32, fissure);
				seam *= 1.0 - smoothstep(0.17, 0.43, abs(cell.y));
				seam *= smoothstep(0.68, 0.96, seed) * (1.0 - smoothstep(24.0, 52.0, -VERTEX.z));
				surface *= 1.0 - seam * 0.19;
			}
#endif
			if (repaved) {
				surface *= vec3(0.82, 0.855, 0.89);
			}
			roughness = 0.86 - tire * 0.24 - smoothstep(0.58, 0.82, weather) * 0.13;
		} else if (SURFACE_KIND == 5) {
			float aggregate = dot(tile, vec3(0.24, 0.67, 0.09));
			vec3 meadow = COLOR.rgb * (0.74 + aggregate * 0.43 + broad * 0.075);
			float slope = 1.0 - max(dot(normalize(NORMAL), VIEW_MATRIX[1].xyz), 0.0);
			float exposed = slope + UV2.x * 0.11 + (aggregate - 0.46) * 0.15 + broad * 0.035;
			float soil = smoothstep(0.050, 0.185, exposed) * (0.70 - COLOR.a * 0.37);
			float outcrop = smoothstep(0.166, 0.34, exposed) * (0.80 + UV2.x * 0.19);
			vec3 earth = vec3(0.37, 0.29, 0.19) * (0.69 + aggregate * 0.61);
			vec3 rock = vec3(0.39, 0.35, 0.30) * (0.79 + aggregate * 0.42);
			if (outcrop > 0.012 && -VERTEX.z < 175.0) {
				vec3 world_normal = mat3(INV_VIEW_MATRIX) * NORMAL;
				vec2 axis = abs(world_normal.xz);
				vec2 scale = vec2(0.29, 0.40);
#ifdef STREET_ECONOMY
				vec2 face = axis.x > axis.y ? ground_position.zy * scale + vec2(0.37, 0.0) : ground_position.xy * scale;
				vec3 strata = texture(rock_albedo, face).rgb;
#else
				float blend_axis = smoothstep(0.38, 0.62, axis.x / max(axis.x + axis.y, 0.01));
				vec3 face_z = texture(rock_albedo, ground_position.xy * scale).rgb;
				vec3 face_x = texture(rock_albedo, ground_position.zy * scale + vec2(0.37, 0.0)).rgb;
				vec3 strata = mix(face_z, face_x, blend_axis);
#endif
				rock = mix(rock, strata * 0.91, 1.0 - smoothstep(90.0, 175.0, -VERTEX.z));
			}
			surface = mix(mix(meadow, earth, soil), rock, outcrop);
		} else {
			float dust = 1.0 - smoothstep(0.0, 0.40, COLOR.r);
			surface *= tile * (0.71 + weather * 0.50 + 0.12 * broad - dust * 0.13);
		}
#ifndef STREET_ECONOMY
		if (material_detail && -VERTEX.z < 115.0) {
			NORMAL_MAP = texture(aggregate_normal, UV).rgb;
			NORMAL_MAP_DEPTH = (SURFACE_KIND == 5 ? 0.24 : 0.38) * (1.0 - smoothstep(26.0, 115.0, -VERTEX.z));
		}
#endif
	}
	if (SURFACE_KIND == 0 && UV2.y > 0.001) {
		float pools = pow(0.5 + 0.5 * cos(street_position.x * 1.10 + street_position.y * 0.21), 6.0);
		surface *= mix(vec3(1.0), vec3(0.54, 0.51, 0.46) + vec3(0.15, 0.096, 0.049) * pools, UV2.y);
	}

	float exposed_water = wetness * (1.0 - UV2.y * 0.83);
	float shine = 0.0;
	if (exposed_water > 0.001 && SURFACE_KIND < 2) {
		vec3 normal = normalize(NORMAL);
		float surface_grade = 1.0 - clamp(dot(normal, VIEW_MATRIX[1].xyz), 0.0, 1.0);
		float runoff = smoothstep(0.002, 0.012, surface_grade);
		float aggregate = texture(base_color, street_position * 0.137 + vec2(0.16, 0.41)).r;
		float drainage = broad_variation * 0.46 + sin(street_position.x * 0.48 + street_position.y * 0.23) * 0.19;
		float puddle = smoothstep(0.09, 0.46, drainage + (aggregate - 0.48) * 1.31 + dirt_edge * 0.20);
		puddle *= exposed_water * exposed_water * (1.0 - runoff * 0.73) * (SURFACE_KIND == 0 ? 1.0 : 0.33);
		shine = exposed_water * 0.26 + puddle * 0.65;
		// Absorbed water darkens the aggregate. A separate surface film keeps
		// its own roughness and only reflects strongly at shallow view angles.
		surface *= 1.0 - exposed_water * 0.23 - puddle * 0.085;
		vec3 reflected = reflect(-VIEW, normal);
		float one_minus_face = 1.0 - clamp(dot(normal, VIEW), 0.0, 1.0);
		float grazing = 0.020 + 0.98 * pow(one_minus_face, 5.0);
		float reflection_height = dot(reflected, VIEW_MATRIX[1].xyz);
		vec3 sky_strip = mix(road_horizon.rgb, road_zenith.rgb, smoothstep(-0.04, 0.67, reflection_height));
		float outside_cover = mix(1.0, 0.34, UV2.y);
		float sky_reflection = grazing * shine * outside_cover * (0.25 + 0.36 * aggregate);
		EMISSION = sky_strip * sqrt(sky_reflection);
#ifndef STREET_ECONOMY
		RADIANCE = vec4(sky_strip * shine * outside_cover * 0.15, shine * 0.58);
		if (SURFACE_KIND == 0 && material_detail && wet_road_lamp_count > 0 && -VERTEX.z < 89.0) {
			vec3 reflected_world = mat3(INV_VIEW_MATRIX) * reflected;
			float specular_lamps = 0.0;
			for (int lamp = 0; lamp < wet_road_lamp_count; lamp++) {
				vec4 source = wet_road_lamps[lamp];
				vec3 to_light = source.xyz - ground_position;
				float distance_sq = dot(to_light, to_light);
				if (distance_sq > 2704.0 || to_light.y < 0.0) { continue; }
				vec3 separation = to_light * inversesqrt(distance_sq) - reflected_world;
				float lobe = exp(-26.0 * dot(separation.xz, separation.xz) - 3.4 * separation.y * separation.y);
				specular_lamps += lobe * source.w / (1.0 + distance_sq * 0.037);
			}
			float lamp_fade = 1.0 - smoothstep(56.0, 89.0, -VERTEX.z);
			EMISSION += vec3(1.0, 0.71, 0.46) * specular_lamps * shine * (0.31 + puddle * 1.2) * lamp_fade;
		}
		roughness = mix(roughness, mix(0.54, 0.18, puddle), exposed_water);
#endif
	} else if (SURFACE_KIND == 5) {
		surface *= 1.0 - wetness * 0.17;
	}
#endif
	if (has_ground_contact) {
		vec2 contact_uv = (street_position - contact_bounds.xy) * contact_bounds.zw;
		vec2 shade = vec2(0.0);
		if (all(greaterThan(contact_uv, vec2(0.0))) && all(lessThan(contact_uv, vec2(1.0)))) {
			shade = texture(ground_contact, contact_uv).rg;
		}
		float contact = (1.0 - shade.r) * (1.0 - shade.g * tree_contact_strength);
		surface *= contact * contact;
	}
	ALBEDO = surface;
#ifndef STREET_ECONOMY
	ROUGHNESS = roughness;
	SPECULAR = mix(SURFACE_KIND == 0 ? 0.32 : 0.23, 0.63, shine);
#endif
}
