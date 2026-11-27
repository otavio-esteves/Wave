shader_type spatial;
render_mode diffuse_burley;

#include "street_sky.gdshaderinc"
#include "street_light.gdshaderinc"

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_bake : filter_linear_mipmap, repeat_disable;
uniform sampler2D road_condition : filter_linear_mipmap, repeat_disable;
uniform vec4 road_condition_bounds;
uniform bool has_road_condition = false;
uniform bool has_ground_sun = false;
uniform sampler2D street_sky : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D street_reflection : filter_linear, repeat_disable;
uniform mat4 street_reflection_matrix;
uniform bool use_street_reflection = false;
uniform vec4 bake_bounds;
uniform vec4 tint : source_color = vec4(1.0);
uniform float texture_scale = 0.47;
uniform bool material_detail = true;
uniform bool use_baked_shadow = false;
uniform int surface_kind = 0; // Asphalt, sidewalk, curb, verge, frontage paving, basalt, mosaic.

varying vec2 bake_uv;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	bake_uv = (world_position.xz - bake_bounds.xy) / bake_bounds.zw;
}

float line(float value, float half_size, float feather) {
	return smoothstep(-half_size - feather, -half_size + feather, value)
		- smoothstep(half_size - feather, half_size + feather, value);
}

void fragment() {
	float across = UV.x;
	float station = UV.y;
	float from_curb = abs(across) - UV2.x;
	// Use the continuous coordinates for the filter width, before wrapping
	// them into marks and joints. Derivatives across the wrap span a whole period.
	float across_aa = clamp(fwidth(across) * 0.5, 0.003, 0.23);
	float station_aa = clamp(fwidth(station) * 0.5, 0.003, 0.33);
	float curb_aa = clamp(fwidth(from_curb) * 0.5, 0.003, 0.20);
	vec2 sample_uv = (surface_kind == 3 ? world_position.xz : UV) * texture_scale;
	vec3 texel = texture(albedo_map, sample_uv).rgb;
	// RGB are sun coverage, contact occlusion and broad-scale surface wear.
	vec4 baked = texture(surface_bake, bake_uv);
	if (surface_kind == 3 && (any(lessThan(bake_uv, vec2(0.0))) || any(greaterThan(bake_uv, vec2(1.0))))) {
		baked = vec4(0.0, 0.0, 0.5, 0.0);
	}
	float wear = baked.b;
	vec3 base = texel * tint.rgb;
	float street_shadow = baked.r;
	float ao = 1.0 - baked.g * 0.53;
	float normal_depth = 0.53;
	ROUGHNESS = 0.92;
	SPECULAR = 0.23;

	if (surface_kind == 0) {
		float gutter = smoothstep(-0.55, -0.07, from_curb + 0.13 * wear);
		vec4 road = vec4(0.21 + wear * 0.19, 0.0, 0.0, gutter * 0.31);
		if (has_road_condition) {
			vec2 condition_uv = (UV - road_condition_bounds.xy) / road_condition_bounds.zw;
			road = texture(road_condition, condition_uv);
		}
		float standing_water = smoothstep(0.52, 0.91, road.r);
		float damp = smoothstep(0.14, 0.61, road.r);
		base = mix(base, texel * 0.79 + vec3(0.024, 0.026, 0.028), 0.44);
		base *= 0.91 + 0.19 * wear - road.g * 0.24 - road.b * 0.31;
		base *= 1.0 - 0.20 * damp - 0.17 * standing_water;
		base = mix(base, base * vec3(0.73, 0.70, 0.63) + vec3(0.035, 0.026, 0.013),
			gutter * road.a * 0.81);
		ao -= gutter * 0.13 + road.b * 0.13;
		ROUGHNESS = clamp(0.86 - damp * 0.40 - standing_water * 0.38 + road.a * 0.14, 0.12, 0.92);
		SPECULAR = 0.26 + damp * 0.25;
		normal_depth = (0.58 - 0.18 * damp) * (1.0 - 0.88 * standing_water);
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float grazing = 1.0 - facing;
		float fresnel = 0.024 + 0.976 * grazing * grazing * grazing * grazing * grazing;
		float reflected_amount = fresnel * (0.10 + damp * 0.22 + standing_water * 0.56)
			+ grazing * grazing * damp * 0.11;
		float sky_visibility = (1.0 - street_shadow * 0.37) * (1.0 - baked.g * 0.57);
		vec3 reflected = vec3(0.41, 0.52, 0.69);
		if (material_detail && reflected_amount > 0.010) {
			vec3 ray = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
			reflected = mix(reflected, textureLod(street_sky, street_cloud_uv(ray), 3.5).rgb, 0.65);
		}
		if (use_street_reflection && reflected_amount > 0.008) {
			vec4 projected = street_reflection_matrix * vec4(world_position, 1.0);
			if (projected.w > 0.001) {
				vec2 point = projected.xy / projected.w * vec2(0.5, -0.5) + 0.5;
				vec2 margin = min(point, 1.0 - point);
				float blend = smoothstep(0.0, 0.035, min(margin.x, margin.y));
				vec2 wobble = vec2(wear - 0.5, road.r - 0.42) * (0.0011 + ROUGHNESS * 0.007);
				vec2 ripple = sin(vec2(across * 14.4 + station * 5.4, station * 8.9 - across * 3.4)
					+ vec2(TIME * 1.60, -TIME * 1.37));
				wobble += ripple * standing_water * 0.00065;
				vec3 reflection = texture(street_reflection, point + wobble).rgb;
				reflected = mix(reflected, reflection * 1.31, blend);
				reflected_amount *= 1.0 + blend * (damp * 0.29 + standing_water * 0.39);
			}
		}
		EMISSION = reflected * (reflected_amount * sky_visibility);

		float dash = line(across, 0.060, across_aa) * line(mod(station - 1.3, 7.4) - 3.7, 1.28, station_aa);
		dash *= smoothstep(18.0, 21.0, station) * (1.0 - smoothstep(130.0, 132.0, station));
		float crossing = line(station - 32.2, 1.65, station_aa) * line(mod(across + 0.3, 0.91) - 0.455, 0.23, across_aa);
		crossing *= smoothstep(0.19, 0.26, -from_curb);
		float abrasion = smoothstep(0.19, 0.39, texel.r * 0.71 + wear * 0.29) * (1.0 - road.b * 0.73);
		float paint = abrasion * (0.71 + 0.24 * wear) * (1.0 - 0.38 * standing_water);
		base = mix(base, vec3(0.73, 0.48, 0.14), paint * dash * (1.0 - crossing));
		base = mix(base, vec3(0.71, 0.68, 0.62), paint * crossing);
		ROUGHNESS = mix(ROUGHNESS, 0.69, max(dash, crossing) * paint);
	} else if (surface_kind == 1) {
		float stagger = station + sign(across) * 0.69;
		float cut = line(mod(stagger + wear * 0.041, 1.72) - 0.86, 0.012, station_aa);
		float seam = line(mod(from_curb - 0.28 + 0.47, 0.94) - 0.47, 0.008, curb_aa);
		float slab = fract(sin(floor(stagger / 1.72) * 13.49 + floor(from_curb / 0.94) * 31.1) * 31.37);
		float repair = smoothstep(0.54, 0.76, slab) * (0.25 + 0.75 * wear);
		float dust = smoothstep(0.87, 1.91, from_curb) * wear;
		float curb_splash = (1.0 - smoothstep(0.23, 0.53, from_curb)) * wear;
		base *= (0.65 + 0.20 * slab + 0.48 * wear - dust * 0.29 - curb_splash * 0.18)
			* (1.0 - max(cut, seam) * 0.37);
		base = mix(base, base * vec3(1.08, 0.94, 0.79), repair * 0.40);
		ao -= dust * 0.17;
		float tactile = line(station - 32.2, 1.10, station_aa) * line(from_curb - 0.43, 0.17, curb_aa);
		vec2 tile = abs(fract(vec2(station, from_curb) * 15.0) - 0.5);
		float stud = 1.0 - smoothstep(0.16, 0.33, max(tile.x, tile.y));
		base = mix(base, vec3(0.63, 0.47, 0.24) * (0.83 + 0.24 * stud + 0.12 * wear), tactile);
	} else if (surface_kind == 2) {
		base *= (0.71 + 0.45 * wear) * COLOR.rgb;
		ao -= clamp(0.16 - from_curb, 0.0, 0.16) * 1.9;
	} else if (surface_kind == 3) {
		vec2 field = world_position.xz;
		float patch = 0.50 + 0.24 * sin(field.x * 0.73 + sin(field.y * 0.19) * 1.78)
			* cos(field.y * 0.56 + cos(field.x * 0.22) * 1.29);
		float greens = smoothstep(0.30, 0.75, patch);
		base *= mix(vec3(0.98, 0.94, 0.83), vec3(0.79, 0.94, 0.81), greens);
		normal_depth *= 0.66;
	} else if (surface_kind == 4) {
		float driveway = smoothstep(0.28, 0.58, wear);
		base *= 0.81 + 0.34 * wear + 0.10 * driveway;
		ao -= 0.12 + wear * 0.09;
	} else if (surface_kind == 5) {
		base *= 0.94 + 0.20 * wear;
		ao -= 0.07;
	} else {
		// Evaluate the mosaic on each stone. The warped courses break up the
		// edge of the pattern and keep mortar in both colours of stone.
		float row = floor(station / 0.092);
		float lateral = (from_curb + 0.017 * sin(row * 2.37)) / 0.103;
		lateral += 0.51 * mod(row, 2.0) + 0.15 * cos(row * 1.46);
		vec2 cell = vec2(lateral, station / 0.092);
		vec2 index = floor(cell);
		vec2 clast = abs(fract(cell) - 0.5);
		float random_stone = fract(sin(dot(index, vec2(20.81, 13.54))) * 43758.541);
		float shape = max(clast.x * (0.96 + random_stone * 0.055), clast.y);
		float footprint = min(max(curb_aa / 0.103, station_aa / 0.092), 0.6);
		float coarse = smoothstep(0.18, 0.65, footprint);
		float stone = 1.0 - smoothstep(0.41 - footprint * 0.32, 0.49 + footprint * 0.28, shape);
		float wave_station = mix((row + 0.5) * 0.092, station, coarse);
		float wave_curb = mix(from_curb - (fract(lateral) - 0.5) * 0.103, from_curb, coarse);
		float wave = sin(wave_station * 1.52 + sign(across) * 0.43) * 0.137;
		float border = line(wave_curb - 0.64 - wave, 0.077, max(curb_aa, 0.027) + 0.015 * coarse)
			+ line(wave_curb - 1.51 + wave * 0.65, 0.064, max(curb_aa, 0.027) + 0.015 * coarse);
		float dark_mix = clamp(border + smoothstep(0.65, 0.77, wear) * 0.19, 0.0, 1.0);
		vec3 pale = vec3(0.50, 0.48, 0.40) * (0.82 + 0.30 * texel.r);
		vec3 dark = vec3(0.155, 0.171, 0.169) * (0.76 + 0.36 * texel.r);
		vec3 mineral = mix(pale, dark, dark_mix) * mix(0.84 + 0.22 * random_stone, 1.0, coarse);
		vec3 mortar = vec3(0.296, 0.277, 0.237) * (0.79 + wear * 0.29);
		base = mix(mortar, mineral, mix(stone, 0.89, coarse)) * (0.81 + wear * 0.24);
		ao *= mix(0.81 + 0.19 * stone, 1.0, coarse);
		ROUGHNESS = 0.81 - wear * 0.14;

	}

	if (use_baked_shadow) {
		base *= mix(vec3(1.0), vec3(0.44, 0.57, 0.76), street_shadow * (has_ground_sun ? 0.76 : 0.70));
	}
	vec3 pool = baked.a * vec3(0.41, 0.245, 0.088);
	if (has_street_light) {
		vec4 field = street_light_at_ground(world_position);
		base *= mix(0.83, 1.03, field.r);
		ao *= mix(0.74, 1.0, field.r);
		if (use_baked_shadow && !has_ground_sun) {
			base *= mix(vec3(0.70, 0.78, 0.89), vec3(1.0), field.a);
		}
		pool = mix(pool, field.g * vec3(0.86, 0.46, 0.18), 0.81);
		EMISSION += base * (vec3(0.10, 0.16, 0.22) * field.r * 0.15
			+ vec3(0.18, 0.12, 0.07) * field.b);
	}
	EMISSION += pool * mix(0.38, 0.80, ROUGHNESS) * (1.0 - baked.g * 0.30);
	ALBEDO = base * (1.0 - baked.g * 0.13);
	AO = clamp(ao, 0.22, 1.0);
	if (material_detail) {
		NORMAL_MAP = texture(normal_texture, sample_uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
}
