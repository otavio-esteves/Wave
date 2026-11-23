shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, shadows_disabled, specular_schlick_ggx;

#include "hatch_reflections.gdshaderinc"

instance uniform float windscreen_water = 0.0;
instance uniform float windscreen_blade = 0.0;
instance uniform bool windscreen_view = false;
varying vec3 glass_position;
varying flat vec2 blade_direction;

void vertex() {
	glass_position = VERTEX;
	blade_direction = vec2(-cos(windscreen_blade), sin(windscreen_blade));
}

float drop_seed(vec2 site) {
	vec2 p = fract(site * vec2(0.1031, 0.1357));
	p += dot(p, p.yx + 31.33);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	float facing = clamp(abs(dot(normal, VIEW)), 0.0, 1.0);
	float reflection = pow(1.0 - facing, 2.0);
	vec3 sky = reflected_sky(mat3(INV_VIEW_MATRIX) * reflect(-VIEW, normal), 1.6);
	// Glancing views read the sky. Looking straight in still shows the cabin.
	ALBEDO = vec3(0.16, 0.22, 0.22);
	ROUGHNESS = 0.12;
	METALLIC = 0.29;
	SPECULAR = 0.60;
	EMISSION = sky * (0.28 + 0.69 * reflection);
	ALPHA = FRONT_FACING ? mix(0.26, 0.87, reflection) : mix(0.06, 0.31, reflection);
	if (windscreen_view && glass_position.z < -0.19) {
		ALPHA *= 0.54;
	}
	if (windscreen_water > 0.01 && glass_position.z < -0.19 && glass_position.y > 0.44) {
		vec2 grid = glass_position.xy * vec2(46.0, 66.0);
		grid.y += TIME * 0.84;
		float seed = drop_seed(floor(grid));
		vec2 p = fract(grid) - vec2(0.38 + seed * 0.25, 0.54);
		float head = 1.0 - smoothstep(0.11, 0.20, length(p * vec2(1.0, 0.62)));
		float trail = (1.0 - smoothstep(0.03, 0.065, abs(p.x))) * smoothstep(-0.54, 0.02, p.y);
		vec2 pivot = glass_position.xy - vec2(0.16, 0.462);
		float radius_sq = dot(pivot, pivot);
		float facing_blade = dot(pivot, blade_direction) * inversesqrt(max(radius_sq, 0.00001));
		float sweep = smoothstep(0.8823, 0.9982, facing_blade);
		float reach = smoothstep(0.0196, 0.0484, radius_sq) * (1.0 - smoothstep(0.1849, 0.2809, radius_sq));
		float drops = (head * 0.72 + trail * 0.17) * step(0.77, seed) * (1.0 - sweep * reach * 0.87) * windscreen_water;
		ALPHA = min(0.86, ALPHA + drops * 0.34);
		EMISSION += vec3(0.29, 0.43, 0.48) * drops;
	}
}
