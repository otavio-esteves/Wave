shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_back;

uniform sampler2D rearview : source_color, filter_linear, repeat_disable;
uniform vec2 view_center = vec2(0.5);
uniform vec2 view_extent = vec2(1.0);
uniform float corner_radius = 0.0;

void fragment() {
	if (corner_radius > 0.0) {
		vec2 corner = max(vec2(0.0), abs(UV - 0.5) - (0.5 - corner_radius));
		if (dot(corner, corner) > corner_radius * corner_radius) {
			discard;
		}
	}
	vec2 p = clamp(view_center + (vec2(1.0 - UV.x, UV.y) - 0.5) * view_extent, vec2(0.0), vec2(1.0));
	vec3 reflection = texture(rearview, p).rgb;
	float vignette = 1.0 - 0.26 * pow(abs(UV.x - 0.5) * 2.0, 7.0);
	ALBEDO = reflection * vec3(0.74, 0.84, 0.88) * vignette;
}
