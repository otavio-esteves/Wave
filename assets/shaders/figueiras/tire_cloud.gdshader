shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D cloud : filter_linear_mipmap, repeat_disable;
uniform float daylight = 1.0;
varying float cloud_opacity;
varying float loose_surface;
varying float spray;

void vertex() {
	vec4 center = MODELVIEW_MATRIX[3];
	float size = length(MODELVIEW_MATRIX[0].xyz);
	float c = cos(INSTANCE_CUSTOM.z) * size;
	float s = sin(INSTANCE_CUSTOM.z) * size;
	MODELVIEW_MATRIX = mat4(vec4(c, s, 0.0, 0.0), vec4(-s, c, 0.0, 0.0),
		vec4(0.0, 0.0, size, 0.0), center);
	cloud_opacity = INSTANCE_CUSTOM.x;
	loose_surface = INSTANCE_CUSTOM.y;
	spray = INSTANCE_CUSTOM.w;
}

void fragment() {
	float density = texture(cloud, UV).a * cloud_opacity;
	if (density < 0.004) { discard; }
	vec3 tint = mix(vec3(0.72, 0.73, 0.78), vec3(0.69, 0.59, 0.43), loose_surface);
	ALBEDO = mix(tint, vec3(0.65, 0.77, 0.83), spray) * mix(0.45, 1.0, daylight);
	ALPHA = density;
}
