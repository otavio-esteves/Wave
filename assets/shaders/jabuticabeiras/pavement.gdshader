shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_bake : filter_linear_mipmap, repeat_disable;
uniform vec4 bake_bounds;
uniform vec4 tint : source_color = vec4(1.0);
uniform float texture_scale = 0.47;
uniform bool material_detail = true;
uniform bool use_baked_shadow = false;
uniform int surface_kind = 0; // Asphalt, sidewalk, curb, verge, frontage paving, basalt.

varying vec2 bake_uv;

void vertex() {
	vec2 world_site = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	bake_uv = (world_site - bake_bounds.xy) / bake_bounds.zw;
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
	vec2 sample_uv = UV * texture_scale;
	vec3 texel = texture(albedo_map, sample_uv).rgb;
	// RGB are sun coverage, contact occlusion and broad-scale surface wear.
	vec3 baked = texture(surface_bake, bake_uv).rgb;
	float wear = baked.b;
	vec3 base = texel * tint.rgb;
	float ao = 1.0 - baked.g * 0.44;
	ROUGHNESS = 0.92;
	SPECULAR = 0.23;

	if (surface_kind == 0) {
		float gutter = smoothstep(-0.48, -0.08, from_curb + 0.09 * wear) * (0.40 + 0.60 * wear);
		float track = max(1.0 - smoothstep(0.02, 0.36, abs(abs(across) - 1.0)),
			1.0 - smoothstep(0.04, 0.41, abs(abs(across) - 2.52)));
		float trench_edge = abs(across + 2.18 + 0.18 * wear);
		float trench = 1.0 - smoothstep(0.11, 0.21, trench_edge);
		float seam = line(trench_edge - 0.155, 0.012, across_aa);
		float utility_cut = smoothstep(51.0, 51.29, station) * (1.0 - smoothstep(105.96, 106.23, station));
		float resurfaced = smoothstep(71.98, 72.17, station + across * 0.22)
			* (1.0 - smoothstep(87.15, 87.38, station - across * 0.14));
		float patch = smoothstep(0.39, 0.66, wear + 0.05 * sin(station * 0.52 + across * 1.6));
		base *= 0.82 + 0.12 * wear + 0.055 * track + 0.034 * patch
			- utility_cut * (0.11 * trench + 0.14 * seam) - 0.12 * resurfaced;
		base = mix(base, base * vec3(0.74, 0.66, 0.55) + vec3(0.018, 0.013, 0.006), gutter * 0.70);
		ROUGHNESS -= track * 0.16 + trench * 0.04;
		ao -= gutter * 0.14;
		float dash = line(across, 0.063, across_aa) * line(mod(station - 1.3, 7.4) - 3.7, 1.28, station_aa);
		dash *= smoothstep(18.0, 21.0, station) * (1.0 - smoothstep(130.0, 132.0, station));
		float crossing = line(station - 32.2, 1.65, station_aa) * line(mod(across + 0.3, 0.91) - 0.455, 0.23, across_aa);
		crossing *= smoothstep(0.19, 0.26, -from_curb);
		float fleck = texture(albedo_map, UV * 2.1 + vec2(0.7, 0.0)).r;
		float abrasion = smoothstep(0.10, 0.29, fleck + wear * 0.065);
		float paint = abrasion * (0.54 + 0.37 * wear);
		base = mix(base, vec3(0.72, 0.49, 0.14) * (0.58 + 0.85 * fleck), paint * dash * (1.0 - crossing));
		base = mix(base, vec3(0.69, 0.67, 0.60) * (0.65 + 0.60 * fleck), paint * crossing);
	} else if (surface_kind == 1) {
		float stagger = station + sign(across) * 0.69;
		float cut = line(mod(stagger, 1.72) - 0.86, 0.012, station_aa);
		float seam = line(mod(from_curb - 0.28 + 0.47, 0.94) - 0.47, 0.008, curb_aa);
		float slab = fract(sin(floor(stagger / 1.72) * 13.49 + floor(from_curb / 0.94) * 31.1) * 31.37);
		float repair = smoothstep(0.54, 0.76, slab) * (0.25 + 0.75 * wear);
		float dust = smoothstep(1.10, 1.94, from_curb) * wear;
		base *= (0.75 + 0.17 * slab + 0.37 * wear - dust * 0.31) * (1.0 - max(cut, seam) * 0.30);
		base = mix(base, base * vec3(1.08, 0.94, 0.79), repair * 0.40);
		ao -= dust * 0.17;
		float tactile = line(station - 32.2, 1.10, station_aa) * line(from_curb - 0.43, 0.17, curb_aa);
		vec2 tile = abs(fract(vec2(station, from_curb) * 15.0) - 0.5);
		float stud = 1.0 - smoothstep(0.16, 0.33, max(tile.x, tile.y));
		base = mix(base, vec3(0.63, 0.47, 0.24) * (0.83 + 0.24 * stud + 0.12 * wear), tactile);
	} else if (surface_kind == 2) {
		base *= 0.77 + 0.38 * wear - line(mod(station, 0.94) - 0.47, 0.011, station_aa) * 0.32;
		ao -= clamp(0.16 - from_curb, 0.0, 0.16) * 1.9;
	} else if (surface_kind == 3) {
		base *= 0.73 + 0.57 * wear;
	} else if (surface_kind == 4) {
		float driveway = smoothstep(0.28, 0.58, wear);
		base *= 0.81 + 0.34 * wear + 0.10 * driveway;
		ao -= 0.12 + wear * 0.09;
	} else {
		base *= 0.94 + 0.20 * wear;
		ao -= 0.07;
	}

	if (use_baked_shadow) {
		base *= mix(vec3(1.0), vec3(0.49, 0.58, 0.68), baked.r);
	}
	ALBEDO = base * (1.0 - baked.g * 0.13);
	AO = clamp(ao, 0.22, 1.0);
	if (material_detail) {
		NORMAL_MAP = texture(normal_texture, sample_uv).rgb;
		NORMAL_MAP_DEPTH = 0.43;
	}
}
