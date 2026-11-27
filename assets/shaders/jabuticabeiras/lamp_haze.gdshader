shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float density = 0.039;
uniform vec4 scattering_color : source_color = vec4(1.0, 0.65, 0.31, 1.0);

varying flat vec3 volume_center;
varying flat float volume_radius;

void vertex() {
	volume_center = (VIEW_MATRIX * MODEL_MATRIX[3]).xyz;
	volume_radius = length(MODEL_MATRIX[0].xyz) * 0.5;
	POSITION = PROJECTION_MATRIX * vec4(volume_center + vec3(VERTEX.xy * volume_radius * 2.0, 0.0), 1.0);
}

void fragment() {
	float raw_depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
#endif
	vec4 geometry = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 site = geometry.xyz / geometry.w;
	float limit = length(site);
	vec3 ray = site / max(limit, 0.001);
	float center = dot(ray, volume_center);
	float separation = max(dot(volume_center, volume_center) - center * center, 0.0);
	float radius_sq = volume_radius * volume_radius;
	float discriminant = radius_sq - separation;
	if (discriminant <= 0.0) {
		discard;
	}
	float depth = sqrt(discriminant);
	float start = max(0.0, center - depth);
	float finish = min(limit, center + depth);
	if (finish <= start) {
		discard;
	}

	// Integral of a quadratic density over the visible segment of the sphere.
	// Depth stops the scatter at the first roof, shutter, tree or vehicle.
	float a = start - center;
	float b = finish - center;
	float integrated = discriminant / radius_sq * (b - a) - (b * b * b - a * a * a) / (3.0 * radius_sq);
	vec3 up = mat3(VIEW_MATRIX) * vec3(0.0, 1.0, 0.0);
	vec3 light_position = volume_center + up * volume_radius * 0.61;
	vec3 from_light = ray * (start + finish) * 0.5 - light_position;
	float cone = smoothstep(0.02, 0.91, dot(normalize(from_light), -up));
	float near_fade = smoothstep(0.6, 2.2, length(volume_center));
	float forward_scatter = 0.52 + 0.48 * max(dot(ray, normalize(light_position)), 0.0);
	ALBEDO = scattering_color.rgb;
	ALPHA = min(0.28, 1.0 - exp(-integrated * density * (0.19 + cone * 0.81) * forward_scatter)) * near_fade;
}
