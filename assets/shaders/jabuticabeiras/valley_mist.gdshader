shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 haze_color = vec3(0.37, 0.48, 0.61);
uniform float concentration = 0.011;
varying flat vec3 center;
varying flat vec3 radius;

void vertex() {
	center = MODEL_MATRIX[3].xyz;
	radius = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)) * 0.5;
}

void fragment() {
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 direction = normalize(mat3(INV_VIEW_MATRIX) * -VIEW);
	vec3 initial = (camera - center) / radius;
	vec3 ray = direction / radius;
	float aa = dot(ray, ray);
	float bb = dot(initial, ray);
	float discriminant = bb * bb - aa * (dot(initial, initial) - 1.0);
	if (discriminant <= 0.0) {
		discard;
	}
	float rim = sqrt(discriminant);
	float start = max((-bb - rim) / aa, 0.0);
	float end = (-bb + rim) / aa;
	float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 space = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
#else
	vec3 space = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 obstruction = INV_PROJECTION_MATRIX * vec4(space, 1.0);
	float surface = length(obstruction.xyz / max(0.0001, abs(obstruction.w)));
	end = min(end, surface - 0.06);
	if (end <= start) {
		discard;
	}

	float opacity = 0.0;
	for (int step_index = 0; step_index < 4; step_index++) {
		float reach = mix(start, end, (float(step_index) + 0.5) * 0.25);
		vec3 point = initial + ray * reach;
		vec3 world = camera + direction * reach;
		float layer = 1.0 - smoothstep(0.40, 1.0, dot(point, point));
		float stream = 0.80 + 0.14 * sin(dot(world.xz, vec2(0.136, 0.071)) + TIME * 0.10)
			+ 0.11 * cos(dot(world.xz, vec2(0.088, -0.172)) - TIME * 0.076);
		opacity += layer * stream;
	}
	float cool_side = smoothstep(-0.27, 0.71, dot(direction, vec3(-0.57, 0.0, -0.74)));
	ALBEDO = haze_color * mix(vec3(0.89, 0.99, 1.05), vec3(1.10, 1.04, 0.96), cool_side);
	ALPHA = clamp(1.0 - exp(-concentration * (end - start) * opacity * 0.25), 0.0, 0.53);
}
