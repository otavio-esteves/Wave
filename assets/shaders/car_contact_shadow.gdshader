shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.28;
uniform bool rectangular = false;
instance uniform vec2 projected_half_size = vec2(0.0);
instance uniform vec4 projected_frame = vec4(0.0, 0.0, 1.0, 0.0);
varying vec2 receiver_position;

void vertex() {
	receiver_position = VERTEX.xz;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	if (projected_half_size.x > 0.0) {
		vec2 offset = receiver_position - projected_frame.xy;
		float c = projected_frame.z;
		float s = projected_frame.w;
		p = vec2(dot(offset, vec2(c, -s)), dot(offset, vec2(s, c))) / projected_half_size;
		if (dot(p, p) > 1.0) {
			discard;
		}
	}
	float falloff = max(abs(p.x), abs(p.y));
	float shade = rectangular ? 1.0 - smoothstep(0.72, 1.0, falloff) : 1.0 - smoothstep(0.12, 1.0, dot(p, p));
	ALBEDO = vec3(0.0);
	ALPHA = shade * opacity;
}
