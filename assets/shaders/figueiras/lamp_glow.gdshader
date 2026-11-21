shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 light_color : source_color = vec4(1.0, 0.79, 0.54, 1.0);
uniform float radius = 0.85;
uniform float strength = 0.0;
varying float camera_distance;

void vertex() {
	// Face the camera while retaining the lamp's world position and depth test.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	camera_distance = length(MODELVIEW_MATRIX[3].xyz);
	VERTEX.xy *= radius;
}

void fragment() {
	vec2 from_center = UV * 2.0 - 1.0;
	float r2 = dot(from_center, from_center);
	float halo = exp(-7.0 * r2) * (1.0 - smoothstep(0.55, 1.0, r2));
	float falloff = 1.0 - smoothstep(40.0, 76.0, camera_distance);
	ALBEDO = light_color.rgb;
	ALPHA = halo * strength * falloff;
}
